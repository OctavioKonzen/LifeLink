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

  test('exportar: comandante à parte, cópias juntas e nome em inglês', () {
    const id = '0000579f-7b35-4ed3-b44c-db2a538066fe';
    final cards = [
      {'name': 'Atraxa', 'commander': true},
      {'name': 'Anel Solar', 'id': id},
      {'name': 'Anel Solar', 'id': id},
      {'name': 'Island'},
    ];
    expect(DeckTools.exportList(cards, english: {id: 'Sol Ring'}), 'Commander\n1 Atraxa\n\nDeck\n1 Island\n2 Sol Ring');
    // A lista exportada volta igual pelo importar.
    final back = DeckTools.parse(DeckTools.exportList(cards, english: {id: 'Sol Ring'}));
    expect([for (final l in back) '${l.qty} ${l.name} ${l.commander}'], containsAll(['1 Atraxa true', '2 Sol Ring false', '1 Island false']));
  });

  test('bracket: game changers, turnos extras e destruição de terrenos', () {
    expect(DeckTools.bracket([{'name': 'Sol Ring', 'oracle_text': '{T}: Add {C}{C}.'}]).bracket, 2);
    final three = DeckTools.bracket([
      {'name': 'Rhystic Study', 'game_changer': true},
      {'name': 'Time Warp', 'oracle_text': 'Target player takes an extra turn after this one.'},
    ]);
    expect(three.bracket, 3);
    expect(three.gameChangers, ['Rhystic Study']);
    expect(three.extraTurns, ['Time Warp']);
    expect(DeckTools.bracket([{'name': 'Armageddon', 'oracle_text': 'Destroy all lands.'}]).bracket, 4);
    expect(DeckTools.bracket([for (var i = 0; i < 4; i++) {'name': 'GC $i', 'game_changer': true}]).bracket, 4);
  });

  test('EDHREC: nome da página e as cartas mais usadas primeiro', () {
    expect(DeckTools.edhrecSlug("Atraxa, Praetors' Voice"), 'atraxa-praetors-voice');
    expect(DeckTools.edhrecSlug('Esika, God of the Tree // The Prismatic Bridge'), 'esika-god-of-the-tree');
    final page = {
      'container': {
        'json_dict': {
          'cardlists': [
            {
              'cardviews': [
                {'name': 'Sol Ring', 'inclusion': 900, 'potential_decks': 1000, 'synergy': 0},
                {'name': 'Doubling Season', 'inclusion': 500, 'potential_decks': 1000, 'synergy': 0.6},
                {'name': 'Já Tenho', 'inclusion': 999, 'potential_decks': 1000},
                {'name': 'Forest', 'inclusion': 1000, 'potential_decks': 1000},
                {'name': 'Snow-Covered Island', 'num_decks': 1000, 'potential_decks': 1000},
              ],
            },
          ],
        },
      },
    };
    expect(DeckTools.edhrecNames(page, {'já tenho'}), ['Sol Ring', 'Doubling Season']);
  });
}
