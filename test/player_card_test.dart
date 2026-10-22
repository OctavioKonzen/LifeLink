import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/providers/game_provider.dart';
import 'package:magic/presentation/widgets/player_card_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('arrastar abre o veneno e o comandante e volta para a vida (rápido, devagar ou no botão)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = GameProvider();
    await tester.runAsync(() => game.ready);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: PlayerCardWidget(index: 0, quarterTurns: 0, game: game, onCounters: () {}, onSettings: () {}),
        ),
      ),
    ));
    final card = find.byType(PlayerCardWidget);

    await tester.fling(card, const Offset(200, 0), 1000); // rápido para a direita
    await tester.pumpAndSettle();
    expect(find.text('VENENO'), findsOneWidget);

    await tester.drag(card, const Offset(-80, 0)); // devagar, de volta
    await tester.pumpAndSettle();
    expect(find.text('VENENO'), findsNothing);
    expect(find.text('40'), findsOneWidget);

    await tester.drag(card, const Offset(-80, 0)); // esquerda: comandante
    await tester.pumpAndSettle();
    expect(find.text('COMANDANTE'), findsOneWidget);

    await tester.tap(find.text('Vida')); // botão de voltar
    await tester.pumpAndSettle();
    expect(find.text('COMANDANTE'), findsNothing);
    expect(find.text('40'), findsOneWidget);
    expect(game.lives[0], 40); // arrastar não mexeu na vida
  });
}
