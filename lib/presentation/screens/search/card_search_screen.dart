import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'card_detail_screen.dart';
import 'card_scan_screen.dart';
import 'card_filters_sheet.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/xp_provider.dart';
import '../../../data/services/scryfall_service.dart';
import '../../../data/services/lifelink_cards.dart';
import '../../theme/app_theme.dart';

class CardSearchScreen extends StatefulWidget {
  final String? targetDeckId; // adicionando cartas a este deck
  final int? replaceCardIndex;

  const CardSearchScreen({super.key, this.targetDeckId, this.replaceCardIndex});

  @override
  State<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends State<CardSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocus = FocusNode();
  final ScryfallService _scryfall = ScryfallService.instance;
  
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextPageUrl;
  String? _errorMessage; 
  String _lastText = '';
  
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, String>> _allSets = []; 
  Timer? _debounce;
  Timer? _suggestDebounce;
  List<String> _suggestions = [];
  List<String> _recentSearches = [];
  int _searchId = 0; // descarta respostas de buscas antigas
  
  CardFilters _filters = const CardFilters();

  List<String> _apiCreatureTypes = [
    "Alien", "Angel", "Archer", "Artificer", "Assassin", "Avatar", "Barbarian", "Bear", "Beast", 
    "Bird", "Boar", "Cat", "Centaur", "Cleric", "Construct", "Demon", "Dinosaur", "Dog", "Dragon", 
    "Drake", "Druid", "Dwarf", "Eldrazi", "Elemental", "Elephant", "Elf", "Faerie", "Fish", "Fox", 
    "Frog", "Fungus", "Giant", "God", "Golem", "Goblin", "Griffin", "Human", "Hydra", "Illusion", 
    "Insect", "Juggernaut", "Kavu", "Kithkin", "Knight", "Kor", "Kraken", "Leviathan", "Lizard", 
    "Manticore", "Mercenary", "Merfolk", "Minotaur", "Monk", "Mutant", "Myr", "Mystic", "Naga", 
    "Ninja", "Noble", "Ogre", "Ooze", "Orc", "Pegasus", "Phyrexian", "Pilot", "Pirate", "Plant", 
    "Ranger", "Rat", "Rebel", "Rogue", "Samurai", "Scout", "Shaman", "Shapeshifter", "Skeleton", 
    "Slime", "Sliver", "Soldier", "Soltari", "Sphinx", "Spider", "Spirit", "Squirrel", "Thopter", 
    "Treefolk", "Troll", "Turtle", "Unicorn", "Vampire", "Vedalken", "Wall", "Warrior", "Weird", 
    "Werewolf", "Whale", "Wizard", "Wolf", "Wolverine", "Wurm", "Zombie"
  ];
  List<String> _apiOtherTypes = [
    "Adventure", "Arcane", "Attraction", "Aura", "Background", "Blood", "Bobblehead", 
    "Cartouche", "Clash", "Class", "Clue", "Contraption", "Curse", "Desert", "Equipment", 
    "Food", "Fortification", "Gate", "Gold", "Incubator", "Junk", "Lair", "Lesson", 
    "Locus", "Map", "Mine", "Power-Plant", "Powerstone", "Role", "Rune", "Saga", "Shard", 
    "Shrine", "Sphere", "Tower", "Trap", "Treasure", "Urza's", "Vehicle"
  ];

