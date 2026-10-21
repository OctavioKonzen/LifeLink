import 'package:flutter/foundation.dart';
import '../models/card_model.dart';
import '../services/scryfall_service.dart';

class CardRepository {
  final ScryfallService _scryfall = ScryfallService.instance;

  // Ranking Global e Pesquisa por Preço
  Future<Map<String, dynamic>> fetchTrendingPrices({String? query, String? nextPage}) async {
    // Se houver pesquisa, filtra pelo nome (ou texto); caso contrário, traz o ranking global
    final searchPart = (query != null && query.isNotEmpty)
        ? '${ScryfallService.buildTextQuery(query)} '
        : '';

    // lang:any inclui japonês, russo, etc.; prints traz versões especiais
    try {
      final page = await _scryfall.search('${searchPart}usd>0 lang:any', order: 'usd', dir: 'desc', unique: 'prints', multilingual: false, nextPage: nextPage);
      return {
        'cards': page.cards.map((j) => CardModel.fromJson(j)).toList(),
        'raw': page.cards,
        'hasMore': page.hasMore,
        'nextPage': page.nextPage,
      };
    } on ScryfallException catch (e) {
      debugPrint("Erro ao buscar preços: $e");
      rethrow;
    }
  }

  // Pesquisa geral de cartas
  Future<Map<String, dynamic>> searchCards(String query, {String? nextPageUrl}) async {
    final page = await _scryfall.search(query, nextPage: nextPageUrl);
    return {
      'cards': page.cards.map((j) => CardModel.fromJson(j)).toList(),
      'hasMore': page.hasMore,
      'nextPage': page.nextPage,
    };
  }

  // Busca outras versões/artes da mesma carta
  Future<List<Map<String, dynamic>>> fetchOtherVersions(String cardName, String lang, String? oracleId) async {
    String query = (oracleId != null && oracleId.isNotEmpty)
        ? 'oracleid:$oracleId lang:$lang'
        : '!"$cardName" lang:$lang';

    try {
      final page = await _scryfall.search(query, order: 'released', unique: 'prints', multilingual: false);
      List<Map<String, dynamic>> versions = [];

      for (var c in page.cards) {
        final imgUrl = CardImages.normalOf(c);
        if (imgUrl != null) {
          versions.add({
            'id': c['id'],
            'oracle_id': c['oracle_id'],
            'name': c['printed_name'] ?? c['name'],
            'imageUrl': imgUrl,
            'backImageUrl': c['card_faces']?[1]?['image_uris']?['normal'],
            'rarity': c['rarity'],
            'collectorNumber': c['collector_number'],
            'setName': c['set_name'],
            'usdPrice': c['prices']?['usd'] ?? '0.00',
            'usdFoil': c['prices']?['usd_foil'],
            'eurPrice': c['prices']?['eur'],
            'tixPrice': c['prices']?['tix'],
            'type_line': c['printed_type_line'] ?? c['type_line'] ?? '',
            'oracle_text': c['printed_text'] ?? c['oracle_text'] ?? '',
            'mana_cost': c['mana_cost'] ?? '',
            'color_identity': (c['color_identity'] as List?)?.join('') ?? 'C',
          });
        }
      }
      return versions;
    } catch (_) {}
    return [];
  }
}
