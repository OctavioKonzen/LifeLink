import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/collection_provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/deck_tools.dart';
import '../search/card_detail_screen.dart';
import '../search/card_scan_screen.dart';
import '../../theme/app_theme.dart';

String _money(double usd, double? brl) => 'US\$ ${usd.toStringAsFixed(2)}${brl != null ? ' · R\$ ${(usd * brl).toStringAsFixed(2)}' : ''}';

/// Minha coleção (as cartas que tenho, com o valor total) e a lista de
/// desejos (as que quero, com o preço de quando entrou e o de hoje).
class CollectionScreen extends StatefulWidget {
  final int initialTab;
  const CollectionScreen({super.key, this.initialTab = 0});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  double? _brl;
  bool _refreshing = false;
  String _query = '';
  String? _folder; // null = todas; '' = sem pasta
  bool _onlyTrade = false;

  @override
  void initState() {
    super.initState();
    DeckTools.dollarInReais().then((v) {
      if (mounted) setState(() => _brl = v);
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final drops = await context.read<CollectionProvider>().refreshPrices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(drops.isEmpty ? 'Preços atualizados.' : 'Preços atualizados. ${drops.length} carta(s) da lista de desejos ficaram mais baratas!'),
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem conexão para atualizar os preços.')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<ThemeProvider>().backgroundColor;
    final text = bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final collection = context.watch<CollectionProvider>();
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: text,
          title: const Text('Minha coleção'),
          actions: [
            IconButton(
              tooltip: 'Atualizar preços',
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            labelColor: text,
            unselectedLabelColor: text.withValues(alpha: 0.5),
            indicatorColor: LL.gold,
            tabs: [
              Tab(text: 'Coleção (${collection.totalCards})'),
              Tab(text: 'Desejos (${collection.wishes.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: LL.gold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.document_scanner),
          label: const Text('Escanear'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardScanScreen(collect: true))),
        ),
        body: TabBarView(children: [
          _collectionTab(collection, text),
          _wishTab(collection, text),
        ]),
      ),
    );
  }

  Widget _thumb(String img) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: img.isEmpty ? const SizedBox(width: 40, height: 56) : CachedNetworkImage(imageUrl: img, width: 40, height: 56, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox(width: 40)),
      );

  Widget _empty(String msg, Color text) => Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: text.withValues(alpha: 0.6)))),
      );

  Widget _collectionTab(CollectionProvider collection, Color text) {
    final q = _query.toLowerCase();
    final list = [
      for (final c in collection.cards)
        if ((q.isEmpty || c.name.toLowerCase().contains(q) || c.set.toLowerCase().contains(q)) && (_folder == null || c.folder == _folder) && (!_onlyTrade || c.trade)) c,
    ];
    final folders = collection.folders;
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => setState(tap)),
        );
    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: LL.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: LL.gold.withValues(alpha: 0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Valor da coleção', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 12)),
          Text(_money(collection.totalUsd, _brl), style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900)),
          if (collection.totalEur > 0) Text('Cardmarket: € ${collection.totalEur.toStringAsFixed(2)}', style: TextStyle(color: text.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${collection.totalCards} cartas · ${collection.cards.length} diferentes · segure uma carta para pasta e troca', style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12)),
        ]),
      ),
      // Pastas (fichário, caixa...) e "para troca".
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), children: [
          chip('Todas', _folder == null && !_onlyTrade, () {
            _folder = null;
            _onlyTrade = false;
          }),
          chip('🔁 Para troca', _onlyTrade, () => _onlyTrade = !_onlyTrade),
          for (final f in folders) chip(f, _folder == f, () => _folder = _folder == f ? null : f),
          if (folders.isNotEmpty) chip('Sem pasta', _folder == '', () => _folder = _folder == '' ? null : ''),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(color: text),
          decoration: InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, color: text.withValues(alpha: 0.5)), hintText: 'Procurar na coleção', hintStyle: TextStyle(color: text.withValues(alpha: 0.4))),
        ),
      ),
      Expanded(
        child: collection.cards.isEmpty
            ? _empty('Sua coleção está vazia.\nEscaneie as cartas com a câmera ou use o botão de coleção na página da carta.', text)
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    leading: _thumb(c.img),
                    title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${c.trade ? '🔁 ' : ''}${c.folder.isNotEmpty ? '${c.folder} · ' : ''}${c.set} · US\$ ${c.usd.toStringAsFixed(2)}${c.eur > 0 ? ' · € ${c.eur.toStringAsFixed(2)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: c.toCard()))),
                    onLongPress: () => _cardOptions(collection, c),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: Icon(Icons.remove_circle_outline, color: text), onPressed: () => collection.setQty(c.id, c.qty - 1)),
                      Text('${c.qty}', style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(icon: Icon(Icons.add_circle_outline, color: text), onPressed: () => collection.setQty(c.id, c.qty + 1)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  /// Segurar uma carta da coleção: pasta e "para troca".
  Future<void> _cardOptions(CollectionProvider collection, SavedCard c) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: LL.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          SwitchListTile(
            secondary: Icon(Icons.swap_horiz, color: LL.gold),
            title: const Text('Para troca', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Os amigos veem e o app mostra quem quer esta carta.', style: TextStyle(color: Colors.white54)),
            value: c.trade,
            onChanged: (v) {
              collection.setTrade(c.id, v);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: Colors.white70),
            title: Text(c.folder.isEmpty ? 'Pôr numa pasta' : 'Pasta: ${c.folder}', style: const TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              final folder = await _askFolder(collection.folders, c.folder);
              if (folder != null) collection.setFolder(c.id, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Tirar da coleção', style: TextStyle(color: Colors.white)),
            onTap: () {
              collection.setQty(c.id, 0);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  /// Escolher uma pasta (ou criar uma nova). '' = sem pasta; null = cancelou.
  Future<String?> _askFolder(List<String> folders, String current) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pasta'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final f in folders) ChoiceChip(label: Text(f), selected: f == current, onSelected: (_) => Navigator.pop(ctx, f)),
              if (current.isNotEmpty) ActionChip(label: const Text('Sem pasta'), onPressed: () => Navigator.pop(ctx, '')),
            ]),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nova pasta (ex.: Fichário, Caixa)'), onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
  }

  Widget _wishTab(CollectionProvider collection, Color text) {
    if (collection.wishes.isEmpty) {
      return _empty('Sua lista de desejos está vazia.\nToque no coração na página de uma carta para acompanhar o preço dela.', text);
    }
    final total = collection.wishes.fold(0.0, (a, c) => a + c.usd);
    return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('Tudo: ${_money(total, _brl)}\nO app confere os preços uma vez por dia e avisa quando algum cai.', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 12)),
      ),
      for (final c in collection.wishes)
        Dismissible(
          key: ValueKey('wish-${c.id}'),
          direction: DismissDirection.endToStart,
          background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => collection.removeWish(c.id),
          child: ListTile(
            leading: _thumb(c.img),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
            subtitle: Text('${c.set} · quando entrou: US\$ ${c.added.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: c.toCard()))),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('US\$ ${c.usd.toStringAsFixed(2)}', style: TextStyle(color: text, fontWeight: FontWeight.w900)),
              if (c.added > 0 && c.usd != c.added)
                Text(
                  '${c.usd < c.added ? '▼' : '▲'} ${((c.usd - c.added).abs() / c.added * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: c.usd < c.added ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w800),
                ),
            ]),
          ),
        ),
    ]);
  }
}

/// O que falta na coleção para montar o deck, com o custo.
Future<void> missingCardsSheet(BuildContext context, DeckModel deck) async {
  final missing = context.read<CollectionProvider>().missingFor(deck.cards);
  final brl = await DeckTools.dollarInReais();
  if (!context.mounted) return;
  final cost = missing.fold(0.0, (a, m) => a + m.usd * (m.need - m.have));
  await showModalBottomSheet(
    context: context,
    backgroundColor: LL.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('O que falta na coleção', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                missing.isEmpty ? 'Você tem todas as cartas deste deck!' : '${missing.length} carta(s) · ${_money(cost, brl)}\nTerrenos básicos não contam; qualquer versão da carta serve.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final m in missing)
                ListTile(
                  dense: true,
                  title: Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Tenho ${m.have} de ${m.need}', style: const TextStyle(color: Colors.white54)),
                  trailing: Text('US\$ ${(m.usd * (m.need - m.have)).toStringAsFixed(2)}', style: TextStyle(color: LL.gold, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CardDetailScreen(card: m.card))),
                ),
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}
