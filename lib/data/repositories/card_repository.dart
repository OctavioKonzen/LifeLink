import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/card_model.dart';

class CardRepository {
  // Cabeçalhos para evitar bloqueios em dispositivos móveis
  final Map<String, String> _headers = {
    'Accept': '*/*',
    'User-Agent': 'LifelinkApp/1.0',
  };

  // Ranking Global e Pesquisa por Preço
  Future<Map<String, dynamic>> fetchTrendingPrices({String? query}) async {
    // Se houver pesquisa, filtra pelo nome; caso contrário, traz o ranking global
    String searchPart = (query != null && query.isNotEmpty) 
        ? '${Uri.encodeComponent(query)}+' 
        : '';
    
    // lang:any inclui japonês, russo, etc.; unique=prints traz versões especiais
    final url = 'https://api.scryfall.com/cards/search?q=${searchPart}usd>0+lang:any&order=usd&dir=desc&unique=prints';
    
    try {
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List cardsJson = data['data'];
        return {
          'cards': cardsJson.map((j) => CardModel.fromJson(j)).toList(),
          'hasMore': data['has_more'] ?? false,
        };
      }
      return {'cards': <CardModel>[], 'hasMore': false};
    } catch (e) {
      debugPrint("Erro ao buscar preços: $e");
      throw Exception("Erro ao carregar ranking global: $e");
    }
  }

  // Pesquisa geral de cartas
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
      throw Exception("Erro na conexão: $e");
    }
  }

  // Busca outras versões/artes da mesma carta
  Future<List<Map<String, dynamic>>> fetchOtherVersions(String cardName, String lang, String? oracleId) async {
    String query = (oracleId != null && oracleId.isNotEmpty) 
        ? 'oracleid:$oracleId lang:$lang' 
        : '!"$cardName" lang:$lang';

    final url = 'https://api.scryfall.com/cards/search?order=released&q=${Uri.encodeQueryComponent(query)}&unique=prints';
    
    try {
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['data'];
        List<Map<String, dynamic>> versions = [];
        
        for (var c in results) {
          String? imgUrl = c['image_uris']?['normal'] ?? c['card_faces']?[0]['image_uris']?['normal'];
          if (imgUrl != null) {
            versions.add({
              'id': c['id'], 
              'oracle_id': c['oracle_id'], 
              'name': c['name'], 
              'imageUrl': imgUrl, 
              'rarity': c['rarity'], 
              'collectorNumber': c['collector_number'], 
              'setName': c['set_name'], 
              'usdPrice': c['prices']?['usd'] ?? '0.00', 
              'type_line': c['type_line'] ?? '',
              'oracle_text': c['oracle_text'] ?? '',
              'mana_cost': c['mana_cost'] ?? '',
              'color_identity': (c['color_identity'] as List?)?.join('') ?? 'C',
            });
          }
        }
        return versions;
      }
    } catch (_) {}
    return [];
  }
}