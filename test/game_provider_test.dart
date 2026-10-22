import 'package:flutter/material.dart';
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

  test('histórico de vida de cada jogador', () {
    game.updateLife(0, -3);
    game.updateCommanderDamage(0, 1, 5);
    game.updateLife(1, -2); // outro jogador não entra
    game.updateLife(0, 4);
    final t = game.lifeTimeline(0);
    expect(t.start, 40);
    expect([for (final c in t.changes) (c.delta, c.life, c.kind)], [(-3, 37, 'life'), (-5, 32, 'cmd'), (4, 36, 'life')]);
    expect(t.changes[1].attacker, 1);
  });

  test('mais cores: as 10 antigas na mesma ordem', () {
    expect(GameProvider.palette.length, 18);
    expect(GameProvider.palette[1], const Color(0xFF1BA655));
  });

  test('segunda cor (degradê) vai para a conta', () async {
    expect(game.secondColorOf(0), isNull);
    game.setSecondColor(0, 11);
    expect(game.secondColorOf(0), GameProvider.palette[11]);
    final other = GameProvider();
    await other.ready;
    await other.applySync(game.toSync());
    expect(other.secondColorIndexOf(0), 11);
    game.setSecondColor(0, -1);
    expect(game.secondColorOf(0), isNull);
  });

  test('turnos: sentido horário, pula quem morreu e a rodada avança', () {
    game.setPlayerCount(4);
    game.startTurns(2);
    expect(game.turnPlayer, 2);
    expect(game.turnRound, 1);
    game.nextTurn();
    expect(game.turnPlayer, 3);
    game.updateLife(0, -40); // o 0 morreu
    game.nextTurn();
    expect(game.turnPlayer, 1);
    expect(game.turnRound, 1);
    game.nextTurn();
    expect(game.turnPlayer, 2);
    expect(game.turnRound, 2);
    game.stopTurns();
    expect(game.countingTurns, isFalse);
  });

  test('monarca, iniciativa e contadores novos vão para a conta e somem na partida nova', () async {
    game.setMonarch(1);
    game.setInitiative(0);
    game.updateCounter(Counter.treasure, 0, 3);
    game.updateCounter(Counter.blessing, 1, 5);
    expect(game.counter(Counter.blessing, 1), 1);
    game.setPlane({'id': 'x', 'name': 'Plano'});
    final other = GameProvider();
    await other.ready;
    await other.applySync(game.toSync());
    expect(other.monarch, 1);
    expect(other.initiative, 0);
    expect(other.counter(Counter.treasure, 0), 3);
    expect(other.plane?['name'], 'Plano');
    game.setMonarch(1);
    expect(game.monarch, -1);
    game.resetGame();
    expect(game.initiative, -1);
    expect(game.counter(Counter.treasure, 0), 0);
    expect(game.plane, isNull);
  });

  test('dano de comandante: cada comandante conta à parte (e o parceiro também)', () async {
    game.setPlayerCount(4);
    game.updateLife(0, 100); // para a vida não acabar antes
    const p = GameProvider.maxPlayers;
    game.updateCommanderDamage(0, 1, 20);
    game.updateCommanderDamage(0, 2, 20);
    game.setPartner(3, true);
    game.updateCommanderDamage(0, 3, 15);
    game.updateCommanderDamage(0, 3 + p, 15);
    // 70 no total, mas nenhum comandante chegou a 21.
    expect(game.isDead(0), isFalse);
    expect(game.maxCmdDamage(0), 20);
    expect(game.cmdDamage(0, 3 + p), 15);
    expect(game.commanderName(3 + p), '${game.playerNames[3]} (2º)');
    game.updateCommanderDamage(0, 3 + p, 6);
    expect(game.isDead(0), isTrue);
    game.undo(); // os toques seguidos no mesmo comandante viraram um só (15 + 6)
    expect(game.cmdDamage(0, 3 + p), 0);
    expect(game.isDead(0), isFalse);
    game.updateCommanderDamage(0, 3 + p, 15);

    // Vai e volta pela conta.
    final other = GameProvider();
    await other.ready;
    await other.applySync(game.toSync());
    expect(other.hasPartner(3), isTrue);
    expect(other.cmdDamage(0, 3 + p), 15);
    expect(other.commanderDamage[0][1], 20);
  });
}
