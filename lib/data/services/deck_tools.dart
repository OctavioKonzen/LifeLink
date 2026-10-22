import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'lifelink_cards.dart';
import 'scryfall_service.dart';

/// Uma linha de uma lista de deck ("4 Lightning Bolt", "1 Sol Ring (CMM) 410").
class DeckLine {
  final int qty;
  final String name;
  final String? set;
  final String? number;
  final bool commander;
  const DeckLine(this.qty, this.name, {this.set, this.number, this.commander = false});

  @override
  String toString() => '$qty $name${set != null ? ' ($set)' : ''}${number != null ? ' $number' : ''}';
}

/// Ferramentas de deck (as mesmas do site, web-site/src/lib/deckTools.js):
/// ler listas do Moxfield, Archidekt, MTG Arena e MTGO, buscar as cartas na
/// Scryfall de 75 em 75, preço, legalidade por formato e a mão de teste.
class DeckTools {
  // Seções que não entram no deck (o "talvez" e o banco de reservas).
  static final _skipSections = RegExp(r'^(sideboard|maybeboard|considering|maybe|tokens?|banco|reservas)\b', caseSensitive: false);
  // Cabeçalho: só a palavra, com a quantidade ou dois-pontos ("Creatures (30)", "Sideboard:").
  static final _sections = RegExp(
      r'^(commander|comandante|deck|mainboard|main|companion|sideboard|maybeboard|considering|maybe|tokens?|banco|reservas|lands?|creatures?|spells?|artifacts?|enchantments?|instants?|sorcery|sorceries|planeswalkers?|terrenos?|criaturas?)\s*(\(\d+\))?\s*:?$',
      caseSensitive: false);
  static final _line = RegExp(r'^(\d+)\s*[xX]?\s+(.+?)$');
  static final _setNumber = RegExp(r'\s+\(([A-Za-z0-9]{2,6})\)(?:\s+([A-Za-z0-9\-★]+))?\s*$');

  /// Lê a lista colada. Linhas sem número contam 1; cabeçalhos ("Commander",
  /// "Sideboard") separam as seções; o banco de reservas e o "talvez" ficam de fora.
  static List<DeckLine> parse(String text) {
    final out = <DeckLine>[];
    var skipping = false;
    var commander = false;
    for (var raw in const LineSplitter().convert(text)) {
      var line = raw.trim();
      if (line.isEmpty) {
        // Na lista do MTG Arena, a linha em branco separa o deck do banco.
        continue;
      }
      if (line.startsWith('//') || line.startsWith('#')) {
        final title = line.replaceFirst(RegExp(r'^(//|#)+\s*'), '');
        skipping = _skipSections.hasMatch(title);
        commander = RegExp(r'^(commander|comandante)', caseSensitive: false).hasMatch(title);
        continue;
      }
      if (RegExp(r'^SB:\s*', caseSensitive: false).hasMatch(line)) continue; // banco do MTGO
      if (_sections.hasMatch(line)) {
        final title = line.replaceAll(RegExp(r'[:(].*$'), '').trim();
        skipping = _skipSections.hasMatch(title);
        commander = RegExp(r'^(commander|comandante)', caseSensitive: false).hasMatch(title);
        continue;
      }
      if (skipping) continue;

      // Marcadores do Archidekt/Moxfield: [Ramp], ^Tag^, *F* (foil), *CMDR*.
      final isCommander = commander || line.contains('*CMDR*') || line.contains('[Commander');
      line = line
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'\^[^^]*\^'), '')
          .replaceAll(RegExp(r'\*[A-Za-z]+\*'), '')
          .trim();

