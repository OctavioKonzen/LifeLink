import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/account/online.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a mesa guarda cada jogador separado e só manda o que mudou', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameProvider();
    await game.ready;
    final before = flattenGame(game.toSync());
    expect(before['p0.lives'], 40);
    expect(before['g.playerCount'], 2);

    game.updateLife(1, -3);
    game.updateCommanderDamage(0, 1, 2);
    final changes = changedFields(before, flattenGame(game.toSync()));
    expect(changes.keys.toSet(), {'p1.lives', 'p0.lives', 'p0.cmdRows'});

    // O documento da mesa volta a ser a mesma partida em outro celular.
    final doc = nestFields(flattenGame(game.toSync()));
    final other = GameProvider();
    await other.ready;
    await other.applySync(unflattenGame(doc));
    expect(other.lives.take(2), [38, 37]);
    expect(other.commanderDamage[0][1], 2);
  });

  test('código da mesa: 6 letras e números fáceis de ler', () {
    final code = newTableCode(Random(3));
    expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
  });
}
