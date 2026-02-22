import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  Color _backgroundColor = const Color(0xFF1E1E24); // Começa Preto Escuro
  String _playerName = "Player 1";
  String _cardLanguage = "pt"; 

  // Mapa com as cores exatas que você pediu: Rosa Claro, Azul Claro, Verde Claro, Preto e Branco
  final Map<String, Color> availableColors = {
    "Rosa Claro": const Color(0xFFF8BBD0),
    "Azul Claro": const Color(0xFFB3E5FC),
    "Verde Claro": const Color(0xFFC8E6C9),
    "Preto": const Color(0xFF1E1E24), // Um preto um pouco mais suave
    "Branco": const Color(0xFFF5F5F5), // Um branco off-white que não cega
  };

  Color get backgroundColor => _backgroundColor;
  String get playerName => _playerName;
  String get cardLanguage => _cardLanguage;

  ThemeProvider() {
    _loadPreferences();
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
    prefs.setString('cardLanguage', _cardLanguage);
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