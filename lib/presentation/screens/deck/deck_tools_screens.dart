import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/deck_share.dart';
import '../../../data/services/deck_tools.dart';
import '../../../data/services/scryfall_service.dart';
import '../search/card_detail_screen.dart';
import '../../theme/app_theme.dart';

/// Preço de hoje (dólar, euro e real) e legalidade do deck em cada formato,
/// com as cartas atualizadas na Scryfall.
class DeckAnalysisScreen extends StatefulWidget {
  final DeckModel deck;
  const DeckAnalysisScreen({super.key, required this.deck});

  @override
  State<DeckAnalysisScreen> createState() => _DeckAnalysisScreenState();
}

class _DeckAnalysisScreenState extends State<DeckAnalysisScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cards = []; // uma por cópia, atualizadas
  double? _brl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([DeckTools.refresh(widget.deck.cards), DeckTools.dollarInReais()]);
      final table = results[0] as Map<String, Map<String, dynamic>>;
      _brl = results[1] as double?;
      _cards = [for (final c in widget.deck.cards) DeckTools.fresh(table, c) ?? c];
    } on ScryfallException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não deu para buscar as cartas agora. Verifique a internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// O nível do deck (Bracket do Commander) e o porquê.
  Widget _bracketSection(Widget Function(String, List<Widget>) section, Color text) {
    final b = DeckTools.bracket(_cards);
    Widget list(String title, List<String> names, Color color) => names.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('$title (${names.length}): ${names.join(', ')}', style: TextStyle(color: color, fontSize: 13)),
          );
    return section('NÍVEL DO DECK (BRACKET)', [
      Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(14)),
          child: Text('${b.bracket}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bracket ${b.bracket}: ${DeckTools.bracketNames[b.bracket]}', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(
              switch (b.bracket) {
                2 => 'Sem Game Changers, turnos extras nem destruição de terrenos. Se for um deck temático bem leve, pode ser o 1.',
                3 => 'Até 3 Game Changers e nada de destruição de terrenos em massa.',
                _ => 'Mais de 3 Game Changers, destruição de terrenos em massa ou vários turnos extras. Se for feito para vencer o mais rápido possível, é o 5 (cEDH).',
              },
              style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 13),
            ),
          ]),
        ),
      ]),
      list('Game Changers', b.gameChangers, LL.gold),
      list('Turnos extras', b.extraTurns, Colors.lightBlueAccent),
      list('Destruição de terrenos em massa', b.landDestruction, Colors.redAccent),
      const SizedBox(height: 8),
      Text('Combos de duas cartas não entram na conta: confira com a mesa.', style: TextStyle(color: text.withValues(alpha: 0.45), fontSize: 11)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    final cardColor = light ? LL.lightSurface : LL.surface;

    Widget section(String title, List<Widget> children) => Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: TextStyle(color: text.withValues(alpha: 0.6), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              ...children,
            ]),
          ),
        );

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: text)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
          ]),
        ),
      );
    } else {
      final usd = _cards.fold<double>(0, (a, c) => a + DeckTools.priceOf(c));
      final eur = _cards.fold<double>(0, (a, c) => a + (double.tryParse('${c['prices']?['eur'] ?? ''}') ?? 0));
      final priced = <String, ({Map<String, dynamic> card, int qty})>{};
      for (final c in _cards) {
        final name = '${c['printed_name'] ?? c['name']}';
        priced[name] = (card: c, qty: (priced[name]?.qty ?? 0) + 1);
      }
      final top = priced.entries.toList()..sort((a, b) => (DeckTools.priceOf(b.value.card) * b.value.qty).compareTo(DeckTools.priceOf(a.value.card) * a.value.qty));
      body = ListView(padding: const EdgeInsets.all(16), children: [
        section('CURVA DE MANA E CORES', [_ManaCurve(cards: _cards, text: text)]),
        if (widget.deck.type == 'Commander') _bracketSection(section, text),
        section('PREÇO DE HOJE (SCRYFALL)', [
          Text('US\$ ${usd.toStringAsFixed(2)}', style: TextStyle(color: text, fontSize: 30, fontWeight: FontWeight.w900)),
          if (_brl != null) Text('≈ R\$ ${(usd * _brl!).toStringAsFixed(2)}  (dólar a R\$ ${_brl!.toStringAsFixed(2)})', style: TextStyle(color: Colors.green.shade400, fontSize: 18, fontWeight: FontWeight.w800)),
          if (eur > 0) Text('€ ${eur.toStringAsFixed(2)}', style: TextStyle(color: text.withValues(alpha: 0.6), fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('AS MAIS CARAS', style: TextStyle(color: text.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w800)),
          for (final e in top.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${e.value.qty}× ${e.key}', overflow: TextOverflow.ellipsis, style: TextStyle(color: text))),
                Text('US\$ ${(DeckTools.priceOf(e.value.card) * e.value.qty).toStringAsFixed(2)}', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
        section('LEGALIDADE', [
          for (final f in DeckTools.formats.entries)
            () {
              final problems = DeckTools.problems(f.key, _cards);
              final ok = problems.isEmpty;
              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.redAccent),
                  title: Text(f.value, style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                  subtitle: Text(ok ? 'Legal' : '${problems.length} problema${problems.length > 1 ? 's' : ''}', style: TextStyle(color: text.withValues(alpha: 0.55))),
                  children: [
                    for (final p in problems.take(40))
                      Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 4, left: 40), child: Text('• $p', style: TextStyle(color: text.withValues(alpha: 0.8))))),
                  ],
                ),
              );
            }(),
        ]),
      ]);
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Análise do deck', style: TextStyle(color: text)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
      ),
      body: body,
    );
  }
}

