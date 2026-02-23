import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/deck_provider.dart';
import '../../../data/services/pdf_service.dart';
import '../search/card_detail_screen.dart'; 
import '../../widgets/custom_back_button.dart'; // IMPORT DO BOTÃO TRIANGULAR

class CommunityDeckDetailScreen extends StatefulWidget {
  final Map<String, dynamic> deckData;
  const CommunityDeckDetailScreen({super.key, required this.deckData});

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

        void extractCards(List<dynamic>? board) {
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
            };

            for (int i = 0; i < qty; i++) {
              tempCards.add(cardObj);
            }
          }
        }

        if (data is Map) {
          data.forEach((key, value) {
            if (value is List) {
              extractCards(value);
            }
          });
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

  void _handleSaveDeck() {
    if (_cards.isEmpty) return;
    
    final deckProvider = context.read<DeckProvider>();
    final theme = context.read<ThemeProvider>();
    final isPt = theme.cardLanguage == 'pt';

    try {
      final String deckName = widget.deckData['name'] ?? 'Novo Deck';
      final String deckType = widget.deckData['type'] ?? 'Casual';
      
      deckProvider.importDeck(deckName, deckType, _cards);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPt ? "Deck '$deckName' adicionado com ${_cards.length} cartas!" : "Deck '$deckName' added with ${_cards.length} cards!"),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isPt ? "Erro ao salvar deck." : "Error saving deck.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // REMOVE A SETA NORMAL
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
            icon: const Icon(Icons.add_to_photos_rounded, color: Colors.greenAccent),
            tooltip: "Salvar nos Meus Decks",
            onPressed: _isLoading ? null : _handleSaveDeck,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
            onPressed: _isLoading ? null : _handleDownloadPdf,
          ),
        ],
      ),
      // STACK PARA SOBREPOR O NOSSO BOTÃO TRIANGULAR AQUI TAMBÉM
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading 
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
                      final gridSafeUrl = kIsWeb ? 'https://wsrv.nl/?url=${Uri.encodeComponent(cardUrl)}&w=300' : cardUrl;

                      return GestureDetector(
                        onTap: () {
                          final Map<String, dynamic> safeCardData = Map.from(cardData);
                          if (kIsWeb) {
                            safeCardData['imageUrl'] = 'https://wsrv.nl/?url=${Uri.encodeComponent(cardUrl)}&w=800';
                          }
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
                              imageUrl: gridSafeUrl,
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
          const CustomBackButton(), // O BOTÃO NOVO AQUI NO FIM
        ],
      ),
    );
  }

  Future<void> _handleDownloadPdf() async {
    if (_cards.isEmpty) return;
    List<String> imageUrls = _cards.map((c) => c['imageUrl'] as String).toList();
    await PdfService.generateAndPrintDeckPdf(context, imageUrls);
  }
}