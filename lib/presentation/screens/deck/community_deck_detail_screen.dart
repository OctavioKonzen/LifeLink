import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../search/card_detail_screen.dart'; 

class CommunityDeckDetailScreen extends StatefulWidget {
  final Map<String, dynamic> deckData;

  const CommunityDeckDetailScreen({
    super.key, 
    required this.deckData, 
  });

  @override
  State<CommunityDeckDetailScreen> createState() => _CommunityDeckDetailScreenState();
}

class _CommunityDeckDetailScreenState extends State<CommunityDeckDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _cards = []; 

  @override
  void initState() {
    super.initState();
    _fetchDeckDetails();
  }

  Future<void> _fetchDeckDetails() async {
    final fileName = widget.deckData['fileName'];
    try {
      final String targetUrl = 'https://mtgjson.com/api/v5/decks/$fileName.json';
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        List<Map<String, dynamic>> tempCards = [];

        void extractCards(List<dynamic>? board, {bool commander = false}) {
          if (board == null) return;
          for (var item in board) {
            if (item is! Map) continue; 
            
            int qty = int.tryParse(item['count']?.toString() ?? '1') ?? 1;
            
            String? scryfallId;
            if (item['identifiers'] != null && item['identifiers'] is Map) {
              scryfallId = item['identifiers']['scryfallId'];
            }
            
            String imgUrl = 'https://upload.wikimedia.org/wikipedia/en/a/aa/Magic_the_gathering-card_back.jpg';
            if (scryfallId != null && scryfallId.length >= 2) {
              imgUrl = 'https://cards.scryfall.io/normal/front/${scryfallId[0]}/${scryfallId[1]}/$scryfallId.jpg';
            }
            
            Map<String, dynamic> cardObj = {
              'name': item['name'] ?? 'Carta Desconhecida',
              'imageUrl': imgUrl,
              'type_line': item['type'] ?? '',
              'oracle_text': item['text'] ?? '',
              'rarity': item['rarity'] ?? 'common',
              'mana_cost': item['manaCost'] ?? '',
              'power': item['power']?.toString(),
              'toughness': item['toughness']?.toString(),
              'color_identity': (item['colorIdentity'] as List?)?.join('') ?? '',
              'setName': item['setCode'] ?? '',
              'collectorNumber': item['number'] ?? '',
              'oracle_id': item['identifiers']?['oracleId'],
              'cmc': item['manaValue'] ?? 0,
              'usdPrice': '0.00',
              if (commander) 'commander': true,
            };

            for (int i = 0; i < qty; i++) {
              tempCards.add(cardObj);
            }
          }
        }

        // Só o comandante e o deck principal: o arquivo também traz o
        // comandante repetido (displayCommander), o banco, fichas, planos...
        if (data is Map) {
          extractCards(data['commander'] as List?, commander: true);
          extractCards(data['mainBoard'] as List?);
        }

        if (mounted) {
          setState(() {
            _cards = tempCards; 
            _isLoading = false;
          });
        }
      } else {
         if (mounted) setState(() { _errorMessage = "Erro ao carregar deck."; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Erro de rede."; _isLoading = false; });
    }
  }

  bool _saved = false;

  /// "Commander Deck" → "Commander", como os tipos dos decks do app.
  static String typeOf(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('commander')) return 'Commander';
    if (t.contains('challenger')) return 'Challenger';
    return 'Normal';
  }

  void _handleSaveDeck() {
    if (_cards.isEmpty || _saved) return;
    
    final deckProvider = context.read<DeckProvider>();

    try {
      final String deckName = widget.deckData['name'] ?? 'Novo Deck';
      final String deckType = typeOf('${widget.deckData['type'] ?? ''}');

      deckProvider.importDeck(deckName, deckType, _cards);
      // Conta como deck criado e cartas adicionadas (missões), como importar lista.
      final xp = context.read<XpProvider>();
      xp.incrementDecksCreated();
      xp.incrementCardsAdded(_cards.length);
      setState(() => _saved = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deck '$deckName' adicionado com ${_cards.length} cartas!"),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar deck.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent, 
            elevation: 0, 
            iconTheme: IconThemeData(color: textColor),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.deckData['name'] ?? 'Deck', 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                if (!_isLoading && _cards.isNotEmpty)
                  Text("${_cards.length} cartas", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_saved ? Icons.check_circle : Icons.add_to_photos_rounded, color: Colors.greenAccent),
                tooltip: _saved ? "Já está nos Meus Decks" : "Salvar nos Meus Decks",
                onPressed: _isLoading || _saved ? null : _handleSaveDeck,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                tooltip: "Baixar PDF para imprimir",
                onPressed: _isLoading ? null : _handleDownloadPdf,
              ),
            ],
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    childAspectRatio: 0.7, 
                    crossAxisSpacing: 10, 
                    mainAxisSpacing: 15,
                  ),
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    final cardData = _cards[index];
                    final cardUrl = cardData['imageUrl'] as String;

                    return GestureDetector(
                      onTap: () {
                        final Map<String, dynamic> safeCardData = Map.from(cardData);
                        
                        safeCardData['imageUrl'] = cardUrl; 
                        
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CardDetailScreen(card: safeCardData)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: cardUrl,
                            memCacheWidth: 320, // miniatura: não decodifica a imagem inteira
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.black12),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _handleDownloadPdf() async {
    if (_cards.isEmpty) return;
    List<String> imageUrls = _cards.map((c) => c['imageUrl'] as String).toList();
    await PdfService.generateAndPrintDeckPdf(context, imageUrls);
  }
}