  @override
  void initState() {
    super.initState();
    _fetchFiltersData(); 
    _performSearch(""); 
    _scryfall.recentSearches().then((list) {
      if (mounted) setState(() => _recentSearches = list);
    });
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        if (!_isLoading && _hasMore && _ownPage != null) {
          _fetchFromLifeLink(page: _ownPage! + 1);
        } else if (!_isLoading && _hasMore && _nextPageUrl != null) {
          _fetchFromScryfall(nextPage: _nextPageUrl!);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Tipos e coleções ficam guardados no celular por 7 dias (ScryfallService),
  // então a busca abre sem esperar a internet.
  Future<void> _fetchFiltersData() async {
    _fetchSets(); 

    final lists = await Future.wait([
      _scryfall.catalog('creature-types'),
      _scryfall.catalog('artifact-types'),
      _scryfall.catalog('enchantment-types'),
    ]);
    if (!mounted) return;
    setState(() {
      if (lists[0] != null) _apiCreatureTypes = lists[0]!;
      if (lists[1] != null && lists[2] != null) _apiOtherTypes = [...lists[1]!, ...lists[2]!]..sort();
    });
  }

  Future<void> _fetchSets() async {
    final sets = await _scryfall.sets();
    if (sets != null && mounted) {
      setState(() => _allSets = sets);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _performSearch(v));
    _suggestDebounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 200), () async {
      // Nomes do banco do LifeLink (português e inglês); sem ele, da Scryfall.
      List<String> names;
      try {
        names = await LifeLinkCards.instance.names(v, lang: context.read<ThemeProvider>().cardLanguage);
      } catch (_) {
        names = await _scryfall.autocomplete(v);
      }
      if (mounted && _searchController.text == v) {
        setState(() => _suggestions = names.take(8).toList());
      }
    });
  }

  // Busca escolhida de propósito (Enter, sugestão ou recente): vai para as recentes.
  void _submitSearch(String text, {bool exactName = false}) {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _searchController.text = text;
    _searchController.selection = TextSelection.collapsed(offset: text.length);
    _searchFocus.unfocus();
    setState(() => _suggestions = []);
    _rememberSearch(text);
    _performSearch(exactName ? '!"$text"' : text);
  }

  Future<void> _rememberSearch(String text) async {
    // A busca vale XP quando a pessoa confirma (enter ou sugestão), uma vez
    // por texto: não a cada letra digitada, não a inicial e não um filtro.
    final counted = text.trim().toLowerCase();
    if (counted.length >= 2 && counted != _lastCountedSearch) {
      _lastCountedSearch = counted;
      context.read<XpProvider>().incrementSearches();
    }
    final list = await _scryfall.addRecentSearch(text);
    if (mounted) setState(() => _recentSearches = list);
  }

  String _lastCountedSearch = '';

  // (nome, ordem na Scryfall, direção)
  static const _orders = [
    ('Nome (A-Z)', 'name', null),
    ('Mais caras', 'usd', 'desc'),
    ('Mais baratas', 'usd', 'asc'),
    ('Custo de mana', 'cmc', 'asc'),
    ('Mais novas', 'released', 'desc'),
  ];
  (String, String, String?) _order = _orders.first;