/// Mão de teste: embaralha o deck, compra 7 e deixa fazer mulligan (o de
/// Londres: compra 7 de novo e põe no fundo uma por mulligan) e comprar mais.
class TestHandScreen extends StatefulWidget {
  final DeckModel deck;
  const TestHandScreen({super.key, required this.deck});

  @override
  State<TestHandScreen> createState() => _TestHandScreenState();
}

class _TestHandScreenState extends State<TestHandScreen> {
  final _rng = Random();
  List<Map<String, dynamic>> _library = [];
  List<Map<String, dynamic>> _hand = [];
  List<Map<String, dynamic>> _battlefield = []; // as cartas jogadas
  List<Map<String, dynamic>> _command = []; // o comandante, fora do grimório
  int _mulligans = 0;
  int _toBottom = 0; // quantas ainda precisa pôr no fundo
  int _turn = 1;
  bool _landPlayed = false;

  static bool _isLand(Map<String, dynamic> c) => '${c['type_line']}'.contains('Land') || '${c['type_line']}'.contains('Terreno');

  @override
  void initState() {
    super.initState();
    _newHand(reset: true);
  }

  void _newHand({bool reset = false}) {
    setState(() {
      if (reset) _mulligans = 0;
      _command = [for (final c in widget.deck.cards) if (c['commander'] == true) c];
      _library = DeckTools.shuffled([for (final c in widget.deck.cards) if (c['commander'] != true) c], _rng);
      _hand = _library.take(7).toList();
      _library = _library.skip(7).toList();
      _battlefield = [];
      _toBottom = _mulligans;
      _turn = 1;
      _landPlayed = false;
    });
  }

  void _mulligan() {
    _mulligans++;
    _newHand();
  }