      var qty = 1;
      var name = line;
      final m = _line.firstMatch(line);
      if (m != null) {
        qty = int.parse(m.group(1)!);
        name = m.group(2)!;
      }
      String? set;
      String? number;
      final s = _setNumber.firstMatch(name);
      if (s != null) {
        set = s.group(1)!.toLowerCase();
        number = s.group(2);
        name = name.substring(0, s.start);
      }
      name = name.trim();
      if (name.isEmpty || qty <= 0) continue;
      out.add(DeckLine(min(qty, 250), name, set: set, number: number, commander: isCommander));
    }
    return out;
  }

  /// Busca as cartas na Scryfall (de 75 em 75). Volta as cartas na ordem da
  /// lista (com repetição pela quantidade) e os nomes não encontrados.
  static Future<({List<Map<String, dynamic>> cards, List<String> missing, List<Map<String, dynamic>> commanders})> fetch(List<DeckLine> lines) async {
    final found = <int, Map<String, dynamic>>{};
    final missing = <String>[];
    // Primeiro no banco do LifeLink (coleção e número no R2, ou o nome na
    // busca da Cloudflare); o que não achar vai para a Scryfall.
    final own = await _fetchOwn(lines);
    final rest = [for (var i = 0; i < lines.length; i++) if (!own.containsKey(i)) i];
    for (var start = 0; start < rest.length; start += 75) {
      final idx = rest.sublist(start, min(start + 75, rest.length));
      final chunk = [for (final i in idx) lines[i]];
      final ids = [
        for (final l in chunk)
          l.set != null && l.number != null ? {'set': l.set, 'collector_number': l.number} : {'name': l.name},
      ];
      final data = await postCollection(ids);
      // A Scryfall devolve as encontradas na ordem pedida, sem as que faltaram.
      final notFound = [for (final n in (data['not_found'] as List? ?? const [])) Map<String, dynamic>.from(n as Map)];
      final cards = [for (final c in (data['data'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
      var k = 0;
      for (var i = 0; i < chunk.length; i++) {
        final asked = ids[i];
        if (notFound.any((n) => n['name'] == asked['name'] && n['set'] == asked['set'] && n['collector_number'] == asked['collector_number'])) {
          // Com edição errada, tenta só pelo nome; com nome errado, a Scryfall tenta adivinhar.
          try {
            final name = Uri.encodeQueryComponent(chunk[i].name);
            found[idx[i]] = await ScryfallService.instance.getJson('https://api.scryfall.com/cards/named?fuzzy=$name');
          } catch (_) {
            missing.add(chunk[i].name);
          }
          continue;
        }
        if (k < cards.length) found[idx[i]] = cards[k++];
      }
    }
    final out = <Map<String, dynamic>>[];
    final commanders = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      final c = own[i] ?? (found[i] == null ? null : deckCardOf(found[i]!));
      if (c == null) continue;
      final card = {...c, if (lines[i].commander) 'commander': true};
      if (lines[i].commander) commanders.add(card);
      for (var q = 0; q < lines[i].qty; q++) {
        out.add(card);
      }
    }
    return (cards: out, missing: missing, commanders: commanders);
  }

  /// As linhas da lista achadas no banco do LifeLink: índice → carta de deck.
  static Future<Map<int, Map<String, dynamic>>> _fetchOwn(List<DeckLine> lines) async {
    final out = <int, Map<String, dynamic>>{};
    final cards = LifeLinkCards.instance;
    Future<void> one(int i) async {
      final l = lines[i];
      try {
        if (l.set != null && l.number != null) {
          final id = await cards.printBySetNumber(l.set!, l.number!);
          if (id != null) {
            final c = await cards.appCard(id, lang: 'en');
            if (c != null) out[i] = c;
            return;
          }
        }
        final found = await cards.search(text: l.name, nameOnly: true, lang: 'en');
        final hit = found.cards.where((c) => '${c['enName']}'.toLowerCase() == l.name.toLowerCase() || '${c['enName']}'.toLowerCase().startsWith('${l.name.toLowerCase()} //'));
        if (hit.isEmpty) return;
        final c = await cards.appCard('${hit.first['id']}', lang: 'en');
        if (c != null) out[i] = c;
      } catch (_) {}
    }

    for (var start = 0; start < lines.length; start += 10) {
      await Future.wait([for (var i = start; i < min(start + 10, lines.length); i++) one(i)]);
    }
    return out;
  }

  /// POST /cards/collection (até 75 cartas por pedido).
  static Future<Map<String, dynamic>> postCollection(List<Map<String, dynamic>> identifiers) async {
    final response = await http
        .post(
          Uri.parse('https://api.scryfall.com/cards/collection'),
          headers: {...ScryfallService.headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'identifiers': identifiers}),
        )
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) throw ScryfallService.errorFor(response.statusCode, data);
    return data;
  }

  /// Carta da API → carta de deck (o mesmo formato do resto do app).
  static Map<String, dynamic> deckCardOf(Map<String, dynamic> data) => {
        'id': data['id'],
        'name': data['name'] ?? 'Carta Desconhecida',
        'imageUrl': CardImages.normalOf(data) ?? CardImages.cardBack,
        'backImageUrl': data['card_faces']?[1]?['image_uris']?['normal'],
        'type_line': data['type_line'] ?? data['card_faces']?[0]?['type_line'] ?? '',
        'oracle_text': data['oracle_text'] ?? data['card_faces']?[0]?['oracle_text'] ?? '',
        'rarity': data['rarity'] ?? 'common',
        'mana_cost': data['mana_cost'] ?? data['card_faces']?[0]?['mana_cost'] ?? '',
        'cmc': data['cmc'] ?? 0,
        'power': data['power']?.toString(),
        'toughness': data['toughness']?.toString(),
        'color_identity': (data['color_identity'] as List?)?.join('') ?? '',
        'setName': data['set_name'] ?? '',
        'collectorNumber': data['collector_number'] ?? '',
        'oracle_id': data['oracle_id'],
        'usdPrice': data['prices']?['usd'] ?? data['prices']?['usd_foil'] ?? '0.00',
        'eurPrice': data['prices']?['eur'],
      };

  /// Id da Scryfall de uma carta de deck (decks antigos só têm a imagem).
  static String? scryfallIdOf(Map<String, dynamic> card) {
    final id = card['id']?.toString();
    if (id != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) return id;
    final m = RegExp(r'/([0-9a-f-]{36})\.(?:jpg|png)').firstMatch(card['imageUrl']?.toString() ?? '');
    return m?.group(1);
  }

  /// As cartas do deck atualizadas na Scryfall (preço e legalidade de hoje),
  /// uma de cada (pelo id da Scryfall ou pelo nome).
  static Future<Map<String, Map<String, dynamic>>> refresh(List<Map<String, dynamic>> deck) async {
    final unique = <String, Map<String, dynamic>>{};
    for (final c in deck) {
      final id = scryfallIdOf(c);
      unique[id ?? 'name:${c['name']}'] = id != null ? {'id': id} : {'name': c['name']};
    }
    final out = <String, Map<String, dynamic>>{};
    // Primeiro no banco do LifeLink (R2); o que não estiver lá, na Scryfall.
    try {
      final own = await LifeLinkCards.instance.many(unique.keys.where((k) => !k.startsWith('name:')));
      for (final e in own.entries) {
        out[e.key] = e.value;
        out['name:${e.value['name']}'] = e.value;
        if (e.value['printed_name'] != null) out['name:${e.value['printed_name']}'] = e.value;
        unique.remove(e.key);
      }
    } catch (_) {}
    final keys = unique.keys.toList();
    for (var start = 0; start < keys.length; start += 75) {
      final chunk = keys.sublist(start, min(start + 75, keys.length));
      final data = await postCollection([for (final k in chunk) unique[k]!]);
      for (final c in (data['data'] as List? ?? const [])) {
        final card = Map<String, dynamic>.from(c as Map);
        out[card['id']] = card;
        out['name:${card['name']}'] = card;
        // Pedido pelo nome traduzido (deck em português): fica pelo nome impresso também.
        if (card['printed_name'] != null) out['name:${card['printed_name']}'] = card;
      }
    }
    return out;
  }

  static Map<String, dynamic>? fresh(Map<String, Map<String, dynamic>> table, Map<String, dynamic> card) =>
      table[scryfallIdOf(card) ?? ''] ?? table['name:${card['name']}'];

  // ------------------------------------------------------------- legalidade

  static const formats = {
    'commander': 'Commander',
    'standard': 'Standard',
    'pioneer': 'Pioneer',
    'modern': 'Modern',
    'legacy': 'Legacy',
    'vintage': 'Vintage',
    'pauper': 'Pauper',
  };

  static bool _anyNumber(Map<String, dynamic> c) {
    final type = '${c['type_line'] ?? ''}';
    final text = '${c['oracle_text'] ?? ''}';
    return type.contains('Basic Land') || type.contains('Terreno Básico') || text.contains('A deck can have any number of cards named');
  }

  /// Os problemas do deck num formato (vazio = legal). [cards] são as cartas
  /// atualizadas da Scryfall, uma por cópia no deck.
  static List<String> problems(String format, List<Map<String, dynamic>> cards) {
    final out = <String>[];
    final counts = <String, int>{};
    for (final c in cards) {
      counts['${c['name']}'] = (counts['${c['name']}'] ?? 0) + 1;
    }
    final byName = {for (final c in cards) '${c['name']}': c};
    for (final e in byName.entries) {
      final status = (e.value['legalities'] as Map?)?[format];
      if (status == 'banned') out.add('${e.key}: banida');
      if (status == 'not_legal') out.add('${e.key}: não é legal');
      if (status == 'restricted' && (counts[e.key] ?? 0) > 1) out.add('${e.key}: restrita (só 1 cópia)');
    }
    final total = cards.length;
    if (format == 'commander') {
      if (total != 100) out.insert(0, 'O deck tem $total cartas (Commander pede 100, com o comandante).');
      for (final e in counts.entries) {
        if (e.value > 1 && !_anyNumber(byName[e.key]!)) out.add('${e.key}: ${e.value} cópias (Commander é 1 de cada)');
      }
    } else {
      if (total < 60) out.insert(0, 'O deck tem $total cartas (o mínimo é 60).');
      for (final e in counts.entries) {
        if (e.value > 4 && !_anyNumber(byName[e.key]!)) out.add('${e.key}: ${e.value} cópias (o máximo é 4)');
      }
    }
    return out;
  }

  // -------------------------------------------------------------- dinheiro

  /// Quanto vale 1 dólar em reais hoje (null se não deu para saber).
  static Future<double?> dollarInReais() async {
    try {
      final r = await http.get(Uri.parse('https://economia.awesomeapi.com.br/json/last/USD-BRL')).timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return double.tryParse('${data['USDBRL']?['bid']}');
    } catch (_) {
      return null;
    }
  }

  static double priceOf(Map<String, dynamic> card) =>
      double.tryParse('${card['prices']?['usd'] ?? card['prices']?['usd_foil'] ?? card['usdPrice'] ?? ''}') ?? 0;

  // ------------------------------------------------------------ mão de teste

  /// Embaralha (Fisher-Yates).
  static List<T> shuffled<T>(List<T> list, [Random? rng]) {
    final r = rng ?? Random();
    final out = List<T>.from(list);
    for (var i = out.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }

  // ------------------------------------------------------- nível (bracket)

  static final _extraTurn = RegExp(r'takes? an extra turn', caseSensitive: false);
  static final _landDestruction = RegExp(
      r"destroy all (nonbasic )?lands|exile all lands|sacrifices? all lands|each player sacrifices (two|three|four|five|six|seven) lands|lands don't untap|lands do not untap",
      caseSensitive: false);

  static String _textOf(Map<String, dynamic> c) => [
        c['oracle_text'] ?? '',
        for (final f in (c['card_faces'] as List? ?? const [])) (f as Map)['oracle_text'] ?? '',
      ].join('\n');

  /// O nível do deck no Commander (Brackets da Wizards), pelo que dá para ver
  /// nas cartas (com os dados da Scryfall): as Game Changers, turnos extras e
  /// destruição de terrenos em massa. Combos de duas cartas e a intenção do
  /// deck (nível 1 e 5) ficam para a mesa conversar.
  static ({int bracket, List<String> gameChangers, List<String> extraTurns, List<String> landDestruction}) bracket(List<Map<String, dynamic>> cards) {
    final gc = <String>{}, turns = <String>{}, mld = <String>{};
    for (final c in cards) {
      final name = '${c['printed_name'] ?? c['name']}';
      if (c['game_changer'] == true) gc.add(name);
      final text = _textOf(c);
      if (_extraTurn.hasMatch(text)) turns.add(name);
      if (_landDestruction.hasMatch(text)) mld.add(name);
    }
    final level = (gc.length > 3 || mld.isNotEmpty || turns.length > 1)
        ? 4
        : gc.isNotEmpty || turns.isNotEmpty
            ? 3
            : 2;
    return (bracket: level, gameChangers: gc.toList()..sort(), extraTurns: turns.toList()..sort(), landDestruction: mld.toList()..sort());
  }

  static const bracketNames = {1: 'Exibição', 2: 'Básico', 3: 'Melhorado', 4: 'Otimizado', 5: 'cEDH'};

  // ------------------------------------------------------------ sugestões

  /// O nome da página do comandante no EDHREC ("Atraxa, Praetors' Voice" →
  /// "atraxa-praetors-voice"; carta de duas faces: só a da frente).
  static String edhrecSlug(String name) => name
      .split(' // ')
      .first
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s-]"), '')
      .trim()
      .replaceAll(RegExp(r'[\s-]+'), '-');

  // Terreno básico não é sugestão (todo deck tem).
  static final _basicLand = RegExp(r'^(Snow-Covered )?(Plains|Island|Swamp|Mountain|Forest)$|^Wastes$');

  /// Os nomes das cartas que o EDHREC mais recomenda para o comandante, das
  /// mais usadas para as menos (sem as que já estão no deck).
  static List<String> edhrecNames(Map<String, dynamic> page, Set<String> skip) {
    final lists = page['container']?['json_dict']?['cardlists'] as List? ?? const [];
    final score = <String, double>{};
    for (final l in lists) {
      for (final v in ((l as Map)['cardviews'] as List? ?? const [])) {
        final c = v as Map;
        final name = '${c['name'] ?? ''}';
        if (name.isEmpty || skip.contains(name.toLowerCase()) || _basicLand.hasMatch(name)) continue;
        final potential = (c['potential_decks'] as num?)?.toDouble() ?? 0;
        final used = ((c['inclusion'] ?? c['num_decks']) as num?)?.toDouble() ?? 0;
        final s = (potential > 0 ? used / potential : 0) + ((c['synergy'] as num?)?.toDouble() ?? 0) * 0.3;
        score[name] = max(score[name] ?? -1, s);
      }
    }
    return (score.keys.toList()..sort((a, b) => score[b]!.compareTo(score[a]!)));
  }

  /// Sugestões de cartas para o comandante do deck: do EDHREC e, se não der,
  /// as mais populares nas cores dele (ordem do EDHREC na Scryfall).
  static Future<({List<Map<String, dynamic>> cards, String source})> suggestions(Map<String, dynamic> commander, List<Map<String, dynamic>> deck, {int count = 40}) async {
    final skip = {for (final c in deck) '${c['name']}'.toLowerCase()};
    var names = <String>[];
    var source = 'EDHREC';
    try {
      final response = await http.get(Uri.parse('https://json.edhrec.com/pages/commanders/${edhrecSlug('${commander['name']}')}.json')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        names = edhrecNames(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>, skip).take(count).toList();
      }
    } catch (_) {}
    if (names.isNotEmpty) {
      // As cartas sugeridas pelo banco do LifeLink (nome exato na busca da
      // Cloudflare, carta no R2); se ele não responder, pela Scryfall.
      try {
        final ids = <String>[];
        for (var start = 0; start < names.length; start += 10) {
          final found = await Future.wait(names.skip(start).take(10).map((n) => LifeLinkCards.instance.search(text: n, nameOnly: true, lang: 'en').then(
                (r) => r.cards.where((c) => '${c['enName']}'.toLowerCase() == n.toLowerCase()).map((c) => '${c['id']}').firstOrNull,
                onError: (_) => null,
              )));
          ids.addAll(found.whereType<String>());
        }
        final own = await LifeLinkCards.instance.many(ids);
        if (own.isNotEmpty) return (cards: [for (final id in ids) if (own[id] != null) own[id]!], source: source);
      } catch (_) {}
      final data = await postCollection([for (final n in names.take(75)) {'name': n}]);
      final byName = {for (final c in (data['data'] as List? ?? const [])) '${(c as Map)['name']}': Map<String, dynamic>.from(c)};
      return (cards: [for (final n in names) if (byName[n] != null) byName[n]!], source: source);
    }
    // Sem EDHREC: as mais jogadas nas cores do comandante (banco do LifeLink).
    try {
      final ci = commander['color_identity'] is List ? (commander['color_identity'] as List).join() : '${commander['color_identity'] ?? ''}';
      final found = await LifeLinkCards.instance.search(colors: ci.toUpperCase(), order: 'popular', lang: 'en');
      final ids = [for (final c in found.cards) if (!skip.contains('${c['enName']}'.toLowerCase()) && !'${c['type_line']}'.contains('Basic')) '${c['id']}'];
      final own = await LifeLinkCards.instance.many(ids.take(count));
      if (own.isNotEmpty) return (cards: [for (final id in ids) if (own[id] != null) own[id]!], source: 'LifeLink (mais populares nas cores do comandante)');
    } catch (_) {}
    source = 'Scryfall (mais populares nas cores do comandante)';
    final colors = (commander['color_identity'] is List ? (commander['color_identity'] as List).join() : '${commander['color_identity'] ?? ''}').toLowerCase();
    final page = await ScryfallService.instance.search('id<=${colors.isEmpty ? 'c' : colors} f:commander -t:basic', order: 'edhrec', multilingual: false);
    return (
      cards: [for (final c in page.cards) if (!skip.contains('${(c as Map)['name']}'.toLowerCase())) Map<String, dynamic>.from(c)].take(count).toList(),
      source: source,
    );
  }

  // ---------------------------------------------------------------- exportar

  /// A lista do deck para colar no Moxfield, Arena, Archidekt...: "1 Sol Ring",
  /// com o comandante numa seção à parte. [english] troca o nome (que pode
  /// estar traduzido) pelo nome em inglês, pelo id da Scryfall.
  static String exportList(List<Map<String, dynamic>> cards, {Map<String, String> english = const {}}) {
    String nameOf(Map<String, dynamic> c) => english[scryfallIdOf(c) ?? ''] ?? '${c['name'] ?? ''}';
    Map<String, int> count(bool commander) {
      final out = <String, int>{};
      for (final c in cards) {
        if ((c['commander'] == true) != commander) continue;
        final n = nameOf(c);
        if (n.isNotEmpty) out[n] = (out[n] ?? 0) + 1;
      }
      return out;
    }

    String lines(Map<String, int> m) => (m.keys.toList()..sort()).map((n) => '${m[n]} $n').join('\n');
    final commanders = count(true);
    final rest = count(false);
    return [
      if (commanders.isNotEmpty) 'Commander\n${lines(commanders)}',
      if (rest.isNotEmpty) 'Deck\n${lines(rest)}',
    ].join('\n\n');
  }

  /// Os nomes em inglês das cartas (pelo id da Scryfall); vazio sem internet.
  static Future<Map<String, String>> englishNames(List<Map<String, dynamic>> cards) async {
    try {
      final table = await refresh(cards);
      return {
        for (final c in cards)
          if (scryfallIdOf(c) != null && fresh(table, c)?['name'] != null) scryfallIdOf(c)!: '${fresh(table, c)!['name']}',
      };
    } catch (_) {
      return const {};
    }
  }
}
