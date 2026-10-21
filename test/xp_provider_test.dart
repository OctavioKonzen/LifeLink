import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/providers/xp_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('desfazer a vitória tira o XP e a partida', () async {
    final xp = XpProvider();
    await xp.ready;
    xp.addXp(80);
    xp.incrementMatches();
    expect(xp.totalMatchesPlayed, 1);
    expect(xp.level, 2); // 130 XP
    xp.undoMatch();
    expect(xp.totalMatchesPlayed, 0);
    expect(xp.xp, 80);
    expect(xp.level, 1);
  });

  test('cada seção de missões conta só o que foi feito nela', () async {
    final xp = XpProvider();
    await xp.ready;
    for (var k = 0; k < 7; k++) {
      xp.incrementSearches();
    }
    expect(xp.sinceTierStart('searches'), 7);
    xp.advanceTier();
    expect(xp.sinceTierStart('searches'), 0);
    xp.incrementSearches();
    expect(xp.sinceTierStart('searches'), 1);
    expect(xp.claimedMissions.length, 5);
    xp.claimMission(9); // fora da lista: não quebra
  });
}
