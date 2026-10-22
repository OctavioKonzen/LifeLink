import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/offline_cards.dart';

void main() {
  test('separa os objetos de uma lista JSON que chega em pedaços', () {
    final cards = [
      {'name': 'Sol Ring', 'oracle_text': 'Add {C}{C}. "quoted" \\ back {x}'},
      {'name': 'Island', 'card_faces': [{'a': '}'}, {'b': '{'}]},
      {'name': 'Rhystic Study'},
    ];
    final text = '[\n${cards.map(jsonEncode).join(',\n')}\n]';
    for (final size in [1, 3, 7, 50, 10000]) {
      final splitter = JsonObjectSplitter();
      final out = <String>[];
      for (var i = 0; i < text.length; i += size) {
        out.addAll(splitter.add(text.substring(i, i + size > text.length ? text.length : i + size)));
      }
      expect([for (final o in out) (jsonDecode(o) as Map)['name']], ['Sol Ring', 'Island', 'Rhystic Study'], reason: 'pedaços de $size');
    }
  });

  test('busca sem internet: pelo nome primeiro, depois tipo e texto', () {
    final cards = [
      {'name': 'Sol Ring', 'type_line': 'Artifact', 'oracle_text': 'Add {C}{C}.'},
      {'name': 'Ring of Three Wishes', 'type_line': 'Artifact', 'oracle_text': 'wish'},
      {'name': 'Llanowar Elves', 'type_line': 'Creature — Elf Druid', 'oracle_text': 'Add {G}.'},
    ];
    expect([for (final c in OfflineCards.searchIn(cards, 'ring')) c['name']], ['Ring of Three Wishes', 'Sol Ring']);
    expect([for (final c in OfflineCards.searchIn(cards, 'elf druid')) c['name']], ['Llanowar Elves']);
  });
}
