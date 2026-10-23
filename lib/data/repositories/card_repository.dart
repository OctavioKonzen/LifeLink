import 'package:flutter/foundation.dart';
import '../models/card_model.dart';
import '../services/lifelink_cards.dart';
import '../services/scryfall_service.dart';

class CardRepository {
  final ScryfallService _scryfall = ScryfallService.instance;

  // Ranking Global e Pesquisa por Preço
  Future<Map<String, dynamic>> fetchTrendingPrices({String? query, String? nextPage}) async {
    // Se houver pesquisa, filtra pelo nome (ou texto); caso contrário, traz o ranking global
    final searchPart = (query != null && query.isNotEmpty)
        ? '${ScryfallService.buildTextQuery(query)} '
        : '';

    // Do banco do LifeLink: sem busca, as 600 versões mais caras (R2); com
    // busca, as cartas mais caras com aquele nome ou texto (Cloudflare).
    if (nextPage == null) {
      try {
        final raw = (query == null || query.isEmpty)
            ? await LifeLinkCards.instance.topPrices()
            : [
                for (final c in (await LifeLinkCards.instance.search(text: query, order: 'usd', desc: true)).cards)
                  {
                    'id': c['id'],
                    'oracle_id': c['oracle_id'],
                    'name': c['enName'],
                    'printed_name': c['name'],
                    'rarity': c['rarity'],
                    'mana_cost': c['mana_cost'],
                    'type_line': c['type_line'],
                    'color_identity': '${c['color_identity']}'.split('').where((x) => x.isNotEmpty).toList(),
                    'prices': {'usd': c['usdPrice']},
                    'image_uris': {'normal': c['imageUrl']},
                  },
              ];
        if (raw.isNotEmpty) return {'cards': raw.map((j) => CardModel.fromJson(j)).toList(), 'raw': raw, 'hasMore': false, 'nextPage': null};
      } catch (_) {}
    }

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

  // Busca outras versões/artes da mesma carta
  Future<List<Map<String, dynamic>>> fetchOtherVersions(String cardName, String lang, String? oracleId) async {
    // Inglês e português: as versões do banco do LifeLink (R2).
    if ((lang == 'en' || lang == 'pt') && oracleId != null && oracleId.isNotEmpty) {
      try {
        final own = await LifeLinkCards.instance.versions(oracleId, lang: lang);
        if (own.isNotEmpty) return own;
      } catch (_) {}
    }
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
            'usdPrice': c['prices']?['usd'] ?? c['prices']?['usd_foil'] ?? c['prices']?['usd_etched'] ?? '0.00',
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
