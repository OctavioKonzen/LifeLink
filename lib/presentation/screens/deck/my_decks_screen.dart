import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import 'deck_detail_screen.dart';
import 'community_decks_screen.dart';
import 'deck_tools_screens.dart';
import '../../../data/services/deck_tools.dart';
import '../../../data/services/scryfall_service.dart';
import '../../widgets/neon.dart';
import '../../theme/app_theme.dart';

class MyDecksScreen extends StatefulWidget {
  const MyDecksScreen({super.key});

  @override
  State<MyDecksScreen> createState() => _MyDecksScreenState();
}

class _MyDecksScreenState extends State<MyDecksScreen> {
  
  void _confirmDelete(BuildContext context, DeckProvider provider, String deckId, String deckName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LL.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Apagar deck", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Deseja realmente apagar o deck '$deckName'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              // Pelo id: a lista pode ter mudado com a janela aberta.
              final index = provider.indexOfId(deckId);
              if (index >= 0) provider.deleteDeck(index);
              Navigator.pop(ctx);
            },
            child: const Text("Apagar"),
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
          backgroundColor: LL.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Novo deck", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Nome do deck",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: selectedType,
                dropdownColor: LL.surface,
                isExpanded: true,
                items: ['Commander', 'Challenger', 'Normal'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setDialogState(() => selectedType = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  context.read<DeckProvider>().createDeck(nameController.text.trim(), selectedType);
                  
                  // Deck criado conta para as missões.
                  context.read<XpProvider>().incrementDecksCreated();
                  
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Criar"),
            )
          ],
        ),
      ),
    );
  }

  bool _importing = false;

  /// Deck novo a partir de uma lista colada.
  Future<void> _importNewDeck() async {
    final input = await importListDialog(context, askName: true);
    if (input == null || input.lines.isEmpty || !mounted) return;
    setState(() => _importing = true);
    String message;
    try {
      final result = await DeckTools.fetch(input.lines);
      if (!mounted) return;
      if (result.cards.isEmpty) {
        message = 'Nenhuma carta encontrada na lista.';
      } else {
        context.read<DeckProvider>().importDeck(input.name, input.type, result.cards);
        context.read<XpProvider>().incrementDecksCreated();
        context.read<XpProvider>().incrementCardsAdded(result.cards.length);
        message = 'Deck "${input.name}" criado com ${result.cards.length} cartas!';
        if (result.missing.isNotEmpty) message += ' Não encontrei: ${result.missing.take(5).join(', ')}';
      }
    } on ScryfallException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Não deu para importar agora. Verifique a internet.';
    }
    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
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
            title: Text("Meus decks", style: TextStyle(color: textColor)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: "Importar lista (Moxfield, Archidekt...)",
                onPressed: _importNewDeck,
              ),
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
          body: deckProvider.allDecks.isEmpty
              // Sem decks: convite para criar o primeiro ou pegar um oficial.
              ? StatusMessage(
                  icon: Icons.style,
                  title: "Você ainda não tem decks",
                  message: "Crie o seu primeiro deck ou salve um dos decks oficiais da Wizards.",
                  actionLabel: "+ Criar deck",
                  onAction: _showCreateDeckDialog,
                )
              : GridView.builder(
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
        if (_importing)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Buscando as cartas da lista...', style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 15)),
                ]),
              ),
            ),
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
          Text("Novo deck", style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildDeckCard(dynamic deck, int index, DeckProvider provider, Color textColor, bool isLight) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DeckDetailScreen(deckId: deck.id))),
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
                    onTap: () => _confirmDelete(context, provider, deck.id, deck.name),
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
              memCacheWidth: 320, // miniatura: não decodifica a imagem inteira
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(color: Colors.black12),
              errorWidget: (c, u, e) => Container(color: Colors.black12),
            )
          : Container(color: Colors.grey[900]),
      ),
    );
  }
}