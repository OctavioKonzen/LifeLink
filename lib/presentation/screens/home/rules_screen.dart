import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/theme_provider.dart';
import '../../../data/services/lifelink_cards.dart';
import '../../../data/services/rules_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neon.dart';
import '../search/card_detail_screen.dart';

/// O juiz de regras (o mesmo do site): a pergunta, em português ou inglês,
/// busca nas Regras Completas oficiais e no glossário; se for o nome de uma
/// carta, mostra a carta com as regras dela (rulings).
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  static const _examples = ['atropelar com toque mortífero', 'dano de comandante', 'quantos marcadores de veneno', 'regra da lenda', 'pilha e prioridade', '702.19'];

  final _ctrl = TextEditingController();
  RulesData? _data;
  String? _error;
  String _query = '';
  Timer? _debounce;
  Map<String, dynamic>? _card; // a carta com o nome perguntado
  int _cardAsk = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await RulesService.instance.load();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não deu para baixar as regras. Verifique a internet.');
    }
  }

  void _ask(String text, {bool now = false}) {
    _debounce?.cancel();
    void run() {
      if (!mounted) return;
      setState(() {
        _query = text;
        _card = null;
      });
      _findCard(text);
    }

    if (now) {
      run();
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), run);
    }
  }

  /// A pergunta é o nome de uma carta?
  Future<void> _findCard(String text) async {
    final q = text.trim();
    final ask = ++_cardAsk;
    if (q.length < 3 || RegExp(r'^\d').hasMatch(q)) return;
    try {
      final found = await LifeLinkCards.instance.search(text: q, nameOnly: true, lang: context.read<ThemeProvider>().cardLanguage);
      final key = RulesData.norm(q);
      final hit = found.cards.where((c) => RulesData.norm('${c['name']}') == key || RulesData.norm('${c['enName']}') == key).firstOrNull;
      if (mounted && ask == _cardAsk && hit != null) setState(() => _card = hit);
    } catch (_) {}
  }

  /// O texto da regra, com "Example:" em itálico.
  Widget _ruleText(String text, Color color, {int? maxLines}) {
    final lines = text.split('\n');
    return Text.rich(
      TextSpan(children: [
        for (var k = 0; k < lines.length; k++)
          TextSpan(
            text: '${k > 0 ? '\n' : ''}${lines[k]}',
            style: lines[k].startsWith('Example:') ? TextStyle(fontStyle: FontStyle.italic, color: color.withValues(alpha: 0.65)) : null,
          ),
      ]),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 14, height: 1.35),
    );
  }

  void _openRule(RulesData data, String id, Color surface, Color text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(data.sectionOf(id), style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 13)),
            const SizedBox(height: 10),
            for (final r in data.family(id))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: r.id == id ? LL.gold.withValues(alpha: 0.12) : null, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.id, style: TextStyle(color: LL.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 4),
                  _ruleText(r.text, text),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<ThemeProvider>().backgroundColor;
    final light = bg.computeLuminance() > 0.5;
    final text = light ? const Color(0xFF141824) : LL.text;
    final surface = cardColorOf(context);
    final data = _data;
    final result = data != null && _query.trim().isNotEmpty ? data.search(_query) : null;

    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
          ]),
        ),
      );
    } else if (data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (result == null) {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        Text('Regras oficiais vigentes desde ${data.effective} (em inglês). Toque num exemplo:', style: TextStyle(color: text.withValues(alpha: 0.65))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _examples)
            ActionChip(
              label: Text(e),
              onPressed: () {
                _ctrl.text = e;
                _ask(e, now: true);
              },
            ),
        ]),
      ]);
    } else {
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (_card != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: _card!))),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: neonDecoration(LL.gold, surface),
                  child: Row(children: [
                    Icon(Icons.gavel, color: LL.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Carta: ${_card!['name']}', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                        Text('Ver a carta e as regras oficiais dela', style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 13)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: text.withValues(alpha: 0.5)),
                  ]),
                ),
              ),
            ),
          ),
        if (result.terms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Buscando por: ${result.terms.join(' · ')}', style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 12)),
          ),
        for (final g in result.glossary)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: neonDecoration(LL.gold, surface).copyWith(border: Border.all(color: LL.gold.withValues(alpha: 0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GLOSSÁRIO', style: TextStyle(color: LL.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(g.id, style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              _ruleText(g.text, text),
            ]),
          ),
        if (result.rules.isEmpty && result.glossary.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text('Nada encontrado. Tente outras palavras (ex.: o nome da habilidade) ou o número da regra.',
                textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: 0.6))),
          ),
        for (final r in result.rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openRule(data, r.id, surface, text),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: neonDecoration(LL.gold, surface),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: LL.gold, borderRadius: BorderRadius.circular(6)),
                        child: Text(r.id, style: TextStyle(color: LL.onGold, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(data.sectionOf(r.id), overflow: TextOverflow.ellipsis, style: TextStyle(color: text.withValues(alpha: 0.55), fontSize: 12))),
                    ]),
                    const SizedBox(height: 6),
                    _ruleText(r.text, text, maxLines: 4),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Regras')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _ctrl,
            autofocus: false,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              hintText: 'Ex.: atropelar com toque mortífero, 702.19',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _ctrl.clear();
                        _ask('', now: true);
                      },
                    ),
            ),
            onChanged: (v) => _ask(v),
            onSubmitted: (v) => _ask(v, now: true),
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}
