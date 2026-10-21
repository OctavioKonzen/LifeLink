import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:magic/data/providers/match_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O Firestore não aceita lista dentro de lista: nada do que vai para a conta pode ter.
bool hasNestedList(Object? v, {bool inList = false}) {
  if (v is List) return inList || v.any((x) => hasNestedList(x, inList: true));
  if (v is Map) return v.values.any((x) => hasNestedList(x));
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a partida terminada guarda jogadores, deck, vencedor e a vida ao longo do jogo', () async {
    final game = GameProvider();
    await game.ready;
    game.setDeck(0, ' Atraxa ');
    game.updateLife(1, -10);
    game.updateCommanderDamage(1, 0, 21);
    expect(game.winner, 0);
    final m = MatchRecord.fromGame(game);
    expect(m.winner, 0);
    expect(m.winnerName, 'Jogador 1');
    expect(m.deckOf(0), 'Atraxa');
    expect(m.timelines[1], [40, 30, 9]);
    final back = MatchRecord.fromMap(m.toMap());
    expect(back.timelines[1], [40, 30, 9]);
    expect(back.players[0]['deck'], 'Atraxa');
  });

  test('nada que vai para a conta tem lista dentro de lista', () async {
    final game = GameProvider();
    await game.ready;
    game.updateCommanderDamage(0, 1, 4);
    final sync = game.toSync();
    expect(hasNestedList(sync), isFalse);
    final other = GameProvider();
    await other.ready;
    await other.applySync(sync);
    expect(other.commanderDamage[0][1], 4);

    final matches = MatchProvider();
    await matches.ready;
    matches.add(MatchRecord.fromGame(game));
    expect(hasNestedList(matches.toSync()), isFalse);
  });

  test('estatísticas por jogador e por deck', () async {
    MatchRecord match(int winner, List<(String, String)> players) => MatchRecord(
          id: '$winner${players.length}',
          at: 0,
          durationMs: 30 * 60000,
          startingLife: 40,
          rounds: 8,
          winner: winner,
          players: [for (final p in players) {'name': p.$1, 'deck': p.$2}],
          timelines: const [],
        );
    final list = [
      match(0, [('Ana', 'Atraxa'), ('Bia', 'Krenko')]),
      match(1, [('ana', 'Atraxa'), ('Bia', '')]),
      match(0, [('Ana', 'Atraxa'), ('Caio', 'Krenko')]),
    ];
    final players = MatchProvider.stats(list);
    expect(players.first.name, 'Ana');
    expect((players.first.wins, players.first.played), (2, 3));
    final decks = MatchProvider.stats(list, byDeck: true);
    expect([for (final d in decks) (d.name, d.wins, d.played)], [('Atraxa', 2, 3), ('Krenko', 0, 2)]);
    expect(MatchProvider.averageDuration(list), const Duration(minutes: 30));
    expect(MatchProvider.longest(list), 8);
  });
}
