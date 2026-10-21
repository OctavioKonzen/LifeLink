import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
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
    for (var start = 0; start < lines.length; start += 75) {
      final chunk = lines.sublist(start, min(start + 75, lines.length));
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
            found[start + i] = await ScryfallService.instance.getJson('https://api.scryfall.com/cards/named?fuzzy=$name');
          } catch (_) {
            missing.add(chunk[i].name);
          }
          continue;
        }
        if (k < cards.length) found[start + i] = cards[k++];
      }
    }
    final out = <Map<String, dynamic>>[];
    final commanders = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      final c = found[i];
      if (c == null) continue;
      final card = deckCardOf(c);
      if (lines[i].commander) commanders.add(card);
      for (var q = 0; q < lines[i].qty; q++) {
        out.add(card);
      }
    }
    return (cards: out, missing: missing, commanders: commanders);
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
        'setName': (data['set'] ?? '').toString().toUpperCase(),
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
    final keys = unique.keys.toList();
    final out = <String, Map<String, dynamic>>{};
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
}
