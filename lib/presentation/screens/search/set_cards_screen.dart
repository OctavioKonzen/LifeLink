import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/theme_provider.dart';
import '../../../data/services/lifelink_cards.dart';
import 'card_detail_screen.dart';

/// Todas as cartas de uma coleção, na ordem dos números (1, 2, 3...), do
/// banco do LifeLink (R2).
class SetCardsScreen extends StatefulWidget {
  final String code;
  final String name;
  final String? targetDeckId;
  const SetCardsScreen({super.key, required this.code, required this.name, this.targetDeckId});

  @override
  State<SetCardsScreen> createState() => _SetCardsScreenState();
}

class _SetCardsScreenState extends State<SetCardsScreen> {
  List<Map<String, dynamic>>? _cards;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final cards = await LifeLinkCards.instance.setCards(widget.code, lang: context.read<ThemeProvider>().cardLanguage);
      if (mounted) setState(() => _cards = cards);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não deu para carregar a coleção agora. Verifique a internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final cards = _cards;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: text,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name, style: TextStyle(color: text, fontWeight: FontWeight.bold)),
          if (cards != null) Text('${cards.length} cartas · ${widget.code.toUpperCase()}', style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 12)),
        ]),
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: text)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
              ]),
            )
          : cards == null
              ? const Center(child: CircularProgressIndicator())
              : cards.isEmpty
                  ? Center(child: Text('Nenhuma carta desta coleção no banco ainda.', style: TextStyle(color: text)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.62, crossAxisSpacing: 10, mainAxisSpacing: 10),
                      itemCount: cards.length,
                      itemBuilder: (context, i) {
                        final c = cards[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: c, targetDeckId: widget.targetDeckId))),
                          child: Column(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: '${c['imageUrl']}',
                                  memCacheWidth: 320,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(color: Colors.black12),
                                  errorWidget: (_, _, _) => Container(
                                    color: Colors.black26,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(6),
                                    child: Text('${c['name']}', textAlign: TextAlign.center, style: TextStyle(color: text, fontSize: 11)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('#${c['collectorNumber']}', style: TextStyle(color: text.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        );
                      },
                    ),
    );
  }
}
