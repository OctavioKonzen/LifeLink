import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// As cartas do próprio LifeLink, na Cloudflare (tool/build_cards.py e cloud/):
/// arquivos no R2 (a carta pelo código, preços, imagens) e a busca no Worker.
/// Assim o app não depende da API da Scryfall para mostrar as cartas.
///
/// No R2:
///   `c/{oracle}.json`   a carta com todas as variações (inglês e português)
///   `pr/{xx}.json`      os preços do dia (xx = começo do oracle_id)
///   `id/{xxx}.json`     código da variação → oracle_id
///   `set/{código}.json` "número|idioma" → código da variação
///   `img/{id}.jpg`      imagens; `data/config.json`: o endereço da busca
class LifeLinkCards {
  LifeLinkCards._();
  static final LifeLinkCards instance = LifeLinkCards._();

  static const r2 = 'https://pub-3077717c9bb54c58a316369e197147fa.r2.dev';

  /// Para os testes trocarem a rede.
  http.Client client = http.Client();

  final Map<String, Future<Map<String, dynamic>?>> _files = {};
  String? _searchUrl;
  DateTime _pricesDay = DateTime.now();

  /// Um arquivo do R2 (guardado enquanto o app está aberto); null = não existe.
  Future<Map<String, dynamic>?> _file(String path) {
    // Os preços mudam todo dia: esquece os de ontem.
    final now = DateTime.now();
    if (now.day != _pricesDay.day) {
      _files.removeWhere((k, _) => k.startsWith('pr/'));
      _pricesDay = now;
    }
    return _files.putIfAbsent(path, () async {
      try {
        final r = await client.get(Uri.parse('$r2/$path')).timeout(const Duration(seconds: 20));
        if (r.statusCode == 404) return null;
        if (r.statusCode != 200) throw http.ClientException('R2 ${r.statusCode}');
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
      } catch (e) {
        _files.remove(path); // sem internet: tenta de novo na próxima vez
        rethrow;
      }
    });
  }

  // ------------------------------------------------------------- imagens

  /// A imagem da variação: do R2 quando já foi copiada, senão do servidor de
  /// imagens da Scryfall (não é a API).
  static String imageUrl(String id, {bool inR2 = true, bool back = false}) {
    if (inR2) return '$r2/img/$id${back ? '-b' : ''}.jpg';
    return 'https://cards.scryfall.io/normal/${back ? 'back' : 'front'}/${id[0]}/${id[1]}/$id.jpg';
  }

  // --------------------------------------------------------------- cartas

  /// A carta inteira (todas as variações, com os preços de hoje).
  Future<Map<String, dynamic>?> card(String oracle) async {
    final results = await Future.wait([_file('c/$oracle.json'), _file('pr/${oracle.substring(0, 2)}.json').catchError((_) => null)]);
    final card = results[0];
    if (card == null) return null;
    final prices = (results[1]?[oracle] as Map?) ?? const {};
    return {
      ...card,
      'v': [
        for (final v in (card['v'] as List? ?? const []))
          {...Map<String, dynamic>.from(v as Map), r'$': ?prices[v['id']]},
      ],
    };
  }

  /// A carta e a variação de um código (o que fica salvo nos decks).
  Future<({Map<String, dynamic> card, Map<String, dynamic> variation})?> byPrint(String id) async {
    if (id.length < 3) return null;
    final map = await _file('id/${id.substring(0, 3)}.json');
    final oracle = map?[id] as String?;
    if (oracle == null) return null;
    final c = await card(oracle);
    if (c == null) return null;
    final v = (c['v'] as List).cast<Map<String, dynamic>>().firstWhere((v) => v['id'] == id, orElse: () => (c['v'] as List).first as Map<String, dynamic>);
    return (card: c, variation: v);
  }

  /// O código da variação pela coleção e número (a câmera).
  Future<String?> printBySetNumber(String set, String number, {String lang = 'en'}) async {
    final map = await _file('set/${set.toLowerCase()}.json');
    return (map?['$number|$lang'] ?? map?['$number|en'] ?? map?['$number|pt']) as String?;
  }

