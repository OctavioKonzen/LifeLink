import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XpProvider extends ChangeNotifier {
  int _xp = 0;
  int _level = 1;
  Timer? _appTimeTimer;

  // --- VARIÁVEIS DE MISSÕES E COSMÉTICOS ---
  int _currentTier = 1;
  List<String> _claimedMissions = ["0", "0", "0", "0", "0"]; 
  List<String> _unlockedAvatars = [];
  List<String> _unlockedBorders = ["0"]; 
  List<String> _unlockedTitles = [];
  
  // --- SISTEMA DE BANNERS ---
  int _totalMatchesPlayed = 0;
  List<String> _unlockedBanners = ["0"]; 
  String _selectedBannerId = "0";

  String _selectedAvatar = "";
  String _selectedBorderId = "0";
  String _selectedTitle = "";

  // --- CONTADORES PARA MISSÕES ---
  int _statDecksCreated = 0;
  int _statCardsAdded = 0;
  int _statSearches = 0;
  int _statArtsViewed = 0;

  // Getters
  int get xp => _xp;
  int get level => _level;
  int get currentTier => _currentTier;
  List<String> get claimedMissions => _claimedMissions;
  List<String> get unlockedAvatars => _unlockedAvatars;
  List<String> get unlockedBorders => _unlockedBorders;
  List<String> get unlockedTitles => _unlockedTitles;
  List<String> get unlockedBanners => _unlockedBanners;
  String get selectedAvatar => _selectedAvatar;
  String get selectedBorderId => _selectedBorderId;
  String get selectedTitle => _selectedTitle;
  String get selectedBannerId => _selectedBannerId;
  int get totalMatchesPlayed => _totalMatchesPlayed;

  int get statDecksCreated => _statDecksCreated;
  int get statCardsAdded => _statCardsAdded;
  int get statSearches => _statSearches;
  int get statArtsViewed => _statArtsViewed;
  
  int get xpForNextLevel => _level * _level * 100;

  // --- BANCO DE DADOS DE BANNERS (Cores Corrigidas com const) ---
  static final List<Map<String, dynamic>> allBanners = [
    {'id': '0', 'name': 'Planície Central', 'colors': const [Color(0xFF4B4B4B), Color(0xFF1A1A1A)]},
    {'id': '1', 'name': 'Bosque Élfico', 'colors': const [Color(0xFF2D5A27), Color(0xFF0F200B)]},
    {'id': '2', 'name': 'Cascata de Safira', 'colors': const [Color(0xFF1E4D6B), Color(0xFF0A1A24)]},
    {'id': '3', 'name': 'Cripta de Sangue', 'colors': const [Color(0xFF6B1E1E), Color(0xFF240A0A)]},
    {'id': '4', 'name': 'Pico do Dragão', 'colors': const [Color(0xFFB35F1A), Color(0xFF3D2009)]},
    {'id': '5', 'name': 'Vazio Abissal', 'colors': const [Color(0xFF4A1A6B), Color(0xFF180824)]},
    {'id': '6', 'name': 'Alvorada Dourada', 'colors': const [Color(0xFFB3971A), Color(0xFF3D3409)]},
    {'id': '7', 'name': 'Névoa Etérea', 'colors': const [Color(0xFF1A6B62), Color(0xFF082421)]},
    {'id': '8', 'name': 'Cidadela de Aço', 'colors': const [Color(0xFF5A6B7A), Color(0xFF1E2429)]},
    {'id': '9', 'name': 'Horizonte Neon', 'colors': const [Color(0xFF6B1A4D), Color(0xFF24081A)]},
    {'id': '10', 'name': 'Aura Mítica', 'colors': const [Color(0xFFB31A1A), Color(0xFF3D0909)]},
  ];

  static final List<Map<String, dynamic>> allBorders = [
    {'id': '0', 'name': 'Padrão', 'colors': [Colors.grey.shade400, Colors.grey.shade700]},
    {'id': '1', 'name': 'Madeira Rústica', 'colors': [Colors.brown.shade400, Colors.brown.shade800]},
    {'id': '2', 'name': 'Prata Arcana', 'colors': [Colors.grey.shade300, Colors.white, Colors.grey.shade500]},
    {'id': '3', 'name': 'Ouro de Ravnica', 'colors': [Colors.amber, Colors.yellow, Colors.amber.shade700]},
    {'id': '4', 'name': 'Mítico Sangrento', 'colors': [Colors.deepOrange, Colors.red, Colors.orangeAccent]},
    {'id': '5', 'name': 'Mana Fluente', 'colors': const [Colors.white, Colors.blue, Colors.black87, Colors.red, Colors.green]},
    {'id': '6', 'name': 'Gelo Eterno', 'colors': [Colors.cyanAccent, Colors.lightBlue, Colors.white]},
    {'id': '7', 'name': 'Fogo Caótico', 'colors': [Colors.redAccent, Colors.orange, Colors.yellowAccent]},
    {'id': '8', 'name': 'Corrupção Phyrexiana', 'colors': [Colors.greenAccent, Colors.black87, Colors.green.shade900]},
    {'id': '9', 'name': 'Vazio Cósmico', 'colors': [Colors.deepPurple, Colors.black, Colors.purpleAccent]},
    {'id': '10', 'name': 'Neon Kamigawa', 'colors': [Colors.pinkAccent, Colors.cyanAccent, Colors.yellowAccent]},
    {'id': '11', 'name': 'Eternidade Divina', 'colors': [Colors.yellow, Colors.white, Colors.amberAccent]},
    {'id': '12', 'name': 'Folhas de Llanowar', 'colors': [Colors.lightGreen, Colors.green, Colors.greenAccent]},
    {'id': '13', 'name': 'Aço Mirrodiano', 'colors': [Colors.blueGrey, Colors.grey, Colors.cyan]},
    {'id': '14', 'name': 'Sombras de Innistrad', 'colors': [Colors.black87, Colors.red.shade900, Colors.black]},
    {'id': '15', 'name': 'Areias de Amonkhet', 'colors': [Colors.orange.shade200, Colors.amber.shade100, Colors.yellow.shade700]},
    {'id': '16', 'name': 'Relâmpago Izzet', 'colors': [Colors.blueAccent, Colors.redAccent, Colors.blueAccent]},
    {'id': '17', 'name': 'Essência Simic', 'colors': [Colors.teal, Colors.greenAccent, Colors.tealAccent]},
    {'id': '18', 'name': 'Julgamento Azorius', 'colors': [Colors.indigo, Colors.lightBlue, Colors.indigoAccent]},
    {'id': '19', 'name': 'Fúria Rakdos', 'colors': [Colors.red, Colors.black, Colors.redAccent]},
    {'id': '20', 'name': 'Aura do Multiverso', 'colors': const [Colors.purple, Colors.blue, Colors.green, Colors.yellow, Colors.red]},
  ];

  static final List<String> allTitles = [
    "Novato do Mesão", "Mago de Batalha", "Colecionador de Relíquias", "Estrategista Astuto",
    "Andarilho dos Planos", "Mestre das Fichas", "Senhor dos Zumbis", "Conjurador de Feitiços",
    "Comandante Lendário", "Arquiteto de Decks", "Arauto da Destruição", "Guardião da Luz",
    "Manipulador do Tempo", "Forjador de Artefatos", "Voz dos Pretores", "Campeão de Ravnica",
    "Ilusionista Nato", "Domador de Dragões", "Sobrevivente do Apocalipse", "Deus do Magic"
  ];

  XpProvider() {
    _loadData();
    _startTimeTracking();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt('user_xp') ?? 0;
    _level = prefs.getInt('user_level') ?? 1;
    _currentTier = prefs.getInt('user_tier') ?? 1;
    _claimedMissions = prefs.getStringList('claimed_missions') ?? ["0", "0", "0", "0", "0"];
    _unlockedAvatars = prefs.getStringList('unlocked_avatars') ?? [];
    _unlockedBorders = prefs.getStringList('unlocked_borders') ?? ["0"];
    _unlockedTitles = prefs.getStringList('unlocked_titles') ?? [];
    _unlockedBanners = prefs.getStringList('unlocked_banners') ?? ["0"];
    _selectedAvatar = prefs.getString('selected_avatar') ?? "";
    _selectedBorderId = prefs.getString('selected_border') ?? "0";
    _selectedTitle = prefs.getString('selected_title') ?? "";
    _selectedBannerId = prefs.getString('selected_banner') ?? "0";
    _totalMatchesPlayed = prefs.getInt('total_matches') ?? 0;
    _statDecksCreated = prefs.getInt('stat_decks') ?? 0;
    _statCardsAdded = prefs.getInt('stat_cards') ?? 0;
    _statSearches = prefs.getInt('stat_searches') ?? 0;
    _statArtsViewed = prefs.getInt('stat_arts') ?? 0;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('user_xp', _xp);
    prefs.setInt('user_level', _level);
    prefs.setInt('user_tier', _currentTier);
    prefs.setStringList('claimed_missions', _claimedMissions);
    prefs.setStringList('unlocked_avatars', _unlockedAvatars);
    prefs.setStringList('unlocked_borders', _unlockedBorders);
    prefs.setStringList('unlocked_titles', _unlockedTitles);
    prefs.setStringList('unlocked_banners', _unlockedBanners);
    prefs.setString('selected_avatar', _selectedAvatar);
    prefs.setString('selected_border', _selectedBorderId);
    prefs.setString('selected_title', _selectedTitle);
    prefs.setString('selected_banner', _selectedBannerId);
    prefs.setInt('total_matches', _totalMatchesPlayed);
    prefs.setInt('stat_decks', _statDecksCreated);
    prefs.setInt('stat_cards', _statCardsAdded);
    prefs.setInt('stat_searches', _statSearches);
    prefs.setInt('stat_arts', _statArtsViewed);
  }

  String? incrementMatches() {
    _totalMatchesPlayed++;
    addXp(50);
    _saveData();
    notifyListeners();

    if (_totalMatchesPlayed > 0 && (_totalMatchesPlayed & (_totalMatchesPlayed - 1)) == 0) {
      int nextBannerIndex = _unlockedBanners.length;
      if (nextBannerIndex < allBanners.length) {
        String newId = allBanners[nextBannerIndex]['id'];
        if (!_unlockedBanners.contains(newId)) {
          _unlockedBanners.add(newId);
          _saveData();
          notifyListeners();
          return allBanners[nextBannerIndex]['name'];
        }
      }
    }
    return null;
  }

  void selectBanner(String id) { _selectedBannerId = id; _saveData(); notifyListeners(); }
  void incrementDecksCreated() { _statDecksCreated++; addXp(100); _saveData(); notifyListeners(); }
  void incrementCardsAdded(int amount) { _statCardsAdded += amount; addXp(5 * amount); _saveData(); notifyListeners(); }
  void incrementSearches() { _statSearches++; addXp(5); _saveData(); notifyListeners(); }
  void incrementArtsViewed() { _statArtsViewed++; addXp(10); _saveData(); notifyListeners(); }

  void addXp(int amount) {
    _xp += amount;
    while (_xp >= xpForNextLevel) { _level++; }
    _saveData();
    notifyListeners();
  }

  void claimMission(int index) { _claimedMissions[index] = "1"; _saveData(); notifyListeners(); }
  void advanceTier() { _currentTier++; _claimedMissions = ["0", "0", "0", "0", "0"]; _saveData(); notifyListeners(); }

  void unlockReward(String type, String value) {
    if (type == 'avatar' && !_unlockedAvatars.contains(value)) _unlockedAvatars.add(value);
    if (type == 'border' && !_unlockedBorders.contains(value)) _unlockedBorders.add(value);
    if (type == 'title' && !_unlockedTitles.contains(value)) {
      _unlockedTitles.add(value);
      if (_selectedTitle.isEmpty) _selectedTitle = value;
    }
    _saveData();
    notifyListeners();
  }

  void selectAvatar(String url) { _selectedAvatar = url; _saveData(); notifyListeners(); }
  void selectBorder(String id) { _selectedBorderId = id; _saveData(); notifyListeners(); }
  void selectTitle(String title) { _selectedTitle = title; _saveData(); notifyListeners(); }

  void _startTimeTracking() { _appTimeTimer = Timer.periodic(const Duration(minutes: 5), (timer) => addXp(10)); }

  @override
  void dispose() { _appTimeTimer?.cancel(); super.dispose(); }
}