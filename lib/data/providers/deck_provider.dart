import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeckModel {
  String id;
  String name;
  String type; // 'Commander' ou 'Normal'
  List<Map<String, dynamic>> cards;

  DeckModel({required this.id, required this.name, required this.type, required this.cards});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'cards': cards};
  factory DeckModel.fromMap(Map<String, dynamic> map) => DeckModel(
    id: map['id'], 
    name: map['name'], 
    type: map['type'], 
    cards: List<Map<String, dynamic>>.from(map['cards'])
  );
}

class DeckProvider with ChangeNotifier {
  List<DeckModel> _allDecks = [];
  List<DeckModel> get allDecks => _allDecks;

  DeckProvider() { _loadDecks(); }

  void createDeck(String name, String type) {
    _allDecks.add(DeckModel(id: DateTime.now().toString(), name: name, type: type, cards: []));
    _saveDecks();
  }

  void deleteDeck(int index) {
    _allDecks.removeAt(index);
    _saveDecks();
  }

  void addCardToDeck(int deckIndex, Map<String, dynamic> card) {
    // Regra de limite de cartas
    int limit = _allDecks[deckIndex].type == 'Commander' ? 100 : 60;
    if (_allDecks[deckIndex].cards.length < limit) {
      _allDecks[deckIndex].cards.add(card);
      _saveDecks();
    }
  }

  void removeCardFromDeck(int deckIndex, int cardIndex) {
    _allDecks[deckIndex].cards.removeAt(cardIndex);
    _saveDecks();
  }

  // Cálculo automático da curva de energia (Mana)
  Map<int, int> getManaCurve(int deckIndex) {
    Map<int, int> curve = {};
    for (var card in _allDecks[deckIndex].cards) {
      // Pega o custo de mana (CMC) da carta. Se não tiver, assume 0.
      int cmc = (card['cmc'] ?? 0).toInt();
      curve[cmc] = (curve[cmc] ?? 0) + 1;
    }
    return curve;
  }

  Future<void> _saveDecks() async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(_allDecks.map((d) => d.toMap()).toList());
    await prefs.setString('saved_decks_mtg_v2', encoded);
    notifyListeners();
  }

  Future<void> _loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_decks_mtg_v2');
    if (data != null) {
      _allDecks = (jsonDecode(data) as List).map((d) => DeckModel.fromMap(d)).toList();
      notifyListeners();
    }
  }
}