  /// As cartas de uma coleção na ordem dos números (1, 2, 3...), uma por
  /// número, no idioma pedido quando existe (senão em inglês).
  Future<List<Map<String, dynamic>>> setCards(String set, {String lang = 'pt'}) async {
    final r = await client.get(Uri.parse('$r2/s/${set.toLowerCase()}.json')).timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return const [];
    if (r.statusCode != 200) throw http.ClientException('R2 ${r.statusCode}');
    final rows = (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<List>();
    final byNumber = <String, List>{};
    for (final row in rows) {
      final old = byNumber[row[1]];
      if (old == null || (row[2] == lang && old[2] != lang)) byNumber['${row[1]}'] = row;
    }
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add('${row[1]}'))
          () {
            final pick = byNumber['${row[1]}']!;
            final name = '${pick[7]}'.isNotEmpty ? pick[7] : pick[6];
            return {
              'id': pick[0],
              'collectorNumber': pick[1],
              'lang': pick[2],
              'rarity': pick[3],
              'imageUrl': imageUrl('${pick[0]}', inR2: pick[4] == 1),
              'oracle_id': pick[5],
              'name': name,
              'enName': pick[6],
            };
          }(),
    ];
  }

  /// As coleções (código, nome, data, tipo e quantas cartas), mais novas primeiro.
  Future<List<Map<String, dynamic>>> setsInfo() async {
    final r = await client.get(Uri.parse('$r2/data/sets-info.json')).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw http.ClientException('R2 ${r.statusCode}');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map<String, dynamic>>();
  }

  /// Código da coleção → nome.
  Future<Map<String, String>> sets() async =>
      ((await _file('sets.json')) ?? const {}).map((k, v) => MapEntry(k, '$v'));

  /// A variação principal no idioma pedido (português ou inglês).
  static Map<String, dynamic> variationFor(Map<String, dynamic> card, {String lang = 'pt'}) {
    final vs = (card['v'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (lang == 'pt') {
      final pt = vs.where((v) => v['l'] == 'pt');
      if (pt.isNotEmpty) return pt.first;
    }
    return vs.firstWhere((v) => v['id'] == card['id'], orElse: () => vs.isEmpty ? {'id': card['id']} : vs.first);
  }

  static String? _price(Map? prices, List<String> keys) {
    for (final k in keys) {
      final p = prices?[k];
      if (p != null) return '$p';
    }
    return null;
  }

  /// A carta no formato que o resto do app usa (decks, ficha, busca).
  static Map<String, dynamic> toApp(Map<String, dynamic> card, Map<String, dynamic> v, {String lang = 'pt'}) {
    final pt = lang == 'pt';
    final faces = (card['f'] as List? ?? const []).cast<Map>();
    final prices = v[r'$'] as Map?;
    final setNames = card['_sets'] as Map?;
    return {
      'id': v['id'],
      'name': (pt ? v['pn'] ?? card['pn'] : null) ?? card['n'],
      'enName': card['n'],
      'imageUrl': imageUrl('${v['id']}', inR2: v['i'] == 1),
      if (v['b'] == 1) 'backImageUrl': imageUrl('${v['id']}', inR2: v['i'] == 1, back: true),
      'rarity': v['r'] ?? card['r'],
      'color_identity': card['ci'] ?? '',
      'mana_cost': card['m'] ?? (faces.isNotEmpty ? faces.first['m'] : '') ?? '',
      'type_line': (pt ? v['pt'] ?? card['pt'] : null) ?? card['t'] ?? '',
      'oracle_text': (pt ? v['px'] ?? card['px'] : null) ?? card['x'] ?? (faces.isNotEmpty ? faces.first['x'] : '') ?? '',
      'oracle_id': card['o'],
      'setName': setNames?[v['s']] ?? (v['s'] ?? '').toString().toUpperCase(),
      'setCode': v['s'],
      'collectorNumber': v['cn'],
      'lang': v['l'],
      'cmc': card['cmc'],
      'power': card['pw'] ?? (faces.isNotEmpty ? faces.first['pw'] : null),
      'toughness': card['tg'] ?? (faces.isNotEmpty ? faces.first['tg'] : null),
      'usdPrice': _price(prices, ['usd', 'usd_foil', 'usd_etched']) ?? '0.00',
      'usdFoil': _price(prices, ['usd_foil']),
      'eurPrice': _price(prices, ['eur', 'eur_foil']),
      'tixPrice': _price(prices, ['tix']),
    };
  }

  /// Os detalhes da ficha no mesmo formato da Scryfall (legalidade, artista,
  /// texto ilustrativo...), para a tela da carta.
  static Map<String, dynamic> details(Map<String, dynamic> card, Map<String, dynamic> v) {
    const names = {'l': 'legal', 'b': 'banned', 'r': 'restricted'};
    final prices = v[r'$'] as Map?;
    return {
      'id': v['id'],
      'oracle_id': card['o'],
      'name': card['n'],
      'legalities': {for (final e in ((card['lg'] as Map?) ?? const {}).entries) e.key: names[e.value] ?? 'not_legal'},
      'artist': v['a'],
      'flavor_text': v['ft'],
      'game_changer': card['gc'] == 1,
      'reserved': card['rs'] == 1,
      'edhrec_rank': card['er'],
      'keywords': card['kw'] ?? const [],
      'frame': v['fr'],
      'finishes': v['fn'] ?? const [],
      'released_at': v['d'],
      'prices': {for (final e in (prices ?? const {}).entries) e.key: '${e.value}'},
      'type_line': card['t'],
      'oracle_text': card['x'],
      if (card['f'] != null)
        'card_faces': [
          for (final f in (card['f'] as List).cast<Map>()) {'name': f['n'], 'mana_cost': f['m'], 'type_line': f['t'], 'oracle_text': f['x'], 'power': f['pw'], 'toughness': f['tg']},
        ],
    };
  }

  /// A carta no formato da Scryfall (para as ferramentas de deck: preço,
  /// legalidade, curva de mana, bracket).
  static Map<String, dynamic> scryfallLike(Map<String, dynamic> card, Map<String, dynamic> v) {
    final d = details(card, v);
    final faces = (card['f'] as List? ?? const []).cast<Map>();
    return {
      ...d,
      'lang': v['l'],
      if (v['pn'] ?? card['pn'] != null) 'printed_name': v['pn'] ?? card['pn'],
      'mana_cost': card['m'] ?? (faces.isNotEmpty ? faces.first['m'] : ''),
      'cmc': card['cmc'],
      'colors': '${card['c'] ?? ''}'.split(''),
      'color_identity': [for (final c in '${card['ci'] ?? ''}'.split('')) if (c.isNotEmpty) c],
      'rarity': v['r'],
      'set': v['s'],
      'collector_number': v['cn'],
      'image_uris': {'normal': imageUrl('${v['id']}', inR2: v['i'] == 1)},
    };
  }

  /// Várias cartas pelo código (as que não estão no banco ficam de fora).
  Future<Map<String, Map<String, dynamic>>> many(Iterable<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    final list = ids.toSet().toList();
    for (var start = 0; start < list.length; start += 20) {
      final found = await Future.wait(list.skip(start).take(20).map((id) => byPrint(id).catchError((_) => null)));
      for (final f in found) {
        if (f != null) out['${f.variation['id']}'] = scryfallLike(f.card, f.variation);
      }
    }
    return out;
  }

  /// A carta pelo código, já no formato do app.
  Future<Map<String, dynamic>?> appCard(String id, {String lang = 'pt'}) async {
    final found = await byPrint(id);
    if (found == null) return null;
    final sets = await this.sets().catchError((_) => <String, String>{});
    return toApp({...found.card, '_sets': sets}, found.variation, lang: lang);
  }

  /// As outras versões (variações) da carta no idioma pedido (inglês ou
  /// português), mais novas primeiro, no formato do app.
  Future<List<Map<String, dynamic>>> versions(String oracle, {String lang = 'pt'}) async {
    final c = await card(oracle);
    if (c == null) return const [];
    final sets = await this.sets().catchError((_) => <String, String>{});
    final withSets = {...c, '_sets': sets};
    return [
      for (final v in (c['v'] as List).cast<Map<String, dynamic>>())
        if (v['l'] == lang || (lang != 'pt' && v['l'] == 'en')) toApp(withSets, v, lang: lang),
    ];
  }

  /// As variações mais caras (inglês e português), no formato da Scryfall.
  Future<List<Map<String, dynamic>>> topPrices() async {
    final r = await client.get(Uri.parse('$r2/data/top.json')).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw http.ClientException('R2 ${r.statusCode}');
    return [
      for (final t in (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map>())
        {
          'id': t['id'],
          'oracle_id': t['o'],
          'name': t['n'],
          if (t['pn'] != null) 'printed_name': t['pn'],
          'lang': t['l'],
          'set': t['s'],
          'set_name': t['sn'],
          'collector_number': t['cn'],
          'rarity': t['r'],
          'mana_cost': t['m'] ?? '',
          'type_line': t['t'] ?? '',
          'color_identity': [for (final c in '${t['ci'] ?? ''}'.split('')) if (c.isNotEmpty) c],
          'prices': {for (final e in ((t[r'$'] as Map?) ?? const {}).entries) e.key: '${e.value}'},
          'image_uris': {'normal': imageUrl('${t['id']}', inR2: t['i'] == 1)},
        },
    ];
  }

  // ---------------------------------------------------------------- busca

  Future<String> _search() async {
    if (_searchUrl != null) return _searchUrl!;
    final config = await _file('data/config.json');
    final url = config?['search'] as String?;
    if (url == null) throw http.ClientException('A busca ainda não está no ar');
    return _searchUrl = url;
  }

  Future<Map<String, dynamic>> _ask(String path, Map<String, String> params) async {
    final base = await _search();
    final uri = Uri.parse('$base/$path').replace(queryParameters: {for (final e in params.entries) if (e.value.isNotEmpty) e.key: e.value});
    final r = await client.get(uri).timeout(const Duration(seconds: 20));
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode != 200) throw http.ClientException('${body['error'] ?? 'Busca ${r.statusCode}'}');
    return body;
  }

  /// Busca (nome, tipo ou texto, em português ou inglês), com filtros.
  /// order: relevance (padrão com texto), name, cmc, usd, released, popular.
  Future<({List<Map<String, dynamic>> cards, bool hasMore})> search({
    String text = '',
    bool nameOnly = false,
    List<String> types = const [],
    String? set,
    String? colors,
    String? order,
    bool desc = false,
    int page = 0,
    String lang = 'pt',
  }) async {
    final body = await _ask('search', {
      'q': text,
      if (nameOnly) 'name': '1',
      'type': types.join(','),
      'set': set ?? '',
      'colors': ?colors,
      'order': order ?? '',
      if (desc) 'dir': 'desc',
      'page': '$page',
      'lang': lang,
    });
    final pt = lang == 'pt';
    return (
      cards: [
        for (final r in (body['cards'] as List).cast<Map>())
          {
            'id': r['id'],
            'name': (pt ? r['pn'] : null) ?? r['n'],
            'enName': r['n'],
            'imageUrl': imageUrl('${r['id']}', inR2: r['img'] == 1),
            'rarity': r['r'],
            'color_identity': r['ci'] ?? '',
            'mana_cost': r['m'] ?? '',
            'type_line': (pt ? r['pt'] : null) ?? r['t'] ?? '',
            'oracle_id': r['o'],
            'cmc': r['cmc'],
            'usdPrice': r['usd'] == null ? '0.00' : (r['usd'] as num).toStringAsFixed(2),
          },
      ],
      hasMore: body['hasMore'] == true,
    );
  }

  /// Sugestões de nome enquanto digita.
  Future<List<String>> names(String text, {String lang = 'pt'}) async {
    final body = await _ask('names', {'q': text});
    return [
      for (final r in (body['names'] as List).cast<Map>()) '${(lang == 'pt' ? r['pn'] : null) ?? r['n']}',
    ];
  }
}
