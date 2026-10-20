import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart'; // IMPORT DO XP PROVIDER
import 'deck_detail_screen.dart';
import 'community_decks_screen.dart'; 
import '../../widgets/custom_back_button.dart';
import '../../widgets/neon.dart';

class MyDecksScreen extends StatefulWidget {
  const MyDecksScreen({super.key});

  @override
  State<MyDecksScreen> createState() => _MyDecksScreenState();
}

class _MyDecksScreenState extends State<MyDecksScreen> {
  
  void _confirmDelete(BuildContext context, DeckProvider provider, int index, String deckName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Apagar Deck", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Deseja realmente apagar o deck '$deckName'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              provider.deleteDeck(index);
              Navigator.pop(ctx);
            },
            child: const Text("APAGAR"),
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog() {
    String selectedType = 'Commander';
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Novo Deck", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Nome do Deck",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: selectedType,
                dropdownColor: const Color(0xFF1E1E24),
                isExpanded: true,
                items: ['Commander', 'Challenger', 'Normal'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setDialogState(() => selectedType = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  context.read<DeckProvider>().createDeck(nameController.text.trim(), selectedType);
                  
                  // GATILHO: AUMENTA CONTADOR DE DECKS CRIADOS
                  context.read<XpProvider>().incrementDecksCreated();
                  
                  Navigator.pop(ctx);
                }
              },
              child: const Text("CRIAR"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final deckProvider = context.watch<DeckProvider>();
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false, 
            title: Text("Meus decks", style: TextStyle(color: textColor)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            actions: [
              IconButton(
                icon: const Icon(Icons.language),
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const CommunityDecksScreen())
                  );
                },
                tooltip: "Decks da Comunidade",
              ),
            ],
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 0.72, 
              crossAxisSpacing: 16, 
              mainAxisSpacing: 16
            ),
            itemCount: deckProvider.allDecks.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildCreateButton(textColor, isLight);
              final deckIndex = index - 1;
              final deck = deckProvider.allDecks[deckIndex];
              return _buildDeckCard(deck, deckIndex, deckProvider, textColor, isLight);
            },
          ),
        ),
        const Material(
          type: MaterialType.transparency,
          child: CustomBackButton(),
        ),
      ],
    );
  }

  Widget _buildCreateButton(Color color, bool isLight) {
    return GestureDetector(
      onTap: _showCreateDeckDialog,
      child: Container(
        decoration: neonDecoration(AreaColors.decks, neonSurface(context, context.read<ThemeProvider>().backgroundColor)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add, size: 44, color: AreaColors.decks, shadows: [Shadow(color: AreaColors.decks.withValues(alpha: 0.8), blurRadius: 12)]),
          const SizedBox(height: 6),
          Text("NOVO DECK", style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildDeckCard(dynamic deck, int index, DeckProvider provider, Color textColor, bool isLight) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DeckDetailScreen(deckIndex: index))),
      child: Container(
        decoration: neonDecoration(AreaColors.decks, neonSurface(context, context.read<ThemeProvider>().backgroundColor), glow: 0.15),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: DeckCoverWidget(cards: deck.cards, isLight: isLight),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deck.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text("${deck.type} • ${deck.cards.length} cartas", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, provider, index, deck.name),
                    child: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 22),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class DeckCoverWidget extends StatelessWidget {
  final List cards;
  final bool isLight;
  const DeckCoverWidget({super.key, required this.cards, required this.isLight});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return Icon(Icons.style, size: 50, color: isLight ? Colors.black12 : Colors.white12);

    final card1 = cards[0];
    final card2 = cards.length > 1 ? cards[1] : null;
    final card3 = cards.length > 2 ? cards[2] : null;
    
    const double angle10 = 10 * pi / 180;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (card3 != null)
            Transform.translate(
              offset: const Offset(-25, 10), 
              child: Transform.rotate(angle: -angle10, child: _buildCardImg(card3['imageUrl'], 95, 130))
            ),
          if (card2 != null)
            Transform.translate(
              offset: const Offset(25, 10), 
              child: Transform.rotate(angle: angle10, child: _buildCardImg(card2['imageUrl'], 95, 130))
            ),
          Transform.translate(
            offset: const Offset(0, -10), 
            child: _buildCardImg(card1['imageUrl'], 105, 145)
          ),
        ],
      ),
    );
  }

  Widget _buildCardImg(String? url, double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10), 
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10), 
        child: url != null 
          ? CachedNetworkImage(
              imageUrl: url, 
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(color: Colors.black12),
              errorWidget: (c, u, e) => Container(color: Colors.black12),
            )
          : Container(color: Colors.grey[900]),
      ),
    );
  }
}