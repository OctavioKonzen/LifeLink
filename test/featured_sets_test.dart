import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/scryfall_service.dart';

Map<String, dynamic> set(String code, String date, {String type = 'expansion', bool digital = false, int cards = 100}) => {
      'code': code,
      'name': code.toUpperCase(),
      'released_at': date,
      'set_type': type,
      'digital': digital,
      'card_count': cards,
      'scryfall_uri': 'https://scryfall.com/sets/$code',
    };

void main() {
  final today = DateTime(2026, 10, 21);

  test('anúncios: só coleções principais, da mais nova para a mais antiga', () {
    final picked = ScryfallService.pickFeaturedSets([
      set('old', '2025-01-10'),
      set('new', '2026-09-26'),
      set('soon', '2026-11-14'),
      set('cmd', '2026-11-14', type: 'commander'),
      set('alc', '2026-10-01', digital: true),
      set('far', '2027-08-01'),
      set('empty', '2026-12-05', cards: 0),
    ], max: 3, today: today);
    expect(picked.map((s) => s['code']), ['soon', 'new', 'old']);
    expect(picked.first['scryfall_uri'], 'https://scryfall.com/sets/soon');
  });
}
