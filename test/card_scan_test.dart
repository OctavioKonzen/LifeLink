import 'package:flutter_test/flutter_test.dart';
import 'package:magic/presentation/screens/search/card_scan_screen.dart';

({String text, double top, double left, double height}) line(String text, double top) => (text: text, top: top, left: 10, height: 20);

void main() {
  test('carta nova: nome em cima e coleção/número no canto de baixo', () {
    final r = readCard([
      line('Tigris, Feline Fury', 40),
      line('{2}{G}', 42),
      line('Legendary Creature — Cat', 400),
      line('Whenever you gain life, put a +1/+1 counter', 460),
      line('0123 R', 690),
      line('FDN • EN', 710),
    ]);
    expect(r.name, 'Tigris, Feline Fury');
    expect(r.set, 'fdn');
    expect(r.number, '123');
    expect(r.lang, 'en');
  });

  test('carta antiga em português: número com barra', () {
    final r = readCard([
      line('Raio', 30),
      line('Mágica Instantânea', 380),
      line('141/249 C', 700),
      line('M10 • PT Christopher Moeller', 715),
    ]);
    expect(r.name, 'Raio');
    expect(r.number, '141');
    expect(r.set, 'm10');
    expect(r.lang, 'pt');
  });

  test('sem nada legível', () {
    expect(readCard([line('1/1', 300)]).isEmpty, isTrue);
  });
}
