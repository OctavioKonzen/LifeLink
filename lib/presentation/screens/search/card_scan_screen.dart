import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/collection_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/lifelink_cards.dart';
import '../../../data/services/scryfall_service.dart';
import 'card_detail_screen.dart';
import '../../theme/app_theme.dart';

/// O que foi lido da carta na câmera: o nome (a linha de cima) e, nas cartas
/// novas, a coleção e o número no canto de baixo (ex.: "MH3 • EN" e "0123").
class CardReading {
  final String? name;
  final String? set;
  final String? number;
  final String? lang;
  const CardReading({this.name, this.set, this.number, this.lang});

  bool get isEmpty => name == null && (set == null || number == null);

  @override
  String toString() => '$name ($set $number $lang)';
}

/// Os idiomas que aparecem no canto da carta e o código da Scryfall.
const _langCodes = {
  'EN': 'en', 'PT': 'pt', 'ES': 'es', 'FR': 'fr', 'DE': 'de', 'IT': 'it', //
  'JA': 'ja', 'JP': 'ja', 'KO': 'ko', 'RU': 'ru', 'CS': 'zhs', 'CT': 'zht',
};

/// Lê as linhas do texto reconhecido (com a posição de cada uma na foto).
CardReading readCard(List<({String text, double top, double left, double height})> lines) {
  String? set, number, lang;
  // A coleção vem impressa em maiúsculas (sem isso, "etapa de" do texto de
  // regras virava a coleção "ETAPA" em alemão).
  // O separador ("•") a leitura às vezes troca por "«", "*" ou "»".
  final setRe = RegExp(r'\b([A-Z0-9]{3,5})\s*[^\w\s]?\s*(EN|PT|ES|FR|DE|IT|JA|JP|KO|RU|CS|CT)\b');
  final numRe = RegExp(r'\b(\d{1,4})\s*/\s*\d{1,4}\b');
  final newNumRe = RegExp(r'^\s*(\d{3,4})(\s+[CURMSLTP]\b|\s*$)'); // "0123 R" ou só "0123"
  // Coleção e número ficam no canto de baixo: só as linhas da parte de baixo
  // do texto lido contam.
  final tops = [for (final l in lines) l.top];
  final minTop = tops.isEmpty ? 0.0 : tops.reduce(min);
  final maxTop = tops.isEmpty ? 0.0 : tops.reduce(max);
  final bottom = minTop + (maxTop - minTop) * 0.6;
  for (final l in lines) {
    if (l.top < bottom) continue;
    final t = l.text;
    final s = setRe.firstMatch(t);
    if (s != null && set == null) {
      set = s.group(1)!.toLowerCase();
      lang = _langCodes[s.group(2)];
    }
    final n = numRe.firstMatch(t.toUpperCase()) ?? newNumRe.firstMatch(t.toUpperCase());
    if (n != null && number == null) number = int.parse(n.group(1)!).toString();
  }

  // O nome: a linha mais alta com cara de nome (letras, sem números de
  // custo/regras), entre as de cima da foto.
  final candidates = [
    for (final l in lines)
      if (RegExp(r"^[\p{L}][\p{L}' ,\-]{2,40}$", unicode: true).hasMatch(l.text.trim()) && l.text.trim().split(' ').length <= 6) l,
  ]..sort((a, b) => a.top.compareTo(b.top));
  final name = candidates.isEmpty ? null : candidates.first.text.trim();
  return CardReading(name: name, set: set, number: number, lang: lang);
}

/// Acha a mesma versão da carta lida e o texto no idioma [want] (o das
/// configurações). Volta a carta no formato do app, ou null.
Future<Map<String, dynamic>?> findCard(CardReading r, String want) async {
  // Primeiro no banco do LifeLink (R2 e a busca na Cloudflare).
  if (want == 'pt' || want == 'en') {
    try {
      final own = await findCardOwn(r, want);
      if (own != null) return own;
    } catch (_) {}
  }
  return findCardScryfall(r, want);
}

