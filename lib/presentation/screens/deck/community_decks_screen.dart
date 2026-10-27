import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/providers/theme_provider.dart';
import 'community_deck_detail_screen.dart';
import '../../widgets/neon.dart';
import '../../../data/services/scryfall_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityDecksScreen extends StatefulWidget {
  const CommunityDecksScreen({super.key});

  @override
  State<CommunityDecksScreen> createState() => _CommunityDecksScreenState();
}

class _CommunityDecksScreenState extends State<CommunityDecksScreen> {
  bool _isLoading = true;
  List<dynamic> _commanderDecks = [];
  List<dynamic> _challengerDecks = [];
  List<dynamic> _secretLairDecks = [];
  List<dynamic> _otherDecks = []; // decks para começar (Starter, Planeswalker, Avatar...)
  
  int _selectedCategory = 0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String? _errorMessage;

  final Map<String, List<String>> _coverCache = {};
  final Set<String> _loadingCovers = {};
  final List<String> _queue = [];
  bool _isProcessingQueue = false;
  final String _cardBackUrl = CardImages.cardBack;

  static const Map<String, String> _headers = {
    'User-Agent': 'LifelinkApp/1.0',
    'Accept': 'application/json',
  };

  // A lista de decks guardada enquanto o app está aberto (e por 1 dia no
  // aparelho): não baixa tudo de novo a cada visita.
  static String? _listCache;
  static const _listKey = 'mtgjson_decklist_v1';
  static const _coversKey = 'mtgjson_covers_v1';

  @override
  void initState() {
    super.initState();
    _loadSavedCovers();
    _fetchOfficialDecks();
  }

