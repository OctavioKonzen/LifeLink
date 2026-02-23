import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../repositories/card_repository.dart';

class CardProvider with ChangeNotifier {
  final CardRepository _repository = CardRepository();

  List<CardModel> _cards = [];
  List<CardModel> get cards => _cards;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _nextPageUrl;

  final List<String> _selectedTypes = [];
  final List<String> _selectedColors = [];
  String? _selectedSet;

  List<String> get selectedTypes => _selectedTypes;
  List<String> get selectedColors => _selectedColors;
  String? get selectedSet => _selectedSet;

  void toggleType(String type) {
    if (_selectedTypes.contains(type)) {
      _selectedTypes.remove(type);
    } else {
      _selectedTypes.add(type);
    }
    notifyListeners();
  }

  void toggleColor(String color) {
    if (_selectedColors.contains(color)) {
      _selectedColors.remove(color);
    } else {
      _selectedColors.add(color);
    }
    notifyListeners();
  }

  void selectSet(String? setCode) {
    _selectedSet = setCode;
    notifyListeners();
  }

  void clearFilters() {
    _selectedTypes.clear();
    _selectedColors.clear();
    _selectedSet = null;
    notifyListeners();
  }

  Future<void> searchCards(String queryText, {bool isNextPage = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    if (!isNextPage) {
      _cards = [];
      _nextPageUrl = null;
      _hasMore = true;
    }
    notifyListeners();

    try {
      String finalQuery = _buildFullQuery(queryText);
      final result = await _repository.searchCards(
        finalQuery, 
        nextPageUrl: isNextPage ? _nextPageUrl : null
      );

      final List<CardModel> newCards = List<CardModel>.from(result['cards']);

      if (isNextPage) {
        _cards.addAll(newCards);
      } else {
        _cards = newCards;
      }

      _hasMore = result['hasMore'];
      // Ajustado para coincidir com a chave retornada pelo CardRepository
      _nextPageUrl = result['nextPage']; 
    } catch (e) {
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _buildFullQuery(String text) {
    List<String> parts = [];
    if (text.trim().isNotEmpty) {
      parts.add(text.trim());
    } else if (_selectedTypes.isEmpty && _selectedColors.isEmpty && _selectedSet == null) {
      parts.add("is:commander");
    }

    for (var t in _selectedTypes) {
      parts.add('t:"$t"');
    }
    if (_selectedColors.isNotEmpty) {
      parts.add("id<=${_selectedColors.join('')}");
    }
    if (_selectedSet != null) {
      parts.add("set:$_selectedSet");
    }

    return parts.join(" ");
  }
}