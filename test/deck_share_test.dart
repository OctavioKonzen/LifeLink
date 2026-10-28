import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/deck_share.dart';

void main() {
  test('vai e volta', () {
    const list = "Commander\n1 Atraxa, Praetors' Voice\n\nDeck\n1 Sol Ring\n35 Forest";
    final code = DeckShare.encode(name: 'Atraxa ção', type: 'Commander', list: list);
    expect(code, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    final d = DeckShare.decode(code)!;
    expect((d.name, d.type, d.list), ('Atraxa ção', 'Commander', list));
    expect(DeckShare.codeFromLink('Olha: ${DeckShare.link(code)}'), code);
  });

  test('o código que o site lê (web-site/src/lib/shareDeck.test.js)', () {
    final code = DeckShare.encode(name: 'Teste', type: 'Normal', list: '4 Lightning Bolt');
    expect(code, 'q1bKU7JSCkktLklV0lEqUbJS8ssvyk3MUdJRylGyUjJR8MlMzyjJy8xLV3DKzylRqgUA');
  });

  test('código inválido', () {
    expect(DeckShare.decode('nada disso'), isNull);
    expect(DeckShare.codeFromLink('1 Sol Ring'), isNull);
  });
}
