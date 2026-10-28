import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/rules_service.dart';

// O mesmo exemplo do site (web-site/src/lib/rules.test.js).
final data = RulesData.fromJson({
  'sections': {'702': 'Keyword Abilities', '704': 'State-Based Actions'},
  'rules': [
    ['702.2', 'Deathtouch'],
    ['702.2b', 'A creature with toughness greater than 0 that has been dealt damage by a source with deathtouch is destroyed.'],
    ['702.19', 'Trample'],
    ['702.19a', "Trample is a static ability that modifies the rules for assigning an attacking creature's combat damage."],
    ['702.19c', 'If an attacking creature with trample or trample over planeswalkers is blocked by a creature with deathtouch, it assigns lethal damage.'],
    ['704.5c', 'If a player has ten or more poison counters, that player loses the game.'],
  ],
  'glossary': [
    ['Trample', 'A keyword ability that modifies how a creature assigns combat damage. See rule 702.19.'],
    ['Poison Counter', 'A counter that may be given to a player. See rule 122.1f.'],
  ],
  'pt': {'atropelar': 'trample', 'toque mortífero': 'deathtouch', 'veneno': 'poison counter', 'perde': 'loses the game'},
  'stop': ['com', 'que', 'uma', 'quantos', 'the'],
});

void main() {
  test('português vira os termos das regras', () {
    expect(RulesData.norm('Toque Mortífero'), 'toque mortifero');
    expect(data.termsOf('atropelar com toque mortífero').map((t) => t.term), ['deathtouch', 'trample']);
  });

  test('acha a regra que junta os dois termos primeiro', () {
    final r = data.search('atropelar com toque mortífero');
    expect(r.rules.first.id, '702.19c');
    expect(r.glossary.first.id, 'Trample');
  });

  test('veneno', () {
    final r = data.search('quantos veneno perde');
    expect(r.rules.first.id, '704.5c');
    expect(r.glossary.first.id, 'Poison Counter');
  });

  test('número da regra', () {
    expect(data.search('702.19').rules.map((r) => r.id), ['702.19', '702.19a', '702.19c']);
    expect(data.family('702.19a').length, 3);
    expect(data.sectionOf('702.19a'), 'Keyword Abilities');
  });

  test('sem nada para buscar', () {
    expect(data.search('com que').rules, isEmpty);
  });
}
