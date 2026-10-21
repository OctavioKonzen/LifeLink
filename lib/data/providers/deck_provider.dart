import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/user_data.dart';

class DeckModel {
  String id;
  String name;
  String type;
  List<Map<String, dynamic>> cards;

  DeckModel({required this.id, required this.name, required this.type, required this.cards});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'cards': cards};
  factory DeckModel.fromMap(Map<String, dynamic> map) => DeckModel(
    id: map['id'].toString(), 
    name: map['name'] ?? 'Deck', 
    type: map['type'] ?? 'Casual', 
    cards: [for (final c in (map['cards'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]
  );
}

class DeckProvider with ChangeNotifier implements SyncedDecks {
  List<DeckModel> _allDecks = [];
  List<DeckModel> get allDecks => _allDecks;

  /// Termina quando os decks salvos no aparelho foram carregados.
  late final Future<void> ready;

  DeckProvider() {
    ready = _loadDecks();
    UserData.instance.decks = this;
  }

  // Avisa a conta (AccountSync) qual deck mudou.
  void _changed(int deckIndex) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) UserData.instance.deckChanged(_allDecks[deckIndex].id);
  }

  /// A posição do deck na lista pelo id (-1 se não existe mais). As telas
  /// guardam o id: a lista muda de ordem quando chega um deck da conta.
  int indexOfId(String id) => _allDecks.indexWhere((d) => d.id == id);

  @override
  Map<String, Map<String, dynamic>> readDecks() => {for (final d in _allDecks) d.id: d.toMap()};

  @override
  Future<void> applyDecks(Map<String, Map<String, dynamic>> remote, {Set<String> keep = const {}}) async {
    final local = {for (final d in _allDecks) d.id: d};
    final merged = <DeckModel>[
      for (final e in remote.entries)
        if (!keep.contains(e.key)) DeckModel.fromMap({...e.value, 'id': e.key}),
      for (final id in keep)
        if (local[id] != null) local[id]!,
    ]..sort((a, b) => a.id.compareTo(b.id));
    _allDecks = merged;
    await _saveDecks();
  }

  @override
  Future<void> clearDecks() async {
    _allDecks = [];
    await _saveDecks();
  }

  void createDeck(String name, String type) {
    _allDecks.add(DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: name, 
      type: type, 
      cards: []
    ));
    _changed(_allDecks.length - 1);
    _saveDecks();
  }

  void importDeck(String name, String type, List<Map<String, dynamic>> newCards) {
    _allDecks.add(DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      cards: List<Map<String, dynamic>>.from(newCards),
    ));
    _changed(_allDecks.length - 1);
    _saveDecks();
  }

  void deleteDeck(int index) {
    if (index >= 0 && index < _allDecks.length) {
      UserData.instance.deckChanged(_allDecks[index].id, deleted: true);
      _allDecks.removeAt(index);
      _saveDecks();
    }
  }

  void addCardToDeck(int deckIndex, Map<String, dynamic> card) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      _allDecks[deckIndex].cards.add(card);
      _changed(deckIndex);
      _saveDecks();
    }
  }

  /// Várias cartas de uma vez (importar lista): grava uma vez só.
  void addCardsToDeck(int deckIndex, List<Map<String, dynamic>> cards) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length && cards.isNotEmpty) {
      _allDecks[deckIndex].cards.addAll(cards);
      _changed(deckIndex);
      _saveDecks();
    }
  }

  void removeCardFromDeck(int deckIndex, int cardIndex) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards.removeAt(cardIndex);
        _changed(deckIndex);
        _saveDecks();
      }
    }
  }

  // Atualiza uma carta específica no deck (Usado para Trocar Arte)
  void updateCardInDeck(int deckIndex, int cardIndex, Map<String, dynamic> newCard) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards[cardIndex] = newCard;
        _changed(deckIndex);
        _saveDecks();
      }
    }
  }

  // NOVA FUNÇÃO: Substitui uma carta por outra diferente (Soluciona o erro do CardDetailScreen)
  void replaceCardInDeck(int deckIndex, int cardIndex, Map<String, dynamic> newCard) {
    if (deckIndex >= 0 && deckIndex < _allDecks.length) {
      if (cardIndex >= 0 && cardIndex < _allDecks[deckIndex].cards.length) {
        _allDecks[deckIndex].cards[cardIndex] = newCard;
        _changed(deckIndex);
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
      try {
        _allDecks = (jsonDecode(data) as List).map((d) => DeckModel.fromMap(d)).toList();
      } catch (e) {
        // Salvo estragado: abre sem os decks deste aparelho (os da conta voltam ao sincronizar).
        debugPrint('Decks salvos inválidos: $e');
        _allDecks = [];
      }
      notifyListeners();
    }
  }
}