  /// Tocar numa carta da mão: no mulligan vai para o fundo; depois, joga.
  void _tap(int i) {
    if (_toBottom > 0) {
      setState(() {
        _library.add(_hand.removeAt(i));
        _toBottom--;
      });
      return;
    }
    final card = _hand[i];
    if (_isLand(card) && _landPlayed) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já jogou um terreno neste turno.'), duration: Duration(seconds: 2)));
      return;
    }
    setState(() {
      _battlefield.add(_hand.removeAt(i));
      if (_isLand(card)) _landPlayed = true;
    });
  }

  void _draw() {
    if (_library.isEmpty || _toBottom > 0) return;
    setState(() => _hand.add(_library.removeAt(0)));
  }

  void _nextTurn() {
    if (_toBottom > 0) return;
    setState(() {
      _turn++;
      _landPlayed = false;
      if (_library.isNotEmpty) _hand.add(_library.removeAt(0));
    });
  }

  Widget _image(Map<String, dynamic> c, {double radius = 7}) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: '${c['imageUrl'] ?? ''}',
          httpHeaders: CardImages.headers,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: Colors.black12),
          errorWidget: (_, _, _) => Container(
            color: Colors.black26,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            child: Text('${c['name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      );

  /// Uma fileira de cartas pequenas (em jogo e zona de comando).
  Widget _strip(String title, List<Map<String, dynamic>> cards, Color text, void Function(int) onTap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(title, style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => GestureDetector(onTap: () => onTap(i), child: SizedBox(width: 60, child: _image(cards[i], radius: 4))),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    final lands = _hand.where(_isLand).length;
    final mana = _battlefield.where(_isLand).length;
    final tooSmall = widget.deck.cards.length < 7;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Mão de teste e simulação', style: TextStyle(color: text)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
      ),
      body: tooSmall
          ? Center(child: Text('O deck precisa de pelo menos 7 cartas.', style: TextStyle(color: text)))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _toBottom > 0
                      ? 'Mulligan $_mulligans: toque em $_toBottom carta${_toBottom > 1 ? 's' : ''} para pôr no fundo do grimório.'
                      : 'Turno $_turn · ${_hand.length} na mão ($lands terreno${lands == 1 ? '' : 's'}) · $mana de mana em jogo · ${_library.length} no grimório\nToque numa carta da mão para jogar (um terreno por turno).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _toBottom > 0 ? LL.gold : text.withValues(alpha: 0.7), fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              if (_command.isNotEmpty)
                _strip('ZONA DE COMANDO (toque para jogar)', _command, text, (i) {
                  if (_toBottom > 0) return;
                  setState(() => _battlefield.add(_command.removeAt(i)));
                }),
              if (_battlefield.isNotEmpty)
                _strip('EM JOGO (${_battlefield.length}) · toque para voltar para a mão', _battlefield, text, (i) {
                  setState(() {
                    final c = _battlefield.removeAt(i);
                    if (c['commander'] == true) {
                      _command.add(c);
                    } else {
                      _hand.add(c);
                      if (_isLand(c) && _landPlayed) _landPlayed = false;
                    }
                  });
                }),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.716, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _hand.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: _toBottom > 0 ? Border.all(color: LL.gold, width: 2) : null,
                      ),
                      child: _image(_hand[i]),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _newHand(reset: true), icon: const Icon(Icons.shuffle), label: const Text('Nova mão'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: _mulligans < 6 && _turn == 1 && _battlefield.isEmpty ? _mulligan : null, icon: const Icon(Icons.replay), label: const Text('Mulligan'))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _toBottom == 0 && _library.isNotEmpty ? _draw : null, icon: const Icon(Icons.add_card), label: const Text('Comprar 1'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(onPressed: _toBottom == 0 ? _nextTurn : null, icon: const Icon(Icons.skip_next), label: const Text('Próximo turno'))),
                    ]),
                  ]),
                ),
              ),
            ]),
    );
  }
}

