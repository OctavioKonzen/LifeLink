import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameProvider game;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    game = GameProvider();
    await game.ready;
  });

  test('toques seguidos viram uma mudança só, e o desfazer volta tudo', () {
    for (int k = 0; k < 7; k++) {
      game.updateLife(0, -1);
    }
    expect(game.lives[0], 33);
    expect(game.history.length, 1);
    expect(game.history.last.delta, -7);
    game.undo();
    expect(game.lives[0], 40);
    expect(game.canUndo, isFalse);
  });

  test('contadores têm limite e o dano de comandante tira vida', () {
    game.updateCounter(Counter.poison, 1, 15);
    expect(game.counter(Counter.poison, 1), 10);
    expect(game.isDead(1), isTrue);
    game.updateCounter(Counter.energy, 0, -3);
    expect(game.counter(Counter.energy, 0), 0);

    game.updateCommanderDamage(0, 1, 5);
    expect(game.commanderDamage[0][1], 5);
    expect(game.lives[0], 35);
    game.undo();
    expect(game.commanderDamage[0][1], 0);
    expect(game.lives[0], 40);
  });

  test('vencedor é o único vivo', () {
    expect(game.winner, isNull);
    game.updateLife(1, -40);
    expect(game.winner, 0);
  });

  test('a partida vai para a conta com os contadores e as cores', () async {
    game.updateCounter(Counter.tax, 0, 2);
    game.setPlayerColor(1, 7);
    final data = game.toSync();
    final other = GameProvider();
    await other.ready;
    await other.applySync(data);
    expect(other.counter(Counter.tax, 0), 2);
    expect(other.colorIndexOf(1), 7);
  });

  test('vida inicial nova começa outra partida', () {
    game.updateLife(0, -10);
    game.setStartingLife(20);
    expect(game.lives[0], 20);
    expect(game.canUndo, isFalse);
  });

  test('avisa cada mudança e quando o jogador acaba de morrer (sons)', () {
    final heard = <String>[];
    game.onChange = (e, died) => heard.add('${e.kind}:${e.delta}${died ? ':morreu' : ''}');
    game.updateLife(0, -5);
    game.updateLife(0, 2);
    game.updateCounter(Counter.poison, 1, 9);
    game.updateCounter(Counter.poison, 1, 1); // 10 de veneno: morre
    game.updateCommanderDamage(0, 1, 3);
    game.updateLife(0, -40); // morre
    game.updateLife(0, -1); // já estava morto: não morre de novo
    expect(heard, ['life:-5', 'life:2', 'poison:9', 'poison:1:morreu', 'cmd:3', 'life:-40:morreu', 'life:-1']);
  });
}
