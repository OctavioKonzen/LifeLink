import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de uma busca no Scryfall.
class ScryfallPage {
  final List<Map<String, dynamic>> cards;
  final bool hasMore;
  final String? nextPage;

  const ScryfallPage(this.cards, {this.hasMore = false, this.nextPage});
}

/// Erro da busca com a mensagem pronta para mostrar na tela.
class ScryfallException implements Exception {
  final String message;
  final bool notFound;

  const ScryfallException(this.message, {this.notFound = false});

  @override
  String toString() => message;
}

/// Acesso único ao Scryfall: respeita o limite de pedidos, guarda as respostas
/// por alguns minutos e traduz os erros. Todas as telas passam por aqui.
class ScryfallService {
  ScryfallService._();
  static final ScryfallService instance = ScryfallService._();

  static const String _base = 'https://api.scryfall.com';

  // O navegador não deixa trocar o User-Agent; no celular o Scryfall pede um.
  static const Map<String, String> headers = kIsWeb
      ? {'Accept': 'application/json'}
      : {'User-Agent': 'LifelinkApp/1.0', 'Accept': 'application/json'};

  static const Duration _cacheTime = Duration(minutes: 10);
  // O Scryfall pede no máximo 10 pedidos por segundo.
  static const Duration _minInterval = Duration(milliseconds: 100);

  final Map<String, ({DateTime at, Map<String, dynamic> data})> _cache = {};
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _queue = Future.value();

  Future<Map<String, dynamic>> getJson(String url, {bool useCache = true}) async {
    final cached = _cache[url];
    if (useCache && cached != null && DateTime.now().difference(cached.at) < _cacheTime) {
      return cached.data;
    }

    final completer = Completer<void>();
    final previous = _queue;
    _queue = completer.future;
    await previous;
    try {
      final wait = _minInterval - DateTime.now().difference(_lastRequest);
      if (wait > Duration.zero) await Future.delayed(wait);
      _lastRequest = DateTime.now();
    } finally {
      completer.complete();
    }

    final http.Response response;
    try {
      response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ScryfallException("A busca demorou demais. Verifique sua internet e tente de novo.");
    } catch (_) {
      throw const ScryfallException("Sem conexão com a internet.");
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ScryfallException("Resposta inválida do Scryfall (erro ${response.statusCode}).");
    }

    if (response.statusCode != 200) {
      throw errorFor(response.statusCode, data);
    }
    _cache[url] = (at: DateTime.now(), data: data);
    return data;
  }

  /// Transforma a resposta de erro do Scryfall numa mensagem compreensível.
  static ScryfallException errorFor(int status, Map<String, dynamic> data) {
    switch (status) {
      case 404:
        return const ScryfallException("Nenhuma carta encontrada.", notFound: true);
      case 400:
        final details = data['details']?.toString();
        return ScryfallException(details == null || details.isEmpty
            ? "Não entendi essa busca. Confira o que foi digitado."
            : "Não entendi essa busca: $details");
      case 429:
        return const ScryfallException("Muitas buscas seguidas. Espere alguns segundos e tente de novo.");
      default:
        return ScryfallException("O Scryfall está com problemas agora (erro $status). Tente mais tarde.");
    }
  }

  // ------------------------------------------------------------------ busca

  /// Pesquisa cartas. Com [multilingual], o nome também é procurado nos
  /// outros idiomas (ex.: "Raio" encontra "Lightning Bolt").
  Future<ScryfallPage> search(String query,
      {String order = 'name', String? dir, String? unique, bool multilingual = true, String? nextPage}) async {
    final url = nextPage ??
        '$_base/cards/search?q=${Uri.encodeQueryComponent(query)}&order=$order'
            '${dir != null ? '&dir=$dir' : ''}'
            '${unique != null ? '&unique=$unique' : ''}'
            '${multilingual ? '&include_multilingual=true' : ''}';
    try {
      final data = await getJson(url);
      final List results = data['data'] ?? [];
      final hasMore = data['has_more'] == true;
      return ScryfallPage(
        results.whereType<Map<String, dynamic>>().toList(),
        hasMore: hasMore,
        nextPage: hasMore ? data['next_page'] as String? : null,
      );
    } on ScryfallException catch (e) {
      if (e.notFound) return const ScryfallPage([]);
      rethrow;
    }
  }

  /// Sugestões de nomes enquanto a pessoa digita.
  Future<List<String>> autocomplete(String text) async {
    final q = text.trim();
    if (q.length < 2) return [];
    try {
      final data = await getJson('$_base/cards/autocomplete?q=${Uri.encodeQueryComponent(q)}&include_multilingual=true');
      return List<String>.from(data['data'] ?? const []);
    } catch (_) {
      return [];
    }
  }