/// Pede a lista colada (Moxfield, Archidekt, MTG Arena, MTGO) e, com
/// [askName], o nome e o tipo do deck novo. Volta as linhas lidas.
Future<({List<DeckLine> lines, String name, String type})?> importListDialog(BuildContext context, {bool askName = false}) async {
  final listCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  var type = 'Commander';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        backgroundColor: LL.surface,
        title: const Text('Importar lista', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (askName) ...[
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Nome do deck', hintStyle: TextStyle(color: Colors.white38)),
              ),
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                dropdownColor: LL.surface,
                items: [for (final t in const ['Commander', 'Challenger', 'Normal']) DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))],
                onChanged: (v) => setDialog(() => type = v!),
              ),
              const SizedBox(height: 8),
            ],
            const Text('Cole a lista exportada do Moxfield, Archidekt, MTG Arena ou MTGO (ex.: "1 Sol Ring (CMM) 410" ou "4x Lightning Bolt") ou um link de deck do LifeLink.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: listCtrl,
              maxLines: 10,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Commander\n1 Atraxa, Praetors' Voice\n\nDeck\n1 Sol Ring\n...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  // Um link de deck do LifeLink: a lista (e o nome e o tipo) vêm de dentro dele.
  final code = DeckShare.codeFromLink(listCtrl.text);
  final shared = code == null ? null : DeckShare.decode(code);
  final name = nameCtrl.text.trim();
  if (shared != null) {
    return (lines: DeckTools.parse(shared.list), name: name.isEmpty ? shared.name : name, type: name.isEmpty ? shared.type : type);
  }
  return (lines: DeckTools.parse(listCtrl.text), name: name.isEmpty ? 'Deck importado' : name, type: type);
}

/// A curva de mana (quantas cartas de cada custo, sem os terrenos) e quanto
/// de cada cor aparece nos custos.
class _ManaCurve extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final Color text;
  const _ManaCurve({required this.cards, required this.text});

  static const _colors = {
    'W': ('Branco', Color(0xFFF9FAF4)),
    'U': ('Azul', Color(0xFF0E68AB)),
    'B': ('Preto', Color(0xFF6B5E5E)),
    'R': ('Vermelho', Color(0xFFD3202A)),
    'G': ('Verde', Color(0xFF00733E)),
  };

  @override
  Widget build(BuildContext context) {
    final curve = List.filled(8, 0); // 0, 1, ..., 6, 7+
    final colors = <String, int>{};
    var lands = 0;
    for (final c in cards) {
      final type = '${c['type_line'] ?? ''}';
      if (type.contains('Land') || type.contains('Terreno')) {
        lands++;
        continue;
      }
      final cmc = ((c['cmc'] as num?) ?? 0).round();
      curve[cmc.clamp(0, 7)]++;
      final cost = '${c['mana_cost'] ?? ''}';
      for (final k in _colors.keys) {
        final n = RegExp('\\{[^}]*$k[^}]*\\}').allMatches(cost).length;
        if (n > 0) colors[k] = (colors[k] ?? 0) + n;
      }
    }
    final top = curve.reduce(max).clamp(1, 1 << 30);
    final spells = curve.fold(0, (a, b) => a + b);
    final avg = spells == 0 ? 0.0 : [for (var i = 0; i < 8; i++) i * curve[i]].fold(0, (a, b) => a + b) / spells;
    final totalColor = colors.values.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 8; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${curve[i]}', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Container(height: 70.0 * curve[i] / top, decoration: BoxDecoration(color: LL.gold, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Text(i == 7 ? '7+' : '$i', style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Text('$spells mágicas · $lands terrenos · custo médio ${avg.toStringAsFixed(2)}', style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12)),
      if (totalColor > 0) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            for (final e in _colors.entries)
              if ((colors[e.key] ?? 0) > 0) Expanded(flex: colors[e.key]!, child: Container(height: 14, color: e.value.$2)),
          ]),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 10, children: [
          for (final e in _colors.entries)
            if ((colors[e.key] ?? 0) > 0)
              Text('${e.value.$1} ${(100 * colors[e.key]! / totalColor).round()}%', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 12)),
        ]),
      ],
    ]);
  }
}

