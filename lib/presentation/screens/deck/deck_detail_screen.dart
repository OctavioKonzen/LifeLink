import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../../../data/services/scryfall_service.dart';
import '../search/card_detail_screen.dart'; 
import '../search/card_search_screen.dart';
import '../../../data/services/deck_tools.dart';
import 'deck_tools_screens.dart';
import '../search/card_scan_screen.dart';
import '../collection/collection_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;

  const DeckDetailScreen({super.key, required this.deckId});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  /// A posição atual do deck (pelo id: a lista pode mudar com a tela aberta).
  int get _deckIndex => context.read<DeckProvider>().indexOfId(widget.deckId);

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  bool _isTranslating = false;
  bool _isImporting = false; 

  final Map<String, String> _languages = {
    "English": "en",
    "Português": "pt",
    "日本語": "ja",
    "Español": "es",
    "Français": "fr",
    "Deutsch": "de",
    "Italiano": "it",
  };

  Color _getRarityColor(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'uncommon': return const Color(0xFFB0B0B0);
      case 'rare': return const Color(0xFFC1A058);
      case 'mythic': return const Color(0xFFD45E18);
      default: return Colors.white24;
    }
  }

  void _deleteDeck(BuildContext context, DeckProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text("Apagar Deck", style: TextStyle(color: Colors.white)),
        content: const Text("Tem certeza que deseja excluir este deck permanentemente?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              provider.deleteDeck(_deckIndex);
              Navigator.pop(ctx); 
              Navigator.pop(context); 
            },
            child: const Text("Apagar"),
          ),
        ],
      ),
    );
  }

  Future<void> _translateDeckCards(String langCode, DeckProvider provider) async {
    setState(() => _isTranslating = true);
    
    final deck = provider.allDecks[_deckIndex];
    int translatedCount = 0;

    for (int i = 0; i < deck.cards.length; i++) {
      if (!mounted) return; // saiu da tela no meio
      var card = deck.cards[i];
      try {
        final oracleId = card['oracle_id'];
        final name = card['name'];
        final query = oracleId != null 
            ? 'oracleid:$oracleId lang:$langCode' 
            : '!"$name" lang:$langCode';
            
        final page = await ScryfallService.instance.search(query, order: 'released', dir: 'desc', multilingual: false);
        final List results = page.cards;

        final validPrint = results.firstWhere(
          (c) {
            final status = c['image_status'];
            return status != 'placeholder' && status != 'missing';
          },
          orElse: () => null
        );

        if (validPrint != null) {
          String? imgUrl = validPrint['image_uris']?['normal'] ?? validPrint['card_faces']?[0]?['image_uris']?['normal'];
          
          if (imgUrl != null) {
            Map<String, dynamic> updatedCard = Map.from(card);
            updatedCard['imageUrl'] = imgUrl;
            updatedCard['name'] = validPrint['printed_name'] ?? validPrint['name'] ?? card['name'];
            updatedCard['type_line'] = validPrint['printed_type_line'] ?? validPrint['type_line'] ?? card['type_line'];
            updatedCard['oracle_text'] = validPrint['printed_text'] ?? validPrint['oracle_text'] ?? card['oracle_text'];
            updatedCard['setName'] = validPrint['set_name'] ?? card['setName'];

            provider.updateCardInDeck(_deckIndex, i, updatedCard);
            translatedCount++;
          }
        }
      } catch (e) {
        // Ignora e mantém no idioma original
      }
    }

    if (!mounted) return;
    setState(() => _isTranslating = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$translatedCount cartas atualizadas para o idioma selecionado!"),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 4),
        )
      );
    }
  }

  /// Importa uma lista colada para este deck (as cartas vêm de 75 em 75 da Scryfall).
  Future<void> _importList(DeckProvider provider) async {
    final input = await importListDialog(context);
    if (input == null || input.lines.isEmpty || !mounted) return;
    setState(() => _isImporting = true);
    String message;
    var ok = true;
    try {
      final result = await DeckTools.fetch(input.lines);
      provider.addCardsToDeck(_deckIndex, result.cards);
      if (result.cards.isNotEmpty && mounted) context.read<XpProvider>().incrementCardsAdded(result.cards.length);
      message = '${result.cards.length} cartas adicionadas!';
      if (result.missing.isNotEmpty) {
        ok = false;
        message += ' Não encontrei: ${result.missing.take(5).join(', ')}${result.missing.length > 5 ? '...' : ''}';
      }
    } on ScryfallException catch (e) {
      ok = false;
      message = e.message;
    } catch (_) {
      ok = false;
      message = 'Não deu para importar agora. Verifique a internet.';
    }
    if (!mounted) return;
    setState(() => _isImporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ok ? Colors.green[700] : Colors.orange[800],
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final deckProvider = context.watch<DeckProvider>();

    if (_deckIndex < 0) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Esse deck não existe mais (foi apagado em outro aparelho?).")));
    }

    final deck = deckProvider.allDecks[_deckIndex];
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    final search = _searchQuery.toLowerCase();

    // Cópias iguais (mesmo nome e mesma arte) viram uma carta com "4×"; o
    // comandante vem primeiro.
    final byKey = <String, List<int>>{};
    for (var i = 0; i < deck.cards.length; i++) {
      final c = deck.cards[i];
      if (search.isNotEmpty && !(c['name']?.toString().toLowerCase() ?? '').contains(search)) continue;
      byKey.putIfAbsent('${c['name']}|${c['imageUrl']}', () => []).add(i);
    }
    final groups = byKey.values.toList()
      ..sort((a, b) {
        final ca = deck.cards[a.first]['commander'] == true ? 0 : 1;
        final cb = deck.cards[b.first]['commander'] == true ? 0 : 1;
        return ca != cb ? ca - cb : a.first - b.first;
      });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            // Tocar no nome renomeia o deck.
            title: GestureDetector(
              onTap: () => _rename(deck.name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(deck.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 14, color: textColor.withValues(alpha: 0.5)),
                  ]),
                  Text("${deck.type} • ${deck.cards.length} cartas", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.document_scanner, color: Colors.lightBlueAccent),
                tooltip: "Escanear carta com a câmera",
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardScanScreen(targetDeckId: widget.deckId))),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, color: Colors.orangeAccent),
                tooltip: "Importar lista",
                onPressed: () => _importList(deckProvider),
              ),
              IconButton(
                icon: const Icon(Icons.price_check, color: Colors.amber),
                tooltip: "Curva, preço e legalidade",
                onPressed: deck.cards.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeckAnalysisScreen(deck: deck))),
              ),
              IconButton(
                icon: const Icon(Icons.front_hand, color: Colors.purpleAccent),
                tooltip: "Mão de teste",
                onPressed: deck.cards.length < 7 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestHandScreen(deck: deck))),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.language, color: Colors.greenAccent),
                tooltip: "Traduzir Deck",
                onSelected: (String code) {
                  _translateDeckCards(code, deckProvider);
                },
                itemBuilder: (context) => _languages.entries.map((e) => PopupMenuItem(value: e.value, child: Text(e.key))).toList(),
              ),
              // Mais: exportar a lista, PDF e apagar.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: textColor),
                tooltip: "Mais",
                onSelected: (choice) async {
                  switch (choice) {
                    case 'export':
                      if (deck.cards.isNotEmpty) await exportDeckSheet(context, deck);
                    case 'suggest':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsScreen(deck: deck)));
                    case 'missing':
                      await missingCardsSheet(context, deck);
                    case 'pdf':
                      if (deck.cards.isEmpty) return;
                      List<String> imageUrls = deck.cards.map((c) => c['imageUrl'].toString()).toList();
                      await PdfService.generateAndPrintDeckPdf(context, imageUrls);
                    case 'delete':
                      _deleteDeck(context, deckProvider);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.share), title: Text('Exportar / compartilhar lista'))),
                  PopupMenuItem(value: 'suggest', child: ListTile(leading: Icon(Icons.lightbulb_outline), title: Text('Sugestões para o comandante'))),
                  PopupMenuItem(value: 'missing', child: ListTile(leading: Icon(Icons.inventory_2_outlined), title: Text('O que falta na coleção'))),
                  PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Baixar PDF'))),
                  PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Apagar deck'))),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Procurar no deck...",
                    hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          
          body: _isTranslating || _isImporting
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    Text(
                      _isImporting ? "Importando cartas da lista..." : "Buscando cartas no idioma escolhido...", 
                      style: TextStyle(color: textColor.withValues(alpha: 0.7))
                    ),
                  ],
                ),
              )
            : groups.isEmpty
              ? _buildEmptyState(textColor)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    return _buildGridCard(deck.cards[g.first], g, isLight);
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CardSearchScreen(targetDeckId: widget.deckId),
              ));
            },
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 80, color: textColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? "Deck vazio" : "Nada encontrado",
            style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Tira a carta, com "Desfazer" para quem tocou sem querer.
  void _removeCard(Map<String, dynamic> card, int indexInDeck) {
    final provider = context.read<DeckProvider>();
    final deckIndex = _deckIndex;
    if (deckIndex < 0) return;
    provider.removeCardFromDeck(deckIndex, indexInDeck);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('${card['name'] ?? 'Carta'} saiu do deck.'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () {
          final i = provider.indexOfId(widget.deckId);
          if (i >= 0) provider.insertCardInDeck(i, indexInDeck, card);
        },
      ),
    ));
  }

  /// Renomear o deck.
  Future<void> _rename(String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do deck'),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    context.read<DeckProvider>().renameDeck(_deckIndex, name);
  }

  /// O que dá para fazer com a carta (segurar em cima dela).
  void _cardMenu(Map<String, dynamic> card, List<int> copies) {
    final commander = card['commander'] == true;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${card['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${copies.length} ${copies.length == 1 ? 'cópia' : 'cópias'} no deck')),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Mais uma cópia'),
            onTap: () {
              Navigator.pop(ctx);
              final copy = Map<String, dynamic>.from(card);
              context.read<DeckProvider>().addCardToDeck(_deckIndex, copy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Tirar uma cópia'),
            onTap: () {
              Navigator.pop(ctx);
              _removeCard(card, copies.last);
            },
          ),
          ListTile(
            leading: Icon(Icons.workspace_premium, color: commander ? Colors.amber : null),
            title: Text(commander ? 'Não é mais o comandante' : 'Marcar como comandante'),
            onTap: () {
              Navigator.pop(ctx);
              context.read<DeckProvider>().setCommander(_deckIndex, copies, !commander);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Trocar por outra carta'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CardSearchScreen(targetDeckId: widget.deckId, replaceCardIndex: copies.first)));
            },
          ),
        ]),
      ),
    );
  }

  /// Uma carta do deck, com a quantidade de cópias (ex.: 4×).
  Widget _buildGridCard(Map<String, dynamic> card, List<int> copies, bool isLight) {
    final rarityColor = _getRarityColor(card['rarity']);
    final indexInDeck = copies.last;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CardDetailScreen(
            card: card,
            targetDeckId: widget.deckId,
            existingCardIndex: copies.first,
          )),
        );
      },
      onLongPress: () => _cardMenu(card, copies),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)])),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: card['imageUrl'] ?? '',
              memCacheWidth: 320, // miniatura: não decodifica a imagem inteira
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(color: Colors.black12),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20),
            ),
          ),
          // Quantas cópias e se é o comandante.
          if (copies.length > 1 || card['commander'] == true)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (card['commander'] == true) const Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                  if (copies.length > 1) Text('${copies.length}×', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                ]),
              ),
            ),
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _removeCard(card, indexInDeck),
              // Área de toque maior que o círculo (fácil de acertar no celular).
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)]),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}