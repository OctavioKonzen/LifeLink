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
import '../../widgets/custom_back_button.dart';

class DeckDetailScreen extends StatefulWidget {
  final int deckIndex;

  const DeckDetailScreen({super.key, required this.deckIndex});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _importListController = TextEditingController();
  
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
              provider.deleteDeck(widget.deckIndex);
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
    
    final deck = provider.allDecks[widget.deckIndex];
    int translatedCount = 0;

    for (int i = 0; i < deck.cards.length; i++) {
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
            updatedCard['setName'] = (validPrint['set'] ?? card['setName']).toString().toUpperCase();

            provider.updateCardInDeck(widget.deckIndex, i, updatedCard);
            translatedCount++;
          }
        }
      } catch (e) {
        // Ignora e mantém no idioma original
      }
    }

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

  void _showImportDialog(BuildContext context, DeckProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isLight = context.read<ThemeProvider>().backgroundColor.computeLuminance() > 0.5;
        return AlertDialog(
          backgroundColor: isLight ? Colors.white : const Color(0xFF1E1E24),
          title: Text("Importar por Lista", style: TextStyle(color: isLight ? Colors.black : Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Cole os nomes das cartas.\nExemplo:\n4 Lightning Bolt\nSol Ring",
                style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _importListController,
                maxLines: 8,
                style: TextStyle(color: isLight ? Colors.black : Colors.white),
                decoration: InputDecoration(
                  hintText: "Sua lista aqui...",
                  hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: isLight ? Colors.grey[200] : Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _importListController.clear();
                Navigator.pop(ctx);
              },
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                final text = _importListController.text;
                _importListController.clear();
                Navigator.pop(ctx);
                if (text.trim().isNotEmpty) {
                  _processImportList(text, provider);
                }
              },
              child: const Text("Importar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  Future<void> _processImportList(String text, DeckProvider provider) async {
    setState(() => _isImporting = true);
    final lines = text.split('\n');
    int addedCount = 0;
    int errorCount = 0;

    // ignore: deprecated_member_use
    final regex = RegExp(r'^(\d+)[xX]?\s+(.*)$');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      int qty = 1;
      String cardName = line;

      final match = regex.firstMatch(line);
      if (match != null) {
        qty = int.parse(match.group(1)!);
        cardName = match.group(2)!;
      }

      try {
        final scryfall = ScryfallService.instance;
        final name = Uri.encodeQueryComponent(cardName);
        Map<String, dynamic>? data;
        try {
          data = await scryfall.getJson('https://api.scryfall.com/cards/named?exact=$name');
        } on ScryfallException {
          // Nome com erro de digitação: o Scryfall tenta adivinhar.
          data = await scryfall.getJson('https://api.scryfall.com/cards/named?fuzzy=$name');
        }

        Map<String, dynamic> cardObj = {
          'name': data['name'] ?? 'Carta Desconhecida',
          'imageUrl': data['image_uris']?['normal'] ?? data['card_faces']?[0]?['image_uris']?['normal'] ?? 'https://upload.wikimedia.org/wikipedia/en/a/aa/Magic_the_gathering-card_back.jpg',
          'type_line': data['type_line'] ?? '',
          'oracle_text': data['oracle_text'] ?? '',
          'rarity': data['rarity'] ?? 'common',
          'mana_cost': data['mana_cost'] ?? '',
          'power': data['power']?.toString(),
          'toughness': data['toughness']?.toString(),
          'color_identity': (data['color_identity'] as List?)?.join('') ?? '',
          'setName': (data['set'] ?? '').toString().toUpperCase(),
          'collectorNumber': data['collector_number'] ?? '',
          'oracle_id': data['oracle_id'],
          'usdPrice': data['prices']?['usd'] ?? '0.00',
        };

        for (int i = 0; i < qty; i++) {
          provider.addCardToDeck(widget.deckIndex, cardObj);
          addedCount++;
        }
      } catch (e) {
        errorCount++;
      }
      
      await Future.delayed(const Duration(milliseconds: 100)); 
    }

    setState(() => _isImporting = false);

    if (mounted) {
      if (addedCount > 0) {
        context.read<XpProvider>().incrementCardsAdded(addedCount);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$addedCount cartas adicionadas!${errorCount > 0 ? ' ($errorCount não encontradas)' : ''}"),
          backgroundColor: errorCount > 0 ? Colors.orange[700] : Colors.green[700],
          duration: const Duration(seconds: 4),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final deckProvider = context.watch<DeckProvider>();

    if (widget.deckIndex >= deckProvider.allDecks.length) {
      return const Scaffold(body: Center(child: Text("Deck não encontrado")));
    }

    final deck = deckProvider.allDecks[widget.deckIndex];
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    final filteredCards = deck.cards.where((card) {
      final name = card['name']?.toString().toLowerCase() ?? "";
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false, 
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deck.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                Text("${deck.type} • ${deck.cards.length} cartas", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add, color: Colors.orangeAccent),
                tooltip: "Importar de Texto",
                onPressed: () => _showImportDialog(context, deckProvider),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.language, color: Colors.greenAccent),
                tooltip: "Traduzir Deck",
                onSelected: (String code) {
                  _translateDeckCards(code, deckProvider);
                },
                itemBuilder: (context) => _languages.entries.map((e) => PopupMenuItem(value: e.value, child: Text(e.key))).toList(),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                tooltip: "Baixar PDF",
                onPressed: () async {
                  if (deck.cards.isEmpty) return;
                  List<String> imageUrls = deck.cards.map((c) => c['imageUrl'].toString()).toList();
                  await PdfService.generateAndPrintDeckPdf(context, imageUrls);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deleteDeck(context, deckProvider),
                tooltip: "Apagar Deck",
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
            : filteredCards.isEmpty
              ? _buildEmptyState(textColor)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: filteredCards.length,
                  itemBuilder: (context, index) {
                    final card = filteredCards[index];
                    final realIndex = deck.cards.indexOf(card);
                    return _buildGridCard(card, realIndex, isLight);
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CardSearchScreen(targetDeckIndex: widget.deckIndex),
              ));
            },
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
        const CustomBackButton(), 
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

  Widget _buildGridCard(Map<String, dynamic> card, int indexInDeck, bool isLight) {
    final rarityColor = _getRarityColor(card['rarity']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CardDetailScreen(
            card: card,
            targetDeckIndex: widget.deckIndex,
            existingCardIndex: indexInDeck, 
          )),
        );
      },
      onLongPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CardSearchScreen(
            targetDeckIndex: widget.deckIndex,
            replaceCardIndex: indexInDeck, 
          )),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)])),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: card['imageUrl'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(color: Colors.black12),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () {
                context.read<DeckProvider>().removeCardFromDeck(widget.deckIndex, indexInDeck);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}