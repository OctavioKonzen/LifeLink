import 'package:flutter_test/flutter_test.dart';
import 'package:magic/presentation/screens/search/card_filters_sheet.dart';

void main() {
  test('sem filtros a busca fica vazia', () {
    expect(const CardFilters().toQuery(), '');
    expect(const CardFilters().isEmpty, isTrue);
  });

  test('tipos entre si com "ou"; raça, subtipo, cores e coleção com "e"', () {
    const f = CardFilters(
      types: {'Creature', 'Artifact'},
      race: 'Elf',
      subtype: 'Equipment',
      colors: {'G', 'W'},
      setCode: 'tle',
      setName: 'Avatar',
    );
    expect(f.toQuery(), '(t:"Creature" or t:"Artifact") t:"Elf" t:"Equipment" id<=WG set:tle');
    expect(f.count, 7);
  });

  test('um tipo só não ganha parênteses', () {
    expect(const CardFilters(types: {'Instant'}).toQuery(), 't:"Instant"');
  });
}
