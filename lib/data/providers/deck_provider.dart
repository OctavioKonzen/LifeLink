import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeckModel {
  String id;
  String name;
  String type;
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
    _allDecks.add(DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: name, 
      type: type, 
      cards: []
    ));
    _saveDecks();
  }

  void importDeck(String name, String type, List<Map<String, dynamic>> newCards) {
    _allDecks.add(DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      cards: List<Map<String, dynamic>>.from(newCards),
    ));
    _saveDecks();
  }

  void deleteDeck(int index) {
    if (index >= 0 && index < _allDecks.length) {
      _allDecks.removeAt(index);
      _saveDecks();
    }
  }

  void addCardToDeck(int deckIndex, Map<String, dynamic> card) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      _allDecks[deckIndex].cards.add(card);
      _saveDecks();
    }
  }

  void removeCardFromDeck(int deckIndex, int cardIndex) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards.removeAt(cardIndex);
        _saveDecks();
      }
    }
  }

  // Atualiza uma carta específica no deck (Usado para Trocar Arte)
  void updateCardInDeck(int deckIndex, int cardIndex, Map<String, dynamic> newCard) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards[cardIndex] = newCard;
        _saveDecks();
      }
    }
  }

  // NOVA FUNÇÃO: Substitui uma carta por outra diferente (Soluciona o erro do CardDetailScreen)
  void replaceCardInDeck(int deckIndex, int cardIndex, Map<String, dynamic> newCard) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards[cardIndex] = newCard;
        _saveDecks();
        notifyListeners(); // Força a tela a atualizar com a nova carta
      }
    }
  }

  Map<int, int> getManaCurve(int deckIndex) {
    Map<int, int> curve = {};
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      for (var card in _allDecks[deckIndex].cards) {
        int cmc = (card['cmc'] ?? 0).toInt();
        curve[cmc] = (curve[cmc] ?? 0) + 1;
      }
    }
    return curve;
  }

  Future<void> _saveDecks() async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(_allDecks.map((d) => d.toMap()).toList());
    await prefs.setString('saved_decks_mtg_v5', encoded); 
    notifyListeners();
  }

  Future<void> _loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('saved_decks_mtg_v5');
    if (data != null) {
      _allDecks = (jsonDecode(data) as List).map((d) => DeckModel.fromMap(d)).toList();
      notifyListeners();
    }
  }
}