  /// Monta a busca do Scryfall a partir do que foi digitado: procura no nome
  /// e também no texto da carta. Quem escreve a sintaxe do Scryfall
  /// (t:, o:, c:...) tem a busca usada como está.
  static String buildTextQuery(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'[:<>=!"()]').hasMatch(t) || RegExp(r'\b(or|and)\b', caseSensitive: false).hasMatch(t)) {
      return t;
    }
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final inName = words.join(' ');
    final inText = words.map((w) => 'o:${_quoteIfNeeded(w)}').join(' ');
    return '(($inName) or ($inText))';
  }

  static String _quoteIfNeeded(String w) => RegExp(r'^[\p{L}\p{N}_\-]+$', unicode: true).hasMatch(w) ? w : '"${w.replaceAll('"', '')}"';

  // ---------------------------------------------- filtros guardados no celular

  static const Duration _catalogTime = Duration(days: 7);

  /// Lista do Scryfall guardada no celular por 7 dias (tipos e coleções mudam
  /// pouco), para a busca não fazer 6 pedidos toda vez que abre.
  Future<List<dynamic>?> cachedList(String key, String path, {List<dynamic> Function(Map<String, dynamic>)? pick}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getInt('scryfall_${key}_at') ?? 0;
    final saved = prefs.getString('scryfall_$key');
    final fresh = DateTime.now().millisecondsSinceEpoch - savedAt < _catalogTime.inMilliseconds;
    if (saved != null && fresh) return jsonDecode(saved) as List;

    try {
      final data = await getJson('$_base$path');
      final list = pick != null ? pick(data) : List<dynamic>.from(data['data'] ?? const []);
      await prefs.setString('scryfall_$key', jsonEncode(list));
      await prefs.setInt('scryfall_${key}_at', DateTime.now().millisecondsSinceEpoch);
      return list;
    } catch (_) {
      // Sem internet: usa a cópia antiga, se houver.
      return saved != null ? jsonDecode(saved) as List : null;
    }
  }

  Future<List<String>?> catalog(String name) async {
    final list = await cachedList('catalog_$name', '/catalog/$name');
    return list == null ? null : List<String>.from(list);
  }

  Future<List<Map<String, String>>?> sets() async {
    final list = await cachedList('sets', '/sets', pick: (data) {
      final List sets = data['data'] ?? [];
      return sets.map((s) => {'code': s['code'].toString(), 'name': s['name'].toString()}).toList();
    });
    return list?.map((s) => Map<String, String>.from(s as Map)).toList();
  }

  // ------------------------------------------------------- buscas recentes

  static const String _recentKey = 'recent_card_searches';
  static const int _recentMax = 10;

  Future<List<String>> recentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? [];
  }

  Future<List<String>> addRecentSearch(String text) async {
    final t = text.trim();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    if (t.isEmpty) return list;
    list.removeWhere((s) => s.toLowerCase() == t.toLowerCase());
    list.insert(0, t);
    if (list.length > _recentMax) list.removeRange(_recentMax, list.length);
    await prefs.setStringList(_recentKey, list);
    return list;
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }
}

/// Tamanhos de imagem do Scryfall (https://scryfall.com/docs/api/images).
/// O app guarda o endereço "normal" e escolhe o tamanho na hora de mostrar.
class CardImages {
  static final RegExp _sized = RegExp(r'(cards\.scryfall\.io/)(small|normal|large|png|border_crop|art_crop)(/[^?]*?)\.(jpg|png)');

  /// Troca o tamanho de um endereço do Scryfall:
  /// small (146×204), normal (488×680), large (672×936), png (745×1040).
  /// Endereços de outros sites voltam como estão.
  static String sized(String url, String size) {
    final ext = size == 'png' ? 'png' : 'jpg';
    return url.replaceFirstMapped(_sized, (m) => '${m[1]}$size${m[3]}.$ext');
  }

  /// Miniatura: listas com imagens pequenas (preços, decks).
  static String thumb(String url) => sized(url, 'small');

  /// Melhor qualidade: tela da carta aberta.
  static String best(String url) => sized(url, 'png');

  /// Arte recortada de uma carta pelo nome (o Scryfall redireciona para a imagem).
  static String artCropByName(String name) =>
      'https://api.scryfall.com/cards/named?exact=${Uri.encodeQueryComponent(name)}&format=image&version=art_crop';

  /// Verso padrão das cartas de Magic.
  static const String cardBack = 'https://upload.wikimedia.org/wikipedia/en/a/aa/Magic_the_gathering-card_back.jpg';

  /// O endereço "normal" de uma carta da API (frente, nas cartas de duas faces).
  static String? normalOf(Map<String, dynamic> card) =>
      card['image_uris']?['normal'] ?? card['card_faces']?[0]?['image_uris']?['normal'];
}
