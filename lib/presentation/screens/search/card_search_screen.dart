import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart'; 
import 'card_detail_screen.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/deck_provider.dart'; 
import '../../../data/providers/xp_provider.dart'; // IMPORT DO XP PROVIDER
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
  
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextPageUrl;
  String? _errorMessage; 
  
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, String>> _allSets = []; 
  Timer? _debounce;
  
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

  final Map<String, String> _scryfallHeaders = {
    'User-Agent': 'LifelinkApp/1.0',
    'Accept': '*/*'
  };

  @override
  void initState() {
    super.initState();
    _fetchFiltersData(); 
    _performSearch(""); 
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        if (!_isLoading && _hasMore && _nextPageUrl != null) {
          _fetchFromScryfall(_nextPageUrl!, isNextPage: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchFiltersData() async {
    _fetchSets(); 
    
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://api.scryfall.com/catalog/supertypes'), headers: _scryfallHeaders),
        http.get(Uri.parse('https://api.scryfall.com/catalog/card-types'), headers: _scryfallHeaders),
        http.get(Uri.parse('https://api.scryfall.com/catalog/creature-types'), headers: _scryfallHeaders),
        http.get(Uri.parse('https://api.scryfall.com/catalog/artifact-types'), headers: _scryfallHeaders),
        http.get(Uri.parse('https://api.scryfall.com/catalog/enchantment-types'), headers: _scryfallHeaders),
      ]);

      if (mounted) {
        setState(() {
          _apiCardTypes = [
            ...jsonDecode(responses[0].body)['data'],
            ...jsonDecode(responses[1].body)['data'],
          ];
          _apiCreatureTypes = List<String>.from(jsonDecode(responses[2].body)['data']);
          _apiOtherTypes = [
            ...jsonDecode(responses[3].body)['data'],
            ...jsonDecode(responses[4].body)['data'],
          ];
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar catálogos, utilizando a lista base. Erro: $e");
    }
  }

  Future<void> _fetchSets() async {
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/sets'), headers: _scryfallHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List setsData = data['data'];
        if (mounted) {
          setState(() {
            _allSets = setsData.map((s) => {'code': s['code'].toString(), 'name': s['name'].toString()}).toList();
          });
        }
      }
    } catch (e) { 
      debugPrint("Erro ao carregar sets: $e");
    }
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
    
    String q = queryText.trim().isEmpty ? "is:commander" : queryText;
    
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

    q = "$q order:name"; 

    final url = 'https://api.scryfall.com/cards/search?q=${Uri.encodeComponent(q)}';
    await _fetchFromScryfall(url);
  }

  Future<void> _fetchFromScryfall(String url, {bool isNextPage = false}) async {
    if (isNextPage) {
      setState(() => _isLoading = true);
    }
    
    try {
      final response = await http.get(Uri.parse(url), headers: _scryfallHeaders).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List cardsData = data['data'];
        
        _hasMore = data['has_more'] ?? false;
        _nextPageUrl = _hasMore ? data['next_page'] : null;

        List<Map<String, dynamic>> newCards = [];
        for (var card in cardsData) {
          String? imgUrl = card['image_uris']?['normal'] ?? 
                           card['card_faces']?[0]['image_uris']?['normal'];

          if (imgUrl != null) {
            newCards.add({
              'id': card['id'],
              'name': card['name'],
              'imageUrl': imgUrl,
              'rarity': card['rarity'],
              'color_identity': (card['color_identity'] as List?)?.join('') ?? 'C',
              'mana_cost': card['mana_cost'] ?? '',
              'type_line': card['type_line'] ?? '',
              'oracle_text': card['oracle_text'] ?? '',
              'oracle_id': card['oracle_id'], 
              'setName': card['set_name'],
            });
          }
        }
        
        if (mounted) {
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
        }
      } else {
        if (mounted) {
          setState(() { 
            _isLoading = false; 
            _errorMessage = "Scryfall bloqueou o acesso ou carta não encontrada."; 
          });
        }
      }
    } catch (e) { 
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          _errorMessage = "Erro de conexão."; 
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
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: widget.replaceCardIndex != null ? "Buscar substituta..." : "Buscar carta...",
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.5)),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 600), () => _performSearch(v));
              },
            ),
          ),
          body: _isLoading && _searchResults.isEmpty && _errorMessage == null 
            ? const Center(child: CircularProgressIndicator()) 
            : _errorMessage != null 
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ))
              : _searchResults.isEmpty 
                ? const Center(child: Text("Nenhuma carta encontrada"))
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
                            httpHeaders: const {'User-Agent': 'LifelinkApp/1.0', 'Accept': '*/*'},
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.black12),
                            errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    },
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
}