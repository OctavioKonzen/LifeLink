import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart'; 
import 'card_detail_screen.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/deck_provider.dart'; 
import '../../../data/providers/xp_provider.dart'; // IMPORT DO XP PROVIDER
import '../../../data/services/scryfall_service.dart';
import '../../widgets/custom_back_button.dart';

class CardSearchScreen extends StatefulWidget {
  final int? targetDeckIndex; 
  final int? replaceCardIndex;

  const CardSearchScreen({super.key, this.targetDeckIndex, this.replaceCardIndex});

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
  
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, String>> _allSets = []; 
  Timer? _debounce;
  Timer? _suggestDebounce;
  List<String> _suggestions = [];
  List<String> _recentSearches = [];
  int _searchId = 0; // descarta respostas de buscas antigas
  
  final List<String> _selectedTypes = [];
  final List<String> _selectedColors = []; 
  String? _selectedSet; 

  List<String> _apiCardTypes = [
    "Artifact", "Battle", "Creature", "Enchantment", "Instant", "Land", "Planeswalker", "Sorcery", 
    "Basic", "Legendary", "Ongoing", "Snow", "World"
  ];
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
        if (!_isLoading && _hasMore && _nextPageUrl != null) {
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
      _scryfall.catalog('supertypes'),
      _scryfall.catalog('card-types'),
      _scryfall.catalog('creature-types'),
      _scryfall.catalog('artifact-types'),
      _scryfall.catalog('enchantment-types'),
    ]);
    if (!mounted) return;
    setState(() {
      if (lists[0] != null && lists[1] != null) _apiCardTypes = [...lists[0]!, ...lists[1]!];
      if (lists[2] != null) _apiCreatureTypes = lists[2]!;
      if (lists[3] != null && lists[4] != null) _apiOtherTypes = [...lists[3]!, ...lists[4]!];
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
      final names = await _scryfall.autocomplete(v);
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
    final list = await _scryfall.addRecentSearch(text);
    if (mounted) setState(() => _recentSearches = list);
  }

  Future<void> _performSearch(String queryText) async {
    if (!mounted) return;
    
    // GATILHO: AUMENTA O CONTADOR DE PESQUISAS DE CARTAS
    context.read<XpProvider>().incrementSearches();
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _hasMore = true;
      _nextPageUrl = null;
      _errorMessage = null; 
    });
    
    String q = queryText.trim().isEmpty ? "is:commander" : ScryfallService.buildTextQuery(queryText);
    
    if (_selectedTypes.isNotEmpty) {
      final typeQuery = _selectedTypes.map((t) => 't:"$t"').join(" or ");
      q = "$q ($typeQuery)";
    }
    
    if (_selectedColors.isNotEmpty) {
      q = "$q id<=${_selectedColors.join('')}";
    }
    if (_selectedSet != null) {
      q = "$q set:$_selectedSet";
    }

    await _fetchFromScryfall(query: q);
  }

  Future<void> _fetchFromScryfall({String? query, String? nextPage}) async {
    final isNextPage = nextPage != null;
    final id = isNextPage ? _searchId : ++_searchId;
    if (isNextPage) {
      setState(() => _isLoading = true);
    }
    
    try {
      final page = await _scryfall.search(query ?? '', nextPage: nextPage);
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
            'usdPrice': card['prices']?['usd'] ?? '0.00',
          });
        }
      }

      if (widget.targetDeckIndex != null && widget.replaceCardIndex == null) {
        final deckProvider = context.read<DeckProvider>();
        if (widget.targetDeckIndex! < deckProvider.allDecks.length) {
          final existingCards = deckProvider.allDecks[widget.targetDeckIndex!].cards;
          final existingNames = existingCards.map((c) => c['name']?.toString() ?? '').toSet();
          newCards.removeWhere((card) => existingNames.contains(card['name']));
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
    } on ScryfallException catch (e) {
      if (mounted && id == _searchId) {
        setState(() { 
          _isLoading = false; 
          _hasMore = false;
          if (isNextPage) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          } else {
            _errorMessage = e.message;
          }
        });
      }
    }
  }

  void _showFilters(BuildContext context, Color bgColor, Color textColor) {
    final PageController pageController = PageController();

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(children: [
              const SizedBox(height: 20),
              Text("Filtros", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ["W", "U", "B", "R", "G", "C"].map((mana) {
                    bool isSel = _selectedColors.contains(mana);
                    return GestureDetector(
                      onTap: () {
                        setModalState(() {
                          if (isSel) {
                            _selectedColors.remove(mana);
                          } else {
                            _selectedColors.add(mana);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 45, height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? Colors.blueAccent : Colors.transparent, width: 3),
                        ),
                        child: Opacity(
                          opacity: isSel ? 1.0 : 0.4,
                          child: SvgPicture.network(
                            "https://svgs.scryfall.io/card-symbols/$mana.svg",
                            headers: const {'User-Agent': 'LifelinkApp/1.0'},
                            placeholderBuilder: (context) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor, size: 18), onPressed: () => pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                  Text("Arraste para o lado", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                  IconButton(icon: Icon(Icons.arrow_forward_ios, color: textColor, size: 18), onPressed: () => pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                ]),
              ),

              Expanded(
                child: PageView(
                  controller: pageController,
                  children: [
                    _buildPage("Tipos & Super Tipos", _apiCardTypes, setModalState, textColor),
                    _buildPage("Raças (Criaturas)", _apiCreatureTypes, setModalState, textColor),
                    _buildPage("Artefatos & Encantamentos", _apiOtherTypes, setModalState, textColor),
                    _buildSetsPage(setModalState, textColor),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(25),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () {
                      setState(() { 
                        _selectedTypes.clear(); 
                        _selectedColors.clear(); 
                        _selectedSet = null; 
                      });
                      Navigator.pop(context);
                      _performSearch("");
                    }, 
                    child: const Text("Limpar")
                  )),
                  const SizedBox(width: 20),
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(0, 60)),
                    onPressed: () {
                      Navigator.pop(context);
                      _performSearch(_searchController.text);
                    }, 
                    child: const Text("APLICAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )),
                ]),
              ),
            ]),
          );
        }
      ),
    );
  }

  Widget _buildPage(String title, List<String> options, StateSetter setModalState, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((t) {
          bool isSel = _selectedTypes.contains(t);
          return FilterChip(
            label: Text(t, style: TextStyle(color: isSel ? Colors.white : textColor, fontSize: 13)),
            selected: isSel,
            onSelected: (v) {
              setModalState(() {
                if (v) {
                  _selectedTypes.add(t);
                } else {
                  _selectedTypes.remove(t);
                }
              });
            },
            selectedColor: Colors.blueAccent,
            checkmarkColor: Colors.white,
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildSetsPage(StateSetter setModalState, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text("EDIÇÕES / SETS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _allSets.length,
            itemBuilder: (context, index) {
              final set = _allSets[index];
              bool isSel = _selectedSet == set['code'];
              return ListTile(
                title: Text(set['name']!, style: TextStyle(color: isSel ? Colors.blueAccent : textColor)),
                trailing: isSel ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
                onTap: () {
                  setModalState(() {
                    if (isSel) {
                      _selectedSet = null;
                    } else {
                      _selectedSet = set['code'];
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
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
            automaticallyImplyLeading: false, 
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
          ),
          body: Stack(
            children: [
              _buildResults(textColor),
              if (_searchFocus.hasFocus) _buildSuggestions(theme.backgroundColor, textColor),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: () => _showFilters(context, theme.backgroundColor, textColor),
            child: const Icon(Icons.filter_list, color: Colors.white),
          ),
        ),
        const CustomBackButton(),
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
                : GridView.builder(
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
                              targetDeckIndex: widget.targetDeckIndex,
                              replaceCardIndex: widget.replaceCardIndex, 
                            )
                          ));
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: card['imageUrl'], 
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (c, u) => Container(color: Colors.black12),
                            errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  );
  }
}