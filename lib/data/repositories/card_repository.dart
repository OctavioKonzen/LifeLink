import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/card_model.dart';

class CardRepository {
  // O "crachá" do app para o Scryfall não bloquear o celular
  final Map<String, String> _headers = {
    'Accept': '*/*',
    'User-Agent': 'LifelinkApp/1.0',
  };

  Future<Map<String, dynamic>> searchCards(String query, {String? nextPageUrl}) async {
    final url = nextPageUrl ?? 'https://api.scryfall.com/cards/search?q=${Uri.encodeComponent(query)}&order=name';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List cardsJson = data['data'];
        return {
          'cards': cardsJson.map((j) => CardModel.fromJson(j)).toList(),
          'hasMore': data['has_more'] ?? false,
          'nextPage': data['next_page'],
        };
      }
      return {'cards': <CardModel>[], 'hasMore': false};
    } catch (e) {
      throw Exception("Erro na conexão com Scryfall: $e");
    }
  }

  Future<List<Map<String, String>>> fetchSets() async {
    try {
      final response = await http.get(Uri.parse('https://api.scryfall.com/sets'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).map((s) => {
          'code': s['code'].toString(),
          'name': s['name'].toString()
        }).toList();
      }
    } catch (e) {
      debugPrint("Erro ao buscar sets: $e");
    }
    return [];
  }

  // --- NOVA FUNÇÃO ADICIONADA AQUI ---
  Future<List<Map<String, dynamic>>> fetchOtherVersions(String cardName, String lang, String? oracleId) async {
    String query = (oracleId != null && oracleId.isNotEmpty) 
        ? 'oracleid:$oracleId lang:$lang' 
        : '!"$cardName" lang:$lang';

    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = 'https://api.scryfall.com/cards/search?order=released&q=$encodedQuery&unique=prints';
    
    try {
      // Usando os headers para evitar bloqueio no mobile
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['data'];
        List<Map<String, dynamic>> versions = [];
        
        for (var c in results) {
          String? imgUrl = (c['image_uris'] != null) 
              ? (c['image_uris']['png'] ?? c['image_uris']['large'] ?? c['image_uris']['normal']) 
              : (c['card_faces'] != null ? (c['card_faces'][0]['image_uris']['png'] ?? c['card_faces'][0]['image_uris']['large'] ?? c['card_faces'][0]['image_uris']['normal']) : null);
          
          if (imgUrl != null) {
            imgUrl = imgUrl.replaceAll('/normal/', '/png/').replaceAll('/large/', '/png/').replaceAll('.jpg', '.png');

            versions.add({
              'id': c['id'], 
              'oracle_id': c['oracle_id'], 
              'name': c['name'], 
              'imageUrl': imgUrl, 
              'rarity': c['rarity'], 
              'collectorNumber': c['collector_number'], 
              'type_line': c['type_line'], 
              'oracle_text': c['oracle_text'] ?? c['printed_text'] ?? '', 
              'mana_cost': c['mana_cost'] ?? '', 
              'power': c['power'], 
              'toughness': c['toughness'],
              'color_identity': c['color_identity'] != null ? (c['color_identity'] as List).join('') : 'C',
              'setName': c['set_name'], 
              'artist': c['artist'], 
              'usdPrice': c['prices']?['usd'] ?? '0.00', 
              'cmc': c['cmc'] ?? 0, 
            });
          }
        }
        return versions;
      }
    } catch (e) { 
      debugPrint("Erro ao buscar versões: $e"); 
    }
    return [];
  }
}