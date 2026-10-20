import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

class ThemeProvider with ChangeNotifier {
  Color _backgroundColor = const Color(0xFF1E1E24); 
  String _playerName = "Player 1";
  String _cardLanguage = "pt"; 

  // Mapa com as cores que você pediu
  final Map<String, Color> availableColors = {
    "Rosa Claro": const Color(0xFFF8BBD0),
    "Azul Claro": const Color(0xFFB3E5FC),
    "Verde Claro": const Color(0xFFC8E6C9),
    "Preto": const Color(0xFF1E1E24), 
    "Branco": const Color(0xFFF5F5F5), 
  };

  Color get backgroundColor => _backgroundColor;
  String get playerName => _playerName;
  String get cardLanguage => _cardLanguage;

  /// Termina quando as preferências salvas no aparelho foram carregadas.
  late final Future<void> ready;

  ThemeProvider() {
    ready = _loadPreferences();
    UserData.instance.register(SyncedSection(key: 'settings', read: toSync, apply: applySync));
  }

  // ignore: deprecated_member_use
  Map<String, dynamic> toSync() => {'bgColor': _backgroundColor.value, 'playerName': _playerName, 'cardLanguage': _cardLanguage};

  Future<void> applySync(Map<String, dynamic>? v) async {
    _backgroundColor = Color((v?['bgColor'] as num?)?.toInt() ?? 0xFF1E1E24);
    _playerName = v?['playerName'] ?? "Player 1";
    _cardLanguage = v?['cardLanguage'] ?? "pt";
    await _savePreferences();
    notifyListeners();
  }

  void setBackgroundColor(Color color) {
    _backgroundColor = color;
    _savePreferences();
    notifyListeners();
  }

  void setPlayerName(String name) {
    _playerName = name;
    _savePreferences();
    notifyListeners();
  }

  void setCardLanguage(String lang) {
    _cardLanguage = lang;
    _savePreferences();
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    prefs.setInt('bgColor', _backgroundColor.value);
    prefs.setString('playerName', _playerName);
    await prefs.setString('cardLanguage', _cardLanguage);
    UserData.instance.changed('settings');
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('bgColor')) {
      _backgroundColor = Color(prefs.getInt('bgColor')!);
    }
    _playerName = prefs.getString('playerName') ?? "Player 1";
    _cardLanguage = prefs.getString('cardLanguage') ?? "pt";
    notifyListeners();
  }
}