  Future<void> _performSearch(String queryText) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _hasMore = true;
      _nextPageUrl = null;
      _errorMessage = null; 
    });
    
    _lastText = queryText;
    _ownPage = null;
    // Busca no banco do LifeLink (Cloudflare). Quem digitar a sintaxe da
    // Scryfall (t:dragon, o:"...") ainda vai direto na Scryfall.
    if (!RegExp(r'[:<>=]').hasMatch(queryText)) {
      if (await _fetchFromLifeLink(page: 0)) return;
    }
    String q = queryText.trim().isEmpty ? "is:commander" : ScryfallService.buildTextQuery(queryText);
    
    if (!_filters.isEmpty) q = "$q ${_filters.toQuery()}";

    await _fetchFromScryfall(query: q);
  }

  int? _ownPage; // a página da busca no banco do LifeLink (null = Scryfall)

  /// Busca no banco do LifeLink; volta false se ele não respondeu (aí a
  /// busca vai para a Scryfall).
  Future<bool> _fetchFromLifeLink({required int page}) async {
    final id = page == 0 ? ++_searchId : _searchId;
    if (page > 0) setState(() => _isLoading = true);
    var text = _lastText.trim();
    final exact = RegExp(r'^!"(.*)"$').firstMatch(text);
    if (exact != null) text = exact.group(1)!;
    final f = _filters;
    // Só a coleção escolhida (sem texto nem outro filtro): todas as cartas
    // dela na ordem dos números (1, 2, 3...).
    if (text.isEmpty && f.setCode != null && f.types.isEmpty && f.colors.isEmpty && f.race == null && f.subtype == null && _order == _orders.first) {
      try {
        final cards = await LifeLinkCards.instance.setCards(f.setCode!, lang: context.read<ThemeProvider>().cardLanguage);
        if (!mounted || id != _searchId) return true;
        if (cards.isNotEmpty) {
          setState(() {
            _searchResults = cards;
            _hasMore = false;
            _ownPage = null;
            _nextPageUrl = null;
            _isLoading = false;
            _errorMessage = null;
          });
          return true;
        }
      } catch (_) {}
    }
    // Sem texto: os comandantes mais usados (como o "is:commander" de antes).
    final types = [...f.types, ?f.race, ?f.subtype, if (text.isEmpty && f.isEmpty) 'Legendary Creature'];
    final userOrder = _order != _orders.first;
    try {
      final result = await LifeLinkCards.instance.search(
        text: text,
        nameOnly: exact != null,
        types: types,
        set: f.setCode,
        colors: f.colors.isEmpty ? null : f.colors.where((c) => c != 'C').join(),
        order: userOrder ? _order.$2 : (text.isEmpty ? 'popular' : null),
        desc: _order.$3 == 'desc',
        page: page,
        lang: context.read<ThemeProvider>().cardLanguage,
      );
      if (!mounted || id != _searchId) return true;
      setState(() {
        _searchResults = page == 0 ? result.cards : [..._searchResults, ...result.cards];
        _hasMore = result.hasMore;
        _ownPage = page;
        _nextPageUrl = null;
        _isLoading = false;
        _errorMessage = null;
      });
      return true;
    } catch (_) {
      if (page > 0 && mounted) setState(() => _isLoading = false);
      return page > 0; // na primeira página, tenta a Scryfall
    }
  }

  Future<void> _fetchFromScryfall({String? query, String? nextPage}) async {
    final isNextPage = nextPage != null;
    final id = isNextPage ? _searchId : ++_searchId;
    if (isNextPage) {
      setState(() => _isLoading = true);
    }
    
    try {
      final page = await _scryfall.search(query ?? '', order: _order.$2, dir: _order.$3, nextPage: nextPage);
      if (!mounted || id != _searchId) return;

      _hasMore = page.hasMore;
      _nextPageUrl = page.nextPage;

      List<Map<String, dynamic>> newCards = [];
      for (var card in page.cards) {
        final imgUrl = CardImages.normalOf(card);
        if (imgUrl != null) {
          newCards.add({
            'id': card['id'],
            'name': card['printed_name'] ?? card['name'],
            'imageUrl': imgUrl,
            // Carta de duas faces: a imagem do outro lado (girar a carta mostra).
            'backImageUrl': card['card_faces']?[1]?['image_uris']?['normal'],
            'rarity': card['rarity'],
            'color_identity': (card['color_identity'] as List?)?.join('') ?? 'C',
            'mana_cost': card['mana_cost'] ?? card['card_faces']?[0]?['mana_cost'] ?? '',
            'type_line': card['printed_type_line'] ?? card['type_line'] ?? '',
            'oracle_text': card['printed_text'] ?? card['oracle_text'] ?? card['card_faces']?[0]?['oracle_text'] ?? '',
            'oracle_id': card['oracle_id'], 
            'setName': card['set_name'],
            'cmc': card['cmc'],
            'power': card['power']?.toString(),
            'toughness': card['toughness']?.toString(),
            'collectorNumber': card['collector_number'],
            'usdPrice': card['prices']?['usd'] ?? card['prices']?['usd_foil'] ?? card['prices']?['usd_etched'] ?? '0.00',
            'usdFoil': card['prices']?['usd_foil'],
            'eurPrice': card['prices']?['eur'],
            'tixPrice': card['prices']?['tix'],
          });
        }
      }

      setState(() {
        if (isNextPage) {
          _searchResults.addAll(newCards);
        } else {
          _searchResults = newCards;
        }
        _isLoading = false;
        _errorMessage = null; 
      });
    } catch (e) {
      // Qualquer erro (não só os da Scryfall) para o carregando.
      final message = e is ScryfallException ? e.message : 'Não deu para buscar agora. Tente de novo.';
      if (mounted && id == _searchId) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
          if (isNextPage) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          } else {
            _errorMessage = message;
          }
        });
      }
    }
  }

  Future<void> _showFilters(BuildContext context, Color bgColor, Color textColor) async {
    final result = await showCardFilters(
      context,
      current: _filters,
      sets: _allSets,
      races: _apiCreatureTypes,
      subtypes: _apiOtherTypes,
      background: bgColor,
      textColor: textColor,
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _performSearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            title: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.replaceCardIndex != null ? "Buscar substituta..." : "Nome ou texto da carta...",
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.5)),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.5)),
                        tooltip: "Limpar",
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {}); // mostra/esconde o botão de limpar
                _onSearchChanged(v);
              },
              onSubmitted: (v) => _submitSearch(v),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.document_scanner, color: textColor),
                tooltip: 'Escanear carta com a câmera',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardScanScreen(targetDeckId: widget.targetDeckId))),
              ),
              // Ordem dos resultados.
              PopupMenuButton<int>(
                icon: Icon(Icons.sort, color: textColor),
                tooltip: 'Ordenar',
                onSelected: (i) {
                  setState(() => _order = _orders[i]);
                  _performSearch(_searchController.text);
                },
                itemBuilder: (_) => [
                  for (var i = 0; i < _orders.length; i++)
                    CheckedPopupMenuItem(value: i, checked: _orders[i] == _order, child: Text(_orders[i].$1)),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              _buildResults(textColor),
              if (_searchFocus.hasFocus) _buildSuggestions(theme.backgroundColor, textColor),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: LL.gold,
            onPressed: () => _showFilters(context, theme.backgroundColor, textColor),
            child: const Icon(Icons.filter_list, color: LL.onGold),
          ),
        ),
      ],
    );
  }

  // Sugestões do Scryfall enquanto digita; com o campo vazio, as buscas recentes.
  Widget _buildSuggestions(Color bgColor, Color textColor) {
    final typing = _searchController.text.trim().isNotEmpty;
    final items = typing ? _suggestions : _recentSearches;
    if (items.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: bgColor,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              if (!typing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(children: [
                    Expanded(child: Text("BUSCAS RECENTES", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: () async {
                        await _scryfall.clearRecentSearches();
                        if (mounted) setState(() => _recentSearches = []);
                      },
                      child: const Text("Limpar"),
                    ),
                  ]),
                ),
              ...items.map((text) => ListTile(
                    dense: true,
                    leading: Icon(typing ? Icons.search : Icons.history, color: textColor.withValues(alpha: 0.5), size: 20),
                    title: Text(text, style: TextStyle(color: textColor)),
                    onTap: () => _submitSearch(text, exactName: typing),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(Color textColor) {
    return _isLoading && _searchResults.isEmpty && _errorMessage == null 
            ? const Center(child: CircularProgressIndicator()) 
            : _errorMessage != null 
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tentar de novo"),
                      onPressed: () => _performSearch(_searchController.text),
                    ),
                  ]),
                ))
              : _searchResults.isEmpty 
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Nenhuma carta encontrada.\nTente outro nome, em português ou inglês, ou uma palavra do texto da carta.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                    ),
                  ))
                : Column(children: [
                  Expanded(child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.68, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: _searchResults.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _searchResults.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final card = _searchResults[index];
                      return GestureDetector(
                        onTap: () {
                          // Achou o que queria: a busca digitada vai para as recentes.
                          if (_searchController.text.trim().isNotEmpty) _rememberSearch(_searchController.text);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => CardDetailScreen(
                              card: card, 
                              targetDeckId: widget.targetDeckId,
                              replaceCardIndex: widget.replaceCardIndex, 
                            )
                          ));
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: card['imageUrl'], 
                            memCacheWidth: 320, // miniatura: não decodifica a imagem inteira
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (c, u) => Container(color: Colors.black12),
                            // Sem internet (ou sem imagem): o nome e o tipo da carta.
                            errorWidget: (c, u, e) => Container(
                              color: Colors.black26,
                              padding: const EdgeInsets.all(6),
                              alignment: Alignment.center,
                              child: Text('${card['name']}\n\n${card['type_line'] ?? ''}',
                                  textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      );
                    },
                  )),
                ]);
  }
}