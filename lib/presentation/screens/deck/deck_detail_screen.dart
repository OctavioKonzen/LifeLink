import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../search/card_detail_screen.dart'; 
import '../search/card_search_screen.dart';
import '../../widgets/custom_back_button.dart'; // <-- IMPORT DO NOSSO BOTÃO

class DeckDetailScreen extends StatefulWidget {
  final int deckIndex;

  const DeckDetailScreen({super.key, required this.deckIndex});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

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

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // ISTO REMOVE A SETINHA DE VOLTAR ANTIGA
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
      // STACK PARA SOBREPOR O BOTÃO À TELA
      body: Stack(
        children: [
          Positioned.fill(
            child: filteredCards.isEmpty
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
          ),
          const CustomBackButton(), // O NOSSO BOTÃO DE LADO
        ],
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