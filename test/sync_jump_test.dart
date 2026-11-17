import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/account/user_data.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// O bug do vídeo: a vida mudava sozinha no contador, pulando entre duas
// partidas, porque o que chegava da conta (por qualquer mudança: XP,
// coleção...) trazia de volta a partida guardada nela.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> changed;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    changed = [];
    UserData.instance.onLocalChange = changed.add;
  });

  /// O que o AccountSync faz quando chega algo da conta.
  Future<void> receive(RemoteSeen seen, Map<String, dynamic> data, {Set<String> dirty = const {}}) =>
      UserData.instance.applyRemote(data, except: {...dirty, ...seen.unchanged(data)});

  test('uma parte igual à que a conta já tinha não é aplicada de novo', () {
    final seen = RemoteSeen();
    expect(seen.unchanged({'game': {'lives': [40, 40]}, 'profile': {'xp': 10}}), isEmpty);
    // Mudou só o XP: a partida é a mesma de antes.
    expect(seen.unchanged({'game': {'lives': [40, 40]}, 'profile': {'xp': 60}}), {'game'});
    // Outro aparelho mudou a vida: aplica.
    expect(seen.unchanged({'game': {'lives': [35, 40]}, 'profile': {'xp': 60}}), {'profile'});
  });

  test('a ordem dos campos não importa', () {
    final seen = RemoteSeen();
    seen.unchanged({'game': {'playerCount': 2, 'lives': [40, 31]}});
    expect(seen.unchanged({'game': {'lives': [40, 31], 'playerCount': 2}}), {'game'});
  });

  test('o que este aparelho gravou não volta quando a conta confirma', () {
    final seen = RemoteSeen();
    seen.unchanged({'game': {'lives': [40, 40]}});
    seen.wrote({'game': {'lives': [30, 40]}});
    expect(seen.unchanged({'game': {'lives': [30, 40]}}), {'game'});
  });

  test('o vídeo: a partida guardada na conta não volta por cima da atual', () async {
    final game = GameProvider();
    await game.ready;
    final seen = RemoteSeen();

    // A conta tem a partida A (75 e 31).
    await game.applySync({'playerCount': 2, 'lives': [75, 31]});
    final accountGame = Map<String, dynamic>.from(game.toSync());
    await receive(seen, {'game': accountGame, 'profile': {'xp': 10}});

    // A mesa online (ou outro caminho) muda a partida aqui para B (21 e 40),
    // sem passar pela conta.
    await game.applySync({'playerCount': 2, 'lives': [21, 40]}, keepHistory: true);

    // Chega uma mudança de XP da conta, com a partida A ainda lá.
    await receive(seen, {'game': accountGame, 'profile': {'xp': 60}});

    // Antes da correção, a vida voltava para 75 e 31.
    expect(game.lives.take(2), [21, 40]);
  });

  test('o toque avisa a conta na hora (não espera 350 ms)', () async {
    final game = GameProvider();
    await game.ready;
    changed.clear();
    game.updateLife(0, -3);
    expect(changed, contains('game'));
  });

  test('outro aparelho mudou a vida de verdade: chega', () async {
    final game = GameProvider();
    await game.ready;
    final seen = RemoteSeen();
    await game.applySync({'playerCount': 2, 'lives': [40, 40]});
    await receive(seen, {'game': game.toSync()});
    final other = Map<String, dynamic>.from(game.toSync())..['lives'] = [33, 40];
    await receive(seen, {'game': other});
    expect(game.lives.take(2), [33, 40]);
  });
}
