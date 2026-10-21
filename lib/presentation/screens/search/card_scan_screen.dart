import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/theme_provider.dart';
import '../../../data/services/scryfall_service.dart';
import 'card_detail_screen.dart';

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
  final setRe = RegExp(r'\b([A-Z0-9]{3,5})\s*[•·.*\-]?\s*(EN|PT|ES|FR|DE|IT|JA|JP|KO|RU|CS|CT)\b');
  final numRe = RegExp(r'\b(\d{1,4})\s*/\s*\d{1,4}\b');
  final newNumRe = RegExp(r'^\s*(\d{3,4})\s+[CURMSLTP]\b');
  for (final l in lines) {
    final t = l.text.toUpperCase();
    final s = setRe.firstMatch(t);
    if (s != null && set == null) {
      set = s.group(1)!.toLowerCase();
      lang = _langCodes[s.group(2)];
    }
    final n = numRe.firstMatch(t) ?? newNumRe.firstMatch(t);
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

/// Escanear uma carta com a câmera: aponta para a carta e o app acha a mesma
/// versão (coleção e arte) e abre a carta, com o texto no idioma escolhido
/// nas configurações. Com [targetDeckId], o "adicionar" vai para esse deck.
class CardScanScreen extends StatefulWidget {
  final String? targetDeckId;
  const CardScanScreen({super.key, this.targetDeckId});

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
      final text = await _recognizer.processImage(InputImage.fromFilePath(photo.path));
      File(photo.path).delete().catchError((_) => File(photo.path));
      final lines = [
        for (final b in text.blocks)
          for (final l in b.lines) (text: l.text, top: l.boundingBox.top, left: l.boundingBox.left, height: l.boundingBox.height),
      ];
      final reading = readCard(lines);
      if (reading.isEmpty || !mounted) return;
      final key = reading.toString();
      if (_failed.contains(key)) return;
      setState(() => _status = 'Procurando ${reading.name ?? '${reading.set?.toUpperCase()} ${reading.number}'}...');
      final card = await _find(reading);
      if (!mounted) return;
      if (card == null) {
        _failed.add(key);
        setState(() => _status = 'Não achei "${reading.name ?? ''}". Ajuste a carta na moldura.');
        return;
      }
      HapticFeedback.heavyImpact();
      _paused = true;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: card, targetDeckId: widget.targetDeckId)));
      if (!mounted) return;
      _failed.clear();
      setState(() {
        _paused = false;
        _status = 'Aponte para a próxima carta';
      });
    } catch (_) {
      // Foto ou leitura falhou: tenta de novo na próxima volta.
    } finally {
      _busy = false;
    }
  }

  /// Acha a mesma versão da carta e o texto no idioma das configurações.
  Future<Map<String, dynamic>?> _find(CardReading r) async {
    final scryfall = ScryfallService.instance;
    final want = context.read<ThemeProvider>().cardLanguage;
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
        try {
          final page = await scryfall.search('"${r.name!.replaceAll('"', '')}"', multilingual: true);
          if (page.cards.isNotEmpty) printing = Map<String, dynamic>.from(page.cards.first as Map);
        } catch (_) {}
      }
      // Achou pelo nome e leu a coleção: a mesma versão da carta na mão.
      if (printing != null && r.set != null && printing['set'] != r.set) {
        try {
          final page = await scryfall.search('oracleid:${printing['oracle_id']} set:${r.set}', unique: 'prints', multilingual: false);
          if (page.cards.isNotEmpty) printing = Map<String, dynamic>.from(page.cards.first as Map);
        } catch (_) {}
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
      'usdPrice': printing['prices']?['usd'] ?? '0.00',
      'usdFoil': printing['prices']?['usd_foil'],
      'eurPrice': printing['prices']?['eur'],
      'tixPrice': printing['prices']?['tix'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Escanear carta')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))))
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
}
