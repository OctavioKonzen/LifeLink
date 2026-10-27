import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'lifelink_cards.dart';

/// Uma regra (702.19a) ou um termo do glossário.
typedef Rule = ({String id, String text});

/// As Regras Completas de Magic (data/rules.json no R2, gerado por
/// tool/build_rules.py): as regras, as seções, o glossário e o dicionário
/// português → inglês da busca.
class RulesData {
  final String effective;
  final Map<String, String> sections;
  final List<Rule> rules;
  final List<Rule> glossary; // id = o termo
  final List<(String, String)> _pt; // (" termo pt ", "termo en"), os maiores antes
  final Set<String> _stop;
  final List<String> _rulesNorm; // " texto normalizado "
  final List<String> _glossaryNorm;

  RulesData._(this.effective, this.sections, this.rules, this.glossary, this._pt, this._stop)
      : _rulesNorm = [for (final r in rules) ' ${norm(r.text)} '],
        _glossaryNorm = [for (final g in glossary) norm(g.id)];

  factory RulesData.fromJson(Map<String, dynamic> j) {
    final pt = [for (final e in (j['pt'] as Map? ?? const {}).entries) (' ${norm('${e.key}')} ', norm('${e.value}'))]
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return RulesData._(
      '${j['effective'] ?? ''}',
      {for (final e in (j['sections'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
      [for (final r in (j['rules'] as List? ?? const [])) (id: '${r[0]}', text: '${r[1]}')],
      [for (final g in (j['glossary'] as List? ?? const [])) (id: '${g[0]}', text: '${g[1]}')],
      pt,
      {for (final w in (j['stop'] as List? ?? const [])) '$w'},
    );
  }

  /// Minúsculas, sem acento e só letras e números (como no site, rules.js).
  static String norm(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  /// Os termos da pergunta: os do dicionário (em inglês) e as outras palavras.
  List<({String term, int weight})> termsOf(String query) {
    var q = ' ${norm(query)} ';
    final out = <({String term, int weight})>[];
    for (final (pt, en) in _pt) {
      if (!q.contains(pt)) continue;
      if (!out.any((t) => t.term == en)) out.add((term: en, weight: 2));
      q = q.split(pt).join(' ');
    }
    for (final w in q.split(' ')) {
      if (w.length >= 3 && !_stop.contains(w) && !out.any((t) => t.term == w)) out.add((term: w, weight: 1));
    }
    return out;
  }

  static bool _isLetterAfter(String id, String base) => id.startsWith(base) && RegExp(r'^[a-z]$').hasMatch(id.substring(base.length));

  /// A regra e as letras dela (702.19 → 702.19, 702.19a, 702.19b...).
  List<Rule> family(String id) {
    final base = id.replaceFirst(RegExp(r'[a-z]$'), '');
    return [for (final r in rules) if (r.id == base || _isLetterAfter(r.id, base)) r];
  }

  /// O nome da seção da regra (702 → "Keyword Abilities").
  String sectionOf(String id) => sections[id.length >= 3 ? id.substring(0, 3) : id] ?? '';

  /// Busca nas regras (português ou inglês) e no glossário. Um número de
  /// regra (ex.: 702.19) mostra a regra e as letras dela.
  ({List<String> terms, List<Rule> glossary, List<Rule> rules}) search(String query, {int limit = 30}) {
    final q = query.trim().replaceFirst(RegExp(r'\.$'), '');
    if (RegExp(r'^\d{3}(\.\d+[a-z]?)?$', caseSensitive: false).hasMatch(q)) {
      final id = q.toLowerCase();
      final found = id.length == 3 ? [for (final r in rules) if (r.id.startsWith('$id.')) r] : family(id);
      return (terms: const [], glossary: const [], rules: found.take(80).toList());
    }
    final terms = termsOf(q);
    if (terms.isEmpty) return (terms: const [], glossary: const [], rules: const []);
    bool has(String text, String term) => text.contains(' $term ');

    // A regra-título de um termo (ex.: "702.19. Trample") e as letras dela sobem.
    final titles = [
      for (var i = 0; i < rules.length; i++)
        if (terms.any((t) => _rulesNorm[i] == ' ${t.term} ')) rules[i].id,
    ];
    bool inTitle(String id) => titles.any((base) => id == base || _isLetterAfter(id, base));

    final scored = <(int, int)>[]; // (índice, pontos)
    for (var i = 0; i < rules.length; i++) {
      var score = 0, hits = 0;
      for (final t in terms) {
        if (!has(_rulesNorm[i], t.term)) continue;
        score += t.weight * (t.term.contains(' ') ? 2 : 1);
        hits++;
      }
      if (score == 0) continue;
      score += hits * hits + (inTitle(rules[i].id) ? 3 : 0);
      scored.add((i, score));
    }
    scored.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));

    final gloss = <(Rule, int)>[];
    for (var i = 0; i < glossary.length; i++) {
      final term = _glossaryNorm[i];
      var score = terms.any((t) => t.term == term)
          ? 20
          : terms.any((t) => t.term.length >= 4 && ' $term '.contains(' ${t.term} '))
              ? 6
              : 0;
      if (score == 0) continue;
      final def = ' ${norm(glossary[i].text)} ';
      score += terms.where((t) => has(def, t.term)).length;
      gloss.add((glossary[i], score));
    }
    gloss.sort((a, b) => b.$2.compareTo(a.$2));

    return (
      terms: [for (final t in terms) t.term],
      glossary: [for (final g in gloss.take(4)) g.$1],
      rules: [for (final s in scored.take(limit)) rules[s.$1]],
    );
  }
}

/// Baixa as regras do R2 (uma vez) e guarda no celular para abrir sem internet.
class RulesService {
  RulesService._();
  static final instance = RulesService._();

  RulesData? _data;
  Future<RulesData>? _loading;

  Future<RulesData> load() {
    if (_data != null) return Future.value(_data);
    return _loading ??= _load().then((d) => _data = d).whenComplete(() => _loading = null);
  }

  Future<File?> _file() async {
    try {
      return File('${(await getApplicationSupportDirectory()).path}/rules.json');
    } catch (_) {
      return null;
    }
  }

  Future<RulesData> _load() async {
    final file = await _file();
    try {
      final r = await http.get(Uri.parse('${LifeLinkCards.r2}/data/rules.json')).timeout(const Duration(seconds: 40));
      if (r.statusCode != 200) throw HttpException('regras ${r.statusCode}');
      final text = utf8.decode(r.bodyBytes);
      final data = RulesData.fromJson(jsonDecode(text) as Map<String, dynamic>);
      file?.writeAsString(text).catchError((_) => file);
      return data;
    } catch (_) {
      // Sem internet: as que ficaram guardadas.
      if (file != null && await file.exists()) {
        return RulesData.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}