/// Exportar o deck: a lista (nomes em inglês, no formato do Moxfield e do
/// Arena) para copiar ou mandar pelo WhatsApp e outros apps.
Future<void> exportDeckSheet(BuildContext context, DeckModel deck) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: LL.surface,
    isScrollControlled: true,
    builder: (ctx) => FutureBuilder<Map<String, String>>(
      future: DeckTools.englishNames(deck.cards),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final text = DeckTools.exportList(deck.cards, english: snap.data!);
        final link = DeckShare.link(DeckShare.encode(name: deck.name, type: deck.type, list: text));
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Exportar ${deck.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // O link do deck (o deck vai dentro do link) e o QR code dele.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Link do deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const Text('Quem abrir o link (ou ler o QR code com a câmera) vê o deck e salva nos decks dele.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: QrImageView(data: link, size: 220, errorCorrectionLevel: QrErrorCorrectLevel.L, padding: EdgeInsets.zero),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Copiar link'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado.')));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Enviar link'),
                        onPressed: () => SharePlus.instance.share(ShareParams(text: '${deck.name}: $link', subject: deck.name)),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 4),
              const Text('A lista no formato do Moxfield, Arena e Archidekt (nomes em inglês).', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13))),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lista copiada.')));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Compartilhar'),
                    onPressed: () => SharePlus.instance.share(ShareParams(text: '${deck.name}\n\n$text', subject: deck.name)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}

/// Sugestões de cartas para o comandante do deck (EDHREC), com o "+" para
/// pôr no deck e o toque para ver a carta.
class SuggestionsScreen extends StatefulWidget {
  final DeckModel deck;
  const SuggestionsScreen({super.key, required this.deck});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  bool _loading = true;
  String? _error;
  String _source = '';
  List<Map<String, dynamic>> _cards = [];
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final commanders = [for (final c in widget.deck.cards) if (c['commander'] == true) c];
      if (commanders.isEmpty) {
        _error = 'Marque o comandante do deck primeiro (segure a carta no deck → "Marcar como comandante").';
      } else {
        // Os nomes em inglês (o deck pode estar traduzido).
        final table = await DeckTools.refresh(widget.deck.cards);
        final fresh = [for (final c in widget.deck.cards) DeckTools.fresh(table, c) ?? c];
        final commander = DeckTools.fresh(table, commanders.first) ?? commanders.first;
        final result = await DeckTools.suggestions(commander, fresh);
        _cards = result.cards;
        _source = result.source;
        if (_cards.isEmpty) _error = 'Não achei sugestões para este comandante.';
      }
    } on ScryfallException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não deu para buscar as sugestões agora. Verifique a internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _add(Map<String, dynamic> data) {
    final decks = context.read<DeckProvider>();
    final index = decks.indexOfId(widget.deck.id);
    if (index < 0) return;
    decks.addCardsToDeck(index, [DeckTools.deckCardOf(data)]);
    setState(() => _added.add('${data['id']}'));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text('${data['name']} foi para o deck.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Sugestões para o deck', style: TextStyle(color: text)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: text)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
                    ]),
                  ),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text('As cartas mais usadas com este comandante (fonte: $_source). Toque no + para pôr no deck.',
                        style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12)),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _cards.length,
                      itemBuilder: (context, i) {
                        final c = _cards[i];
                        final added = _added.contains('${c['id']}');
                        return Column(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: DeckTools.deckCardOf(c), targetDeckId: widget.deck.id))),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CachedNetworkImage(
                                  imageUrl: CardImages.normalOf(c) ?? '',
                                  httpHeaders: CardImages.headers,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(color: Colors.black12),
                                  errorWidget: (_, _, _) => Container(
                                    color: Colors.black26,
                                    alignment: Alignment.center,
                                    child: Text('${c['name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(children: [
                            Expanded(
                              child: Text('US\$ ${DeckTools.priceOf(c).toStringAsFixed(2)}', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Pôr no deck',
                              onPressed: added ? null : () => _add(c),
                              icon: Icon(added ? Icons.check_circle : Icons.add_circle, color: added ? Colors.green : LL.gold),
                            ),
                          ]),
                        ]);
                      },
                    ),
                  ),
                ]),
    );
  }
}
