import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/deck_tools.dart';
import '../../../data/services/scryfall_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    final cardColor = light ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1E1E24);

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
  int _mulligans = 0;
  int _toBottom = 0; // quantas ainda precisa pôr no fundo
  int _turn = 1;

  @override
  void initState() {
    super.initState();
    _newHand(reset: true);
  }

  void _newHand({bool reset = false}) {
    setState(() {
      if (reset) _mulligans = 0;
      _library = DeckTools.shuffled(widget.deck.cards, _rng);
      _hand = _library.take(7).toList();
      _library = _library.skip(7).toList();
      _toBottom = _mulligans;
      _turn = 1;
    });
  }

  void _mulligan() {
    _mulligans++;
    _newHand();
  }

  void _tap(int i) {
    if (_toBottom == 0) return;
    setState(() {
      _library.add(_hand.removeAt(i));
      _toBottom--;
    });
  }

  void _draw() {
    if (_library.isEmpty || _toBottom > 0) return;
    setState(() {
      _hand.add(_library.removeAt(0));
      _turn++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final light = theme.backgroundColor.computeLuminance() > 0.5;
    final text = light ? Colors.black87 : Colors.white;
    final lands = _hand.where((c) => '${c['type_line']}'.contains('Land') || '${c['type_line']}'.contains('Terreno')).length;
    final tooSmall = widget.deck.cards.length < 7;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Mão de teste', style: TextStyle(color: text)),
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
                      : '${_hand.length} cartas na mão · $lands terreno${lands == 1 ? '' : 's'} · ${_library.length} no grimório${_turn > 1 ? ' · turno $_turn' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _toBottom > 0 ? Colors.amber : text.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.716, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _hand.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _tap(i),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: _toBottom > 0 ? Border.all(color: Colors.amber, width: 2) : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedNetworkImage(
                            imageUrl: '${_hand[i]['imageUrl'] ?? ''}',
                            httpHeaders: CardImages.headers,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: Colors.black12),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.black26,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(6),
                              child: Text('${_hand[i]['name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _newHand(reset: true), icon: const Icon(Icons.shuffle), label: const Text('Nova mão'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: _mulligans < 6 ? _mulligan : null, icon: const Icon(Icons.replay), label: const Text('Mulligan'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.icon(onPressed: _toBottom == 0 && _library.isNotEmpty ? _draw : null, icon: const Icon(Icons.add_card), label: const Text('Comprar'))),
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
        backgroundColor: const Color(0xFF1E1E24),
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
                dropdownColor: const Color(0xFF1E1E24),
                items: [for (final t in const ['Commander', 'Challenger', 'Normal']) DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))],
                onChanged: (v) => setDialog(() => type = v!),
              ),
              const SizedBox(height: 8),
            ],
            const Text('Cole a lista exportada do Moxfield, Archidekt, MTG Arena ou MTGO.\nEx.: "1 Sol Ring (CMM) 410" ou "4x Lightning Bolt".',
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
  return (lines: DeckTools.parse(listCtrl.text), name: nameCtrl.text.trim().isEmpty ? 'Deck importado' : nameCtrl.text.trim(), type: type);
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
                  Container(height: 70.0 * curve[i] / top, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4))),
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
