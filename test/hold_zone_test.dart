import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/sound_service.dart';
import 'package:magic/presentation/widgets/player_card_widget.dart';

// O bug: segurar o − ou o + e o quadro trocar de página (o botão sai da
// tela) deixava a vida mudando sozinha e os sons presos.
void main() {
  testWidgets('segurar muda de 1 em 1 e para ao soltar', (tester) async {
    var steps = 0;
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 200, height: 200, child: HoldZone(onStep: () => steps++, child: const SizedBox.expand()))));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldZone)));
    await tester.pump(const Duration(milliseconds: 600)); // vira "segurar"
    await tester.pump(const Duration(milliseconds: 1000));
    final whileHolding = steps;
    expect(whileHolding, greaterThan(1));
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));
    expect(steps, whileHolding);
    expect(SoundService.instance.holding, isFalse);
  });

  testWidgets('o botão sai da tela segurado: para de mudar e solta o som', (tester) async {
    var steps = 0;
    final show = ValueNotifier(true);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, on, _) => SizedBox(width: 200, height: 200, child: on ? HoldZone(onStep: () => steps++, child: const SizedBox.expand()) : const SizedBox.expand()),
      ),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldZone)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(SoundService.instance.holding, isTrue);
    show.value = false; // o quadro trocou de página
    await tester.pump();
    final atRemoval = steps;
    await tester.pump(const Duration(seconds: 5));
    expect(steps, atRemoval);
    expect(SoundService.instance.holding, isFalse);
    await gesture.up();
  });
}
