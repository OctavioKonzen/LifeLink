import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/deck_tools.dart';

void main() {
  test('lê listas do Moxfield, Archidekt, Arena e MTGO', () {
    final lines = DeckTools.parse('''
Commander
1 Atraxa, Praetors' Voice (ONE) 196 *F*

Deck
1x Sol Ring (CMM) 410 [Ramp]
4 Lightning Bolt
Island
Creatures (2)
2 Llanowar Elves
// Sideboard
3 Duress
SB: 1 Negate
Maybeboard
1 Opt
''');
    expect(lines.map((l) => l.toString()), [
      "1 Atraxa, Praetors' Voice (one) 196",
      '1 Sol Ring (cmm) 410',
      '4 Lightning Bolt',
      '1 Island',
      '2 Llanowar Elves',
    ]);
    expect(lines.first.commander, isTrue);
    expect(lines[1].commander, isFalse);
  });

  Map<String, dynamic> card(String name, {String type = 'Creature', Map<String, String>? legal}) =>
      {'name': name, 'type_line': type, 'oracle_text': '', 'legalities': legal ?? {'commander': 'legal', 'modern': 'legal'}};

  test('legalidade: tamanho, cópias e banidas', () {
    final deck = [
      for (int i = 0; i < 98; i++) card('Carta $i'),
      card('Sol Ring', legal: {'commander': 'legal', 'modern': 'not_legal'}),
      card('Forest', type: 'Basic Land — Forest'),
    ];
    expect(DeckTools.problems('commander', deck), isEmpty);
    final withCopy = [...deck, card('Carta 1')];
    expect(DeckTools.problems('commander', withCopy).join('\n'), contains('2 cópias'));
    final modern = DeckTools.problems('modern', deck);
    expect(modern, contains('Sol Ring: não é legal'));
    expect(DeckTools.problems('modern', [for (int i = 0; i < 60; i++) card('Forest', type: 'Basic Land — Forest')]), isEmpty);
    expect(DeckTools.problems('modern', [for (int i = 0; i < 59; i++) card('X')]).first, contains('59 cartas'));
  });

  test('embaralhar mantém as mesmas cartas', () {
    final list = List.generate(60, (i) => i);
    final s = DeckTools.shuffled(list, Random(1));
    expect(s, isNot(list));
    expect([...s]..sort(), list);
  });
}
