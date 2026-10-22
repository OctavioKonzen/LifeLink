import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/user_data.dart';
import '../services/deck_tools.dart';

/// Uma carta guardada (na coleção ou na lista de desejos), no formato da
/// conta: { id, name, oracle_id, set, num, img, usd, qty } e, na lista de
/// desejos, também { added (preço quando entrou), at (quando) }.
class SavedCard {
  final String id;
  final String name;
  final String? oracleId;
  final String set;
  final String number;
  final String img;
  double usd;
  int qty;
  final double added;
  final int at;

  SavedCard({required this.id, required this.name, this.oracleId, this.set = '', this.number = '', this.img = '', this.usd = 0, this.qty = 1, double? added, int? at})
      : added = added ?? usd,
        at = at ?? DateTime.now().millisecondsSinceEpoch;

  /// A partir de uma carta do app (busca, scan, deck).
  factory SavedCard.of(Map<String, dynamic> card) {
    final usd = double.tryParse('${card['usdPrice'] ?? card['usdFoil'] ?? ''}') ?? 0;
    return SavedCard(
      id: DeckTools.scryfallIdOf(card) ?? '${card['id'] ?? card['name']}',
      name: '${card['name'] ?? ''}',
      oracleId: card['oracle_id']?.toString(),
      set: '${card['setName'] ?? ''}',
      number: '${card['collectorNumber'] ?? ''}',
      img: '${card['imageUrl'] ?? ''}',
      usd: usd,
    );
  }

