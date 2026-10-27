import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

class ThemeProvider with ChangeNotifier {
  // A noite azul do redesign (antes era 0xFF1E1E24, que vira esta).
  static const night = Color(0xFF0A0D17);
  static const _oldDark = 0xFF1E1E24;
  Color _backgroundColor = night;
  String _playerName = "Jogador 1";
  String _cardLanguage = "pt"; 

  // As cores de fundo que dá para escolher
  final Map<String, Color> availableColors = {
    "Rosa Claro": const Color(0xFFF8BBD0),
    "Azul Claro": const Color(0xFFB3E5FC),
    "Verde Claro": const Color(0xFFC8E6C9),
    "Noite": night,
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
    _backgroundColor = _fromSaved((v?['bgColor'] as num?)?.toInt());
    _playerName = v?['playerName'] ?? "Jogador 1";
    _cardLanguage = v?['cardLanguage'] ?? "pt";
    await _savePreferences();
    notifyListeners();
  }

  /// A cor salva; o preto antigo vira a noite azul do redesign.
  static Color _fromSaved(int? value) => value == null || value == _oldDark ? night : Color(value);

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
      _backgroundColor = _fromSaved(prefs.getInt('bgColor'));
    }
    _playerName = prefs.getString('playerName') ?? "Jogador 1";
    _cardLanguage = prefs.getString('cardLanguage') ?? "pt";
    notifyListeners();
  }
}