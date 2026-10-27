import 'deck_tools.dart';
import 'lifelink_cards.dart';

/// Uma linha da coleção para exportar: quantas, para troca, o nome em inglês,
/// o código da coleção e o número.
typedef CollectionRow = ({int qty, bool trade, String name, String set, String number});

/// Importar e exportar a coleção (o mesmo do site, web-site/src/lib/collectionCsv.js):
/// lê o CSV do Moxfield, ManaBox, Archidekt e Deckbox (ou uma lista de texto,
/// "1 Sol Ring (CMM) 410") e gera o CSV no formato do Moxfield, que esses
/// sites e apps também importam.
class CollectionCsv {
  /// O texto CSV → linhas (com aspas, vírgula, ponto e vírgula ou tab).
  static List<List<String>> parseCsv(String text) {
    final s = text.replaceFirst('﻿', '');
    final first = s.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final sep = ([',', ';', '\t']..sort((a, b) => first.split(b).length.compareTo(first.split(a).length))).first;
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    void endRow() {
      row.add(cell.toString());
      cell.clear();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (quoted) {
        if (ch == '"' && i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == sep) {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
        endRow();
      } else {
        cell.write(ch);
      }
    }
    endRow();
    return rows;
  }

  // Os nomes das colunas em cada site (em minúsculas).
  static const _columns = {
    'qty': ['count', 'quantity', 'qty', 'amount', 'quantidade', 'qtd'],
    'name': ['name', 'card name', 'card', 'nome'],
    'set': ['edition', 'set code', 'set', 'edition code', 'set_code', 'edicao', 'coleção', 'colecao'],
    'number': ['collector number', 'card number', 'number', 'collector_number', 'cn', 'numero', 'número'],
  };

  /// O que foi colado (ou o arquivo) → as linhas. Com o cabeçalho de um CSV
  /// conhecido lê as colunas; sem ele, lê como lista de texto.
  static List<DeckLine> parse(String text) {
    final rows = parseCsv(text);
    final header = [for (final h in rows.isEmpty ? const <String>[] : rows.first) h.trim().toLowerCase()];
    int col(String key) => header.indexWhere((h) => _columns[key]!.contains(h));
    final name = col('name');
    if (rows.length < 2 || name < 0) {
      return [for (final l in DeckTools.parse(text)) DeckLine(l.qty, l.name, set: l.set, number: l.number)];
    }
    final qty = col('qty'), set = col('set'), number = col('number');
    String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    final out = <DeckLine>[];
    for (final r in rows.skip(1)) {
      final n = at(r, name);
      if (n.isEmpty) continue;
      final q = qty >= 0 ? int.tryParse(at(r, qty)) : 1;
      // A coleção pelo código (ex.: "cmm"); o nome da coleção (Deckbox) não serve.
      final code = at(r, set);
      final num = at(r, number);
      out.add(DeckLine(
        q != null && q > 0 ? (q > 999 ? 999 : q) : 1,
        n,
        set: RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(code) ? code.toLowerCase() : null,
        number: num.isEmpty ? null : num,
      ));
    }
    return out;
  }

  static String _quote(Object? v) => '"${'${v ?? ''}'.replaceAll('"', '""')}"';

  /// As cartas da coleção → o CSV do Moxfield.
  static String csv(List<CollectionRow> rows) {
    const header = ['Count', 'Tradelist Count', 'Name', 'Edition', 'Condition', 'Language', 'Foil', 'Tags', 'Last Modified', 'Collector Number', 'Alter', 'Proxy', 'Purchase Price'];
    return [
      header.map(_quote).join(','),
      for (final r in rows) [r.qty, r.trade ? r.qty : 0, r.name, r.set, 'Near Mint', 'English', '', '', '', r.number, 'False', 'False', ''].map(_quote).join(','),
    ].join('\n');
  }

  /// Uma lista de texto da coleção ("1 Sol Ring (CMM) 410").
  static String list(List<CollectionRow> rows) => [
        for (final r in rows) '${r.qty} ${r.name}${r.set.isNotEmpty ? ' (${r.set.toUpperCase()})${r.number.isNotEmpty ? ' ${r.number}' : ''}' : ''}',
      ].join('\n');

  /// As cartas para pôr na coleção: [(carta, quantas)] e os nomes não encontrados.
  static Future<({List<(Map<String, dynamic>, int)> cards, int copies, List<String> missing})> fetch(String text) async {
    final lines = parse(text);
    if (lines.isEmpty) return (cards: const <(Map<String, dynamic>, int)>[], copies: 0, missing: const <String>[]);
    final result = await DeckTools.fetch(lines);
    final byId = <String, (Map<String, dynamic>, int)>{};
    for (final c in result.cards) {
      final id = DeckTools.scryfallIdOf(c) ?? '${c['name']}';
      final e = byId[id];
      byId[id] = (c, (e?.$2 ?? 0) + 1);
    }
    return (cards: byId.values.toList(), copies: result.cards.length, missing: result.missing);
  }

  /// As linhas para exportar, com o nome em inglês e o código da coleção
  /// (do banco do LifeLink; o que faltar, da Scryfall).
  static Future<List<CollectionRow>> rows(List<({String id, String name, String number, int qty, bool trade})> saved) async {
    final ids = [for (final c in saved) if (RegExp(r'^[0-9a-f-]{36}$').hasMatch(c.id)) c.id];
    final found = <String, Map>{};
    try {
      found.addAll(await LifeLinkCards.instance.many(ids));
    } catch (_) {}
    final rest = [for (final id in ids) if (!found.containsKey(id)) id];
    for (var start = 0; start < rest.length; start += 75) {
      try {
        final data = await DeckTools.postCollection([for (final id in rest.skip(start).take(75)) {'id': id}]);
        for (final c in (data['data'] as List? ?? const [])) {
          found['${(c as Map)['id']}'] = c;
        }
      } catch (_) {
        break;
      }
    }
    return [
      for (final c in saved)
        (
          qty: c.qty,
          trade: c.trade,
          name: '${found[c.id]?['name'] ?? c.name}',
          set: '${found[c.id]?['set'] ?? ''}',
          number: '${found[c.id]?['collector_number'] ?? c.number}',
        ),
    ];
  }
}