/// No banco do LifeLink: pela coleção e número (a versão exata) ou pelo nome
/// (português ou inglês), escolhendo a versão da coleção lida, se houver.
Future<Map<String, dynamic>?> findCardOwn(CardReading r, String want) async {
  final cards = LifeLinkCards.instance;
  if (r.set != null && r.number != null) {
    final id = await cards.printBySetNumber(r.set!, r.number!, lang: r.lang ?? 'en');
    if (id != null) return cards.appCard(id, lang: want);
  }
  if (r.name == null) return null;
  // O nome lido (com erro de leitura, tenta só as primeiras palavras).
  final words = r.name!.split(RegExp(r'\s+'));
  String? oracle;
  for (var k = words.length; k >= 1 && oracle == null; k--) {
    final found = await cards.search(text: words.take(k).join(' '), nameOnly: true, lang: want);
    if (found.cards.isNotEmpty) oracle = '${found.cards.first['oracle_id']}';
    if (k <= 2) break;
  }
  if (oracle == null) return null;
  final card = await cards.card(oracle);
  if (card == null) return null;
  final vs = (card['v'] as List).cast<Map<String, dynamic>>();
  final v = vs.firstWhere(
    (v) => (r.set == null || v['s'] == r.set) && (r.number == null || v['cn'] == r.number) && (r.set != null || r.number != null),
    orElse: () => LifeLinkCards.variationFor(card, lang: want),
  );
  final sets = await cards.sets().catchError((_) => <String, String>{});
  return LifeLinkCards.toApp({...card, '_sets': sets}, v, lang: want);
}

/// Na Scryfall (o caminho de antes; para outros idiomas ou se o banco do
/// LifeLink não responder).
Future<Map<String, dynamic>?> findCardScryfall(CardReading r, String want) async {
  final scryfall = ScryfallService.instance;
  Map<String, dynamic>? printing;

  // 1. Coleção e número (cartas novas): a versão exata.
  if (r.set != null && r.number != null) {
    try {
      printing = await scryfall.getJson('https://api.scryfall.com/cards/${r.set}/${r.number}${r.lang != null && r.lang != 'en' ? '/${r.lang}' : ''}');
    } catch (_) {}
  }
  // 2. Pelo nome (inglês, com erro de leitura) ou pelo nome impresso (português...).
  if (printing == null && r.name != null) {
    try {
      printing = await scryfall.getJson('https://api.scryfall.com/cards/named?fuzzy=${Uri.encodeQueryComponent(r.name!)}');
    } catch (_) {
      // Nome impresso (português...) e, se a leitura errou o fim do nome
      // (acentos, letras coladas), só as primeiras palavras.
      final words = r.name!.replaceAll('"', '').split(RegExp(r'\s+'));
      for (var k = words.length; k >= 2 && printing == null; k--) {
        try {
          final page = await scryfall.search('"${words.take(k).join(' ')}"', multilingual: true);
          if (page.cards.isNotEmpty) printing = Map<String, dynamic>.from(page.cards.first as Map);
        } catch (_) {}
      }
    }
    // Achou pelo nome e leu a coleção (ou só o número, nas cartas antigas):
    // a mesma versão da carta na mão.
    final sameSet = r.set == null || printing?['set'] == r.set;
    final sameNumber = r.number == null || printing?['collector_number'] == r.number;
    if (printing != null && (r.set != null || r.number != null) && !(sameSet && sameNumber)) {
      final where = [if (r.set != null) 'set:${r.set}', if (r.number != null) 'cn:${r.number}'];
      for (final q in [where.join(' '), if (where.length > 1) where.first]) {
        try {
          final page = await scryfall.search('oracleid:${printing!['oracle_id']} $q', unique: 'prints', multilingual: false);
          if (page.cards.isNotEmpty) {
            printing = Map<String, dynamic>.from(page.cards.first as Map);
            break;
          }
        } catch (_) {}
      }
    }
  }
  if (printing == null) return null;

  // O texto no idioma escolhido (a mesma versão nesse idioma, ou outra versão
  // só para o texto, mantendo a imagem da carta escaneada).
  Map<String, dynamic>? translated;
  if (want != (printing['lang'] ?? 'en')) {
    try {
      translated = await scryfall.getJson('https://api.scryfall.com/cards/${printing['set']}/${printing['collector_number']}/$want');
    } catch (_) {
      try {
        final page = await scryfall.search('oracleid:${printing['oracle_id']} lang:$want', unique: 'prints', multilingual: false);
        if (page.cards.isNotEmpty) translated = Map<String, dynamic>.from(page.cards.first as Map);
      } catch (_) {}
    }
  }
  final text = translated ?? printing;
  final sameArt = translated != null && translated['set'] == printing['set'] && translated['collector_number'] == printing['collector_number'];
  final image = CardImages.normalOf(sameArt ? translated : printing) ?? CardImages.normalOf(printing);
  return {
    'id': (sameArt ? translated : printing)['id'],
    'name': text['printed_name'] ?? text['name'] ?? printing['name'],
    'imageUrl': image,
    'backImageUrl': printing['card_faces']?[1]?['image_uris']?['normal'],
    'rarity': printing['rarity'],
    'color_identity': (printing['color_identity'] as List?)?.join('') ?? 'C',
    'mana_cost': printing['mana_cost'] ?? printing['card_faces']?[0]?['mana_cost'] ?? '',
    'type_line': text['printed_type_line'] ?? text['type_line'] ?? printing['type_line'] ?? '',
    'oracle_text': text['printed_text'] ?? text['oracle_text'] ?? printing['oracle_text'] ?? printing['card_faces']?[0]?['oracle_text'] ?? '',
    'oracle_id': printing['oracle_id'],
    'setName': printing['set_name'],
    'cmc': printing['cmc'],
    'power': printing['power']?.toString(),
    'toughness': printing['toughness']?.toString(),
    'collectorNumber': printing['collector_number'],
    'usdPrice': printing['prices']?['usd'] ?? printing['prices']?['usd_foil'] ?? printing['prices']?['usd_etched'] ?? '0.00',
    'usdFoil': printing['prices']?['usd_foil'],
    'eurPrice': printing['prices']?['eur'],
    'tixPrice': printing['prices']?['tix'],
  };
}