  factory SavedCard.fromMap(Map<String, dynamic> m) => SavedCard(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        oracleId: m['oracle_id']?.toString(),
        set: '${m['set'] ?? ''}',
        number: '${m['num'] ?? ''}',
        img: '${m['img'] ?? ''}',
        usd: (m['usd'] as num?)?.toDouble() ?? 0,
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        added: (m['added'] as num?)?.toDouble(),
        at: (m['at'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap({bool wish = false}) => {
        'id': id,
        'name': name,
        if (oracleId != null) 'oracle_id': oracleId,
        'set': set,
        'num': number,
        'img': img,
        'usd': usd,
        if (!wish) 'qty': qty,
        if (wish) 'added': added,
        if (wish) 'at': at,
      };

  /// Dados para abrir a carta (CardDetailScreen).
  Map<String, dynamic> toCard() => {
        'id': id,
        'name': name,
        'imageUrl': img,
        'setName': set,
        'collectorNumber': number,
        'oracle_id': oracleId,
        'usdPrice': usd.toStringAsFixed(2),
      };
}

/// Uma carta que falta para montar o deck.
typedef MissingCard = ({String name, int need, int have, double usd, Map<String, dynamic> card});

/// A coleção (as cartas que a pessoa tem) e a lista de desejos (as que quer,
/// com aviso quando o preço cai). Vão para a conta como 'collection' e
/// 'wishlist' (listas, para que tirar uma carta apague na conta também).
class CollectionProvider with ChangeNotifier {
  static const maxCards = 2000; // o documento da conta tem limite de 1 MB

  List<SavedCard> _cards = [];
  List<SavedCard> _wishes = [];
  List<SavedCard> get cards => List.unmodifiable(_cards);
  List<SavedCard> get wishes => List.unmodifiable(_wishes);

  late final Future<void> ready;

  CollectionProvider() {
    ready = _load();
    UserData.instance.register(SyncedSection(key: 'collection', read: () => _toSync(_cards), apply: (v) => _apply(v, wish: false)));
    UserData.instance.register(SyncedSection(key: 'wishlist', read: () => _toSync(_wishes, wish: true), apply: (v) => _apply(v, wish: true)));
  }

  Map<String, dynamic> _toSync(List<SavedCard> list, {bool wish = false}) => {'list': [for (final c in list) c.toMap(wish: wish)]};

  static List<SavedCard> _read(Map<String, dynamic>? v) => [for (final m in (v?['list'] as List? ?? const [])) SavedCard.fromMap(Map<String, dynamic>.from(m as Map))];

  Future<void> _apply(Map<String, dynamic>? v, {required bool wish}) async {
    if (wish) {
      _wishes = _read(v);
    } else {
      _cards = _read(v);
    }
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------- coleção

  int qtyOf(String id) => _cards.where((c) => c.id == id).fold(0, (a, c) => a + c.qty);
  int get totalCards => _cards.fold(0, (a, c) => a + c.qty);
  double get totalUsd => _cards.fold(0.0, (a, c) => a + c.usd * c.qty);

  /// Mais uma cópia da carta na coleção; volta quantas tem agora.
  int add(Map<String, dynamic> card, [int n = 1]) {
    final saved = SavedCard.of(card);
    final i = _cards.indexWhere((c) => c.id == saved.id);
    if (i >= 0) {
      _cards[i].qty += n;
    } else {
      if (_cards.length >= maxCards) return 0;
      saved.qty = n;
      _cards.insert(0, saved);
    }
    _changed('collection');
    return qtyOf(saved.id);
  }

  void setQty(String id, int qty) {
    if (qty <= 0) {
      _cards.removeWhere((c) => c.id == id);
    } else {
      for (final c in _cards) {
        if (c.id == id) c.qty = qty;
      }
    }
    _changed('collection');
  }

  /// O que falta na coleção para montar o deck (pelo nome da carta, qualquer
  /// versão; terrenos básicos não contam).
  List<MissingCard> missingFor(List<Map<String, dynamic>> deck) => missing(deck, _cards);

  static List<MissingCard> missing(List<Map<String, dynamic>> deck, List<SavedCard> collection) {
    String key(String? oracle, String name) => oracle ?? name.toLowerCase();
    final have = <String, int>{};
    for (final c in collection) {
      have[key(c.oracleId, c.name)] = (have[key(c.oracleId, c.name)] ?? 0) + c.qty;
      if (c.oracleId != null) have[c.name.toLowerCase()] = (have[c.name.toLowerCase()] ?? 0) + c.qty;
    }
    final need = <String, ({int n, Map<String, dynamic> card})>{};
    for (final c in deck) {
      if ('${c['type_line'] ?? ''}'.contains(RegExp('Basic|Básic'))) continue;
      final k = key(c['oracle_id']?.toString(), '${c['name']}');
      need[k] = (n: (need[k]?.n ?? 0) + 1, card: c);
    }
    final out = <MissingCard>[];
    for (final e in need.entries) {
      final card = e.value.card;
      final got = have[e.key] ?? have['${card['name']}'.toLowerCase()] ?? 0;
      if (got < e.value.n) {
        out.add((name: '${card['name']}', need: e.value.n, have: got, usd: DeckTools.priceOf(card), card: card));
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  // ----------------------------------------------------- lista de desejos

  bool wished(String id) => _wishes.any((c) => c.id == id);

  void toggleWish(Map<String, dynamic> card) {
    final saved = SavedCard.of(card);
    if (wished(saved.id)) {
      _wishes.removeWhere((c) => c.id == saved.id);
    } else {
      _wishes.insert(0, saved);
    }
    _changed('wishlist');
  }

  void removeWish(String id) {
    _wishes.removeWhere((c) => c.id == id);
    _changed('wishlist');
  }

  // ---------------------------------------------------------------- preços

  /// Atualiza os preços na Scryfall (coleção e desejos). Volta as cartas da
  /// lista de desejos que ficaram mais baratas (5% ou mais) desde a última vez.
  Future<List<({SavedCard card, double before})>> refreshPrices() async {
    final all = {for (final c in [..._cards, ..._wishes]) c.id};
    final ids = [for (final id in all) if (RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) id];
    final prices = <String, double>{};
    for (var start = 0; start < ids.length; start += 75) {
      final chunk = ids.sublist(start, (start + 75).clamp(0, ids.length));
      final data = await DeckTools.postCollection([for (final id in chunk) {'id': id}]);
      for (final c in (data['data'] as List? ?? const [])) {
        final p = double.tryParse('${c['prices']?['usd'] ?? c['prices']?['usd_foil'] ?? ''}');
        if (p != null) prices['${c['id']}'] = p;
      }
    }
    final drops = <({SavedCard card, double before})>[];
    for (final c in _wishes) {
      final p = prices[c.id];
      if (p == null) continue;
      if (c.usd > 0 && p <= c.usd * 0.95) drops.add((card: c, before: c.usd));
      c.usd = p;
    }
    for (final c in _cards) {
      c.usd = prices[c.id] ?? c.usd;
    }
    if (prices.isNotEmpty) {
      _changed('collection');
      _changed('wishlist');
    }
    return drops;
  }

  /// Uma vez por dia, ao abrir o app: os preços da lista de desejos que caíram.
  Future<List<({SavedCard card, double before})>> dailyCheck() async {
    if (_wishes.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('pricesCheckedDay') == today) return const [];
    try {
      final drops = await refreshPrices();
      await prefs.setString('pricesCheckedDay', today);
      return drops;
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------- salvar

  void _changed(String key) {
    notifyListeners();
    _save();
    UserData.instance.changed(key);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('collection', jsonEncode(_toSync(_cards)));
    await prefs.setString('wishlist', jsonEncode(_toSync(_wishes, wish: true)));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? read(String k) => prefs.getString(k) == null ? null : jsonDecode(prefs.getString(k)!) as Map<String, dynamic>;
    _cards = _read(read('collection'));
    _wishes = _read(read('wishlist'));
    notifyListeners();
  }
}