  /// As capas já descobertas antes (as cartas de cada deck não mudam).
  Future<void> _loadSavedCovers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_coversKey);
      if (raw == null || !mounted) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        for (final e in map.entries) {
          _coverCache.putIfAbsent(e.key, () => [for (final u in e.value as List) u.toString()]);
        }
      });
    } catch (_) {}
  }

  Future<void> _saveCovers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coversKey, jsonEncode(_coverCache));
    } catch (_) {}
  }

  Future<String> _deckListJson() async {
    if (_listCache != null) return _listCache!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_listKey);
    final savedAt = prefs.getInt('${_listKey}_at') ?? 0;
    if (saved != null && DateTime.now().millisecondsSinceEpoch - savedAt < const Duration(days: 1).inMilliseconds) {
      return _listCache = saved;
    }
    try {
      final body = (await _fetchWithRetry('https://mtgjson.com/api/v5/DeckList.json')).body;
      prefs.setString(_listKey, body);
      prefs.setInt('${_listKey}_at', DateTime.now().millisecondsSinceEpoch);
      return _listCache = body;
    } catch (_) {
      // Sem internet: usa a lista antiga, se tiver.
      if (saved != null) return _listCache = saved;
      rethrow;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Direto no MTGJSON (tenta duas vezes).
  Future<http.Response> _fetchWithRetry(String url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(Uri.parse(url), headers: kIsWeb ? null : _headers).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) return response;
      } catch (_) {}
    }
    throw Exception("Falha de rede");
  }

  Future<void> _fetchOfficialDecks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = jsonDecode(await _deckListJson());
      List<dynamic> allDecks = data['data'] ?? [];

      List<dynamic> commander = [];
      List<dynamic> challenger = [];
      List<dynamic> secretLair = [];
      List<dynamic> others = [];

      for (var deck in allDecks) {
        final type = (deck['type'] ?? '').toString().toLowerCase();
        final name = (deck['name'] ?? '').toString().toLowerCase();

        if (type.contains('secret lair')) {
          secretLair.add(deck);
        } else if (name.contains('avatar') || name.contains('aang') || name.contains('zuko')) {
          others.add(deck);
        } else if (type.contains('commander')) {
          commander.add(deck);
        } else if (type.contains('challenger')) {
          challenger.add(deck);
        } else if (type.contains('starter') || type.contains('planeswalker')) {
          others.add(deck);
        }
      }

      int compare(a, b) => (b['releaseDate'] ?? '').toString().compareTo((a['releaseDate'] ?? '').toString());
      commander.sort(compare);
      challenger.sort(compare);
      secretLair.sort(compare);
      others.sort(compare);

      if (mounted) {
        setState(() {
          _commanderDecks = commander;
          _challengerDecks = challenger;
          _secretLairDecks = secretLair;
          _otherDecks = others;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _errorMessage = "Erro ao carregar lista de decks.\nVerifique sua conexão."; 
          _isLoading = false; 
        });
      }
    }
  }

  void _queueDeckCover(String fileName) {
    if (_coverCache.containsKey(fileName) || _loadingCovers.contains(fileName) || _queue.contains(fileName)) {
      return;
    }
    _queue.add(fileName);
    // Só as capas dos decks que passaram na tela por último: rolando a lista
    // inteira, as de cima saem da fila em vez de virar centenas de downloads.
    while (_queue.length > 12) {
      _queue.removeAt(0);
    }
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    while (_queue.isNotEmpty) {
      if (!mounted) {
        break;
      }
      String fileName = _queue.removeLast(); // o mais recente (o que está na tela)
      _loadingCovers.add(fileName);
      try {
        final response = await _fetchWithRetry('https://mtgjson.com/api/v5/decks/$fileName.json');
        final data = jsonDecode(response.body)['data'];
        List<String> foundUrls = [];
        List<dynamic> candidates = [...(data['commander'] ?? []), ...(data['mainBoard'] ?? [])];
        for (var item in candidates) {
          if (foundUrls.length >= 3) {
            break;
          }
          String? id = item['identifiers']?['scryfallId'];
          if (id != null) {
            foundUrls.add('https://cards.scryfall.io/normal/front/${id[0]}/${id[1]}/$id.jpg');
          }
        }
        while (foundUrls.length < 3) {
          foundUrls.add(_cardBackUrl);
        }
        if (mounted) {
          setState(() => _coverCache[fileName] = foundUrls);
          _saveCovers();
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _isProcessingQueue = false;
  }

  List<dynamic> _getFilteredDecks() {
    List<dynamic> baseList;
    if (_selectedCategory == 0) {
      baseList = _commanderDecks;
    } else if (_selectedCategory == 1) {
      baseList = _challengerDecks;
    } else if (_selectedCategory == 2) {
      baseList = _secretLairDecks;
    } else {
      baseList = _otherDecks;
    }

    if (_searchQuery.isEmpty) return baseList;
    return baseList.where((deck) => deck['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isLight = theme.backgroundColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final filteredDecks = _getFilteredDecks();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent, 
            elevation: 0, 
            iconTheme: IconThemeData(color: textColor),
            title: Text("Decks oficiais", style: TextStyle(color: textColor)),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Pesquisar deck...",
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  _buildCategorySelector(textColor),
                  Expanded(
                    child: _errorMessage != null
                      ? StatusMessage(
                          icon: Icons.wifi_off,
                          color: AreaColors.official,
                          title: "Não deu para carregar os decks",
                          message: "Confira a internet e tente de novo.",
                          actionLabel: "Tentar de novo",
                          onAction: _fetchOfficialDecks,
                        )
                      : filteredDecks.isEmpty
                        ? StatusMessage(
                            icon: Icons.search_off,
                            color: AreaColors.official,
                            title: "Nenhum deck encontrado",
                            message: "Tente outro nome ou outra categoria.",
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
                            ),
                            itemCount: filteredDecks.length,
                            itemBuilder: (context, index) {
                              final deck = filteredDecks[index];
                              if (!_coverCache.containsKey(deck['fileName'])) {
                                _queueDeckCover(deck['fileName']);
                              }
                              return _buildDeckCard(context, deck, _coverCache[deck['fileName']] ?? [_cardBackUrl, _cardBackUrl, _cardBackUrl], isLight, textColor);
                            },
                          ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(Color textColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _categoryButton("Commander", 0),
          const SizedBox(width: 8),
          _categoryButton("Challenger", 1),
          const SizedBox(width: 8),
          _categoryButton("Secret Lair", 2),
          const SizedBox(width: 8),
          _categoryButton("Iniciante", 3),
        ],
      ),
    );
  }

  Widget _categoryButton(String label, int index) {
    bool sel = _selectedCategory == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AreaColors.official : AreaColors.official.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AreaColors.official, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, dynamic deck, List<String> coverImages, bool isLight, Color textColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDeckDetailScreen(
          deckData: deck,
        )));
      },
      child: Container(
        decoration: neonDecoration(AreaColors.official, neonSurface(context, context.read<ThemeProvider>().backgroundColor), glow: 0.15),
        child: Column(
          children: [
            Expanded(flex: 5, child: CommunityDeckCoverWidget(isLight: isLight, imageUrls: coverImages)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck['name'] ?? "Deck", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(deck['releaseDate'] ?? "", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CommunityDeckCoverWidget extends StatelessWidget {
  final bool isLight;
  final List<String> imageUrls;
  const CommunityDeckCoverWidget({super.key, required this.isLight, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    const double angle10 = 10 * pi / 180;
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(offset: const Offset(-18, 8), child: Transform.rotate(angle: -angle10, child: _buildCardImg(imageUrls[2], 80, 110))),
          Transform.translate(offset: const Offset(18, 8), child: Transform.rotate(angle: angle10, child: _buildCardImg(imageUrls[1], 80, 110))),
          Transform.translate(offset: const Offset(0, -5), child: _buildCardImg(imageUrls[0], 90, 125)),
        ],
      ),
    );
  }

  Widget _buildCardImg(String url, double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), 
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8), 
        child: CachedNetworkImage(
          imageUrl: url, 
          httpHeaders: CardImages.headers,
          memCacheWidth: 200, // a capa é pequena: não decodifica a imagem inteira
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: Colors.black26),
          errorWidget: (c, u, e) => Container(color: Colors.black26),
        ),
      ),
    );
  }
}