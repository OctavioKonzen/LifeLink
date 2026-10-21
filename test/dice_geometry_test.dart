import 'package:flutter_test/flutter_test.dart';
import 'package:magic/presentation/widgets/dice/dice_geometry.dart';

void main() {
  const sides = {DieKind.d4: 4, DieKind.d6: 6, DieKind.d8: 8, DieKind.d10: 10, DieKind.d12: 12, DieKind.d20: 20, DieKind.d100: 10};

  for (final kind in DieKind.values) {
    group(kind.name, () {
      final die = DieShape.of(kind);

      test('tem ${sides[kind]} faces planas, viradas para fora', () {
        expect(die.sides, sides[kind]);
        for (final f in die.faces) {
          expect(f.normal.dot(f.center), greaterThan(0));
          for (final c in f.corners) {
            expect((die.vertices[c] - f.center).dot(f.normal).abs(), lessThan(1e-6), reason: 'face ${f.label} não é plana');
          }
        }
      });

      test('números sem repetir', () {
        final values = die.faces.map((f) => f.value).toSet();
        expect(values.length, die.sides);
        final expected = switch (kind) {
          DieKind.d10 => {for (int i = 0; i < 10; i++) i},
          DieKind.d100 => {for (int i = 0; i < 10; i++) i * 10},
          _ => {for (int i = 1; i <= die.sides; i++) i},
        };
        expect(values, expected);
      });

      if (kind != DieKind.d4) {
        test('faces opostas somam o mesmo valor', () {
          final sums = <int>{};
          for (final f in die.faces) {
            final opposite = die.faces.firstWhere((g) => (g.normal + f.normal).length < 1e-4);
            sums.add(f.value + opposite.value);
          }
          expect(sums.length, 1, reason: 'somas: $sums');
        });
      }

      test('a face sorteada para virada para quem olha, com o número de pé', () {
        for (final f in die.faces) {
          final r = die.restingOn(f.value, tiltX: 0, tiltY: 0);
          final n = r.apply(f.normal), up = r.apply(f.up);
          expect(n.z, closeTo(1, 1e-9));
          expect(up.y, closeTo(1, 1e-9));
        }
      });
    });
  }

  test('quatérnio: ida e volta da matriz', () {
    final m = DieShape.of(DieKind.d20).restingOn(7);
    final back = Quat.fromMatrix(m).toMatrix();
    for (final p in DieShape.of(DieKind.d20).vertices) {
      expect((m.apply(p) - back.apply(p)).length, lessThan(1e-9));
    }
  });
}
