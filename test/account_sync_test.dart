import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/account/user_data.dart';
import 'package:magic/data/providers/deck_provider.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:magic/data/providers/theme_provider.dart';
import 'package:magic/data/providers/xp_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> changed;
  late List<String> deckEvents;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    changed = [];
    deckEvents = [];
    UserData.instance.onLocalChange = changed.add;
    UserData.instance.onDeckChange = (id, {deleted = false}) => deckEvents.add('$id${deleted ? ' apagado' : ''}');
  });

  test('mudança feita no app avisa a conta; a que vem da conta não volta', () async {
    final theme = ThemeProvider();
    await theme.ready;
    theme.setCardLanguage('en');
    await Future<void>.delayed(Duration.zero);
    expect(changed, contains('settings'));

    changed.clear();
    await UserData.instance.applyRemote({'settings': {'cardLanguage': 'pt', 'playerName': 'Ana'}});
    expect(theme.cardLanguage, 'pt');
    expect(theme.playerName, 'Ana');
    expect(changed, isEmpty);
  });

  test('perfil vindo da conta, com os campos que faltam no padrão', () async {
    final xp = XpProvider();
    await xp.ready;
    await xp.applySync({'xp': 950, 'level': 4, 'unlockedTitles': ['Deus do Magic']});
    expect(xp.level, 4);
    expect(xp.unlockedTitles, ['Deus do Magic']);
    expect(xp.unlockedBorders, ['0']);
    expect(xp.toSync()['xp'], 950);
  });

  test('partida vinda da conta (formato do site)', () async {
    final game = GameProvider();
    await game.ready;
    await game.applySync({
      'playerCount': 3,
      'startingLife': 20,
      'lives': [18, 20, 5, 20, 20, 20],
      'poison': [0, 2, 0, 0, 0, 0],
      'commanderDamage': [for (var i = 0; i < 6; i++) List.filled(6, 0)],
      'playerNames': ['A', 'B', 'C', 'D', 'E', 'F'],
    });
    expect(game.playerCount, 3);
    expect(game.lives[2], 5);
    expect(game.poison[1], 2);
    expect(game.playerNames.first, 'A');
    expect(game.toSync()['startingLife'], 20);
  });

  test('decks: cada mudança avisa qual deck; os da conta trocam os locais, menos os mudados aqui', () async {
    final decks = DeckProvider();
    await decks.ready;
    decks.importDeck('Local', 'Normal', []);
    final localId = decks.allDecks.single.id;
    decks.addCardToDeck(0, {'name': 'Sol Ring'});
    expect(deckEvents, [localId, localId]);

    await UserData.instance.applyRemoteDecks({
      '1': {'name': 'Do site', 'type': 'Commander', 'cards': [{'name': 'Lightning Bolt'}]},
    }, keep: {localId});
    expect(decks.allDecks.map((d) => d.name), ['Do site', 'Local']);
    expect(decks.allDecks.first.cards.single['name'], 'Lightning Bolt');
    expect(deckEvents.length, 2); // aplicar o que veio da conta não grava de volta

    decks.deleteDeck(1);
    expect(deckEvents.last, '$localId apagado');

    await UserData.instance.clearAll();
    expect(decks.allDecks, isEmpty);
  });
}