/// Escanear uma carta com a câmera: aponta para a carta e o app acha a mesma
/// versão (coleção e arte) e abre a carta, com o texto no idioma escolhido
/// nas configurações. Com [targetDeckId], o "adicionar" vai para esse deck.
/// Com [collect] (ou a chave em cima), cada carta lida vai direto para a
/// coleção, sem abrir: é só ir passando as cartas na frente da câmera.
class CardScanScreen extends StatefulWidget {
  final String? targetDeckId;
  final bool collect;
  const CardScanScreen({super.key, this.targetDeckId, this.collect = false});

  @override
  State<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends State<CardScanScreen> {
  CameraController? _camera;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String _status = 'Abrindo a câmera...';
  String? _error;
  bool _busy = false;
  bool _paused = false;
  final Set<String> _failed = {}; // o que já tentou e não achou
  Timer? _loop;
  late bool _collect = widget.collect;
  // A última carta guardada: a mesma carta parada na frente da câmera não
  // conta de novo por alguns segundos.
  String? _lastId;
  DateTime _lastAt = DateTime(2000);
  int _saved = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('sem câmera');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final camera = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await camera.initialize();
      await camera.setFlashMode(FlashMode.off).catchError((_) {});
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _status = 'Aponte para a carta (o nome e o canto de baixo à vista)';
      });
      _loop = Timer.periodic(const Duration(milliseconds: 1400), (_) => _scanOnce());
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied' ? 'Sem permissão para usar a câmera. Libere nas configurações do celular.' : 'Não deu para abrir a câmera.');
    } catch (_) {
      setState(() => _error = 'Não deu para abrir a câmera.');
    }
  }

  @override
  void dispose() {
    _loop?.cancel();
    _camera?.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _scanOnce() async {
    final camera = _camera;
    if (_busy || _paused || camera == null || !camera.value.isInitialized || camera.value.isTakingPicture) return;
    _busy = true;
    try {
      final photo = await camera.takePicture();
      await _read(photo.path, delete: true);
    } catch (_) {
      // Foto ou leitura falhou: tenta de novo na próxima volta.
    } finally {
      _busy = false;
    }
  }

  /// Tirar a foto na hora (botão) ou escolher uma foto da galeria.
  Future<void> _manual({required bool gallery}) async {
    // Espera a leitura automática que estiver em andamento.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    _busy = true;
    try {
      String? path;
      var delete = false;
      if (gallery) {
        _paused = true;
        path = (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
        _paused = false;
      } else {
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) return;
        HapticFeedback.selectionClick();
        path = (await camera.takePicture()).path;
        delete = true;
      }
      if (path == null || !mounted) return;
      setState(() => _status = 'Lendo a foto...');
      _failed.clear(); // foto escolhida: tenta mesmo se já falhou antes
      final ok = await _read(path, delete: delete, manual: true);
      if (!ok && mounted) setState(() => _status = 'Não consegui ler a carta nessa foto. Tente com o nome e o canto de baixo bem à vista.');
    } catch (_) {
      if (mounted) setState(() => _status = 'Não deu para usar essa foto.');
    } finally {
      _paused = false;
      _busy = false;
    }
  }

  /// Lê a carta da foto e acha a versão certa; volta se achou.
  Future<bool> _read(String path, {bool delete = false, bool manual = false}) async {
    {
      final text = await _recognizer.processImage(InputImage.fromFilePath(path));
      if (delete) File(path).delete().catchError((_) => File(path));
      final lines = [
        for (final b in text.blocks)
          for (final l in b.lines) (text: l.text, top: l.boundingBox.top, left: l.boundingBox.left, height: l.boundingBox.height),
      ];
      final reading = readCard(lines);
      if (reading.isEmpty || !mounted) return false;
      final key = reading.toString();
      if (_failed.contains(key)) return false;
      setState(() => _status = 'Procurando ${reading.name ?? '${reading.set?.toUpperCase()} ${reading.number}'}...');
      final card = await findCard(reading, context.read<ThemeProvider>().cardLanguage);
      if (!mounted) return false;
      if (card == null) {
        _failed.add(key);
        setState(() => _status = 'Não achei "${reading.name ?? ''}". Ajuste a carta na moldura.');
        return manual; // na foto escolhida, a mensagem "não achei" fica
      }
      if (_collect) {
        final id = '${card['id']}';
        if (!manual && id == _lastId && DateTime.now().difference(_lastAt) < const Duration(seconds: 4)) return true;
        final qty = context.read<CollectionProvider>().add(card);
        HapticFeedback.heavyImpact();
        _lastId = id;
        _lastAt = DateTime.now();
        _failed.clear();
        setState(() {
          _saved++;
          _status = qty == 0 ? 'A coleção está cheia (${CollectionProvider.maxCards} cartas diferentes).' : 'Guardada: ${card['name']} ($qty na coleção). Próxima!';
        });
        return true;
      }
      HapticFeedback.heavyImpact();
      _paused = true;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: card, targetDeckId: widget.targetDeckId)));
      if (!mounted) return true;
      _failed.clear();
      setState(() {
        _paused = false;
        _status = 'Aponte para a próxima carta';
      });
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_collect ? 'Guardar na coleção${_saved > 0 ? ' ($_saved)' : ''}' : 'Escanear carta'),
        actions: [
          Row(children: [
            const Text('Coleção', style: TextStyle(fontSize: 13)),
            Switch(value: _collect, activeThumbColor: LL.gold, onChanged: (v) => setState(() => _collect = v)),
          ]),
        ],
      ),
      body: _error != null
          // Sem câmera, ainda dá para escolher uma foto da galeria.
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(icon: const Icon(Icons.photo_library), label: const Text('Escolher foto da galeria'), onPressed: () => _manual(gallery: true)),
                  const SizedBox(height: 12),
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
                ]),
              ),
            )
          : camera == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(fit: StackFit.expand, children: [
                  Center(child: CameraPreview(camera)),
                  // A moldura do tamanho de uma carta.
                  IgnorePointer(
                    child: LayoutBuilder(builder: (context, box) {
                      final w = box.maxWidth * 0.78;
                      return Center(
                        child: Container(
                          width: w,
                          height: w / 0.716,
                          decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(18)),
                        ),
                      );
                    }),
                  ),
                  // Tirar a foto na hora ou escolher uma da galeria.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 96,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _roundButton(Icons.photo_library, 'Galeria', () => _manual(gallery: true)),
                      const SizedBox(width: 28),
                      _roundButton(Icons.camera_alt, 'Tirar foto', () => _manual(gallery: false), big: true),
                    ]),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
                ]),
    );
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap, {bool big = false}) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: big ? 68 : 52,
            height: big ? 68 : 52,
            decoration: BoxDecoration(
              color: big ? Colors.white : Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(icon, color: big ? Colors.black : Colors.white, size: big ? 32 : 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, shadows: [Shadow(blurRadius: 4)])),
        ]),
      );
}
