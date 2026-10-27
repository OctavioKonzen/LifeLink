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

  test('palavras do texto de regras não viram coleção', () {
    final r = readCard([
      line('Mestra do Saber da Academia', 30),
      line('No início da etapa de compra de cada', 400),
      line('jogador, aquele jogador pode comprar', 430),
    ]);
    expect(r.name, 'Mestra do Saber da Academia');
    expect(r.set, isNull);
    expect(r.lang, isNull);
  });

  test('canto de baixo lido com o separador trocado e sem a raridade', () {
    final r = readCard([
      line('Sol Ring', 30),
      line('Artifact', 400),
      line('0410', 690),
      line('CMM « EN Mike Bierek', 712),
    ]);
    expect(r.set, 'cmm');
    expect(r.number, '410');
    expect(r.lang, 'en');
  });

  test('nome da busca igual ao lido, com erro de leitura', () {
    expect(nameMatches('Lightnirg Bolt', 'Lightning Bolt'), isTrue);
    expect(nameMatches('Elfos de Llanowar', 'Elfos de Llanowar'), isTrue);
    expect(nameMatches('Choque', 'Choque Elétrico Duplo'), isFalse);
    expect(nameMatches('Shock', 'Shockwave'), isFalse);
  });

  test('só o texto dentro da moldura conta', () {
    // Foto 1000 × 1800: a moldura vai de ~355 a ~1445 na altura.
    final lines = [
      (text: 'Outra Carta Na Mesa', top: 120.0, left: 300.0, height: 30.0),
      (text: 'Sol Ring', top: 400.0, left: 140.0, height: 30.0),
      (text: 'CMM • EN', top: 1400.0, left: 140.0, height: 20.0),
    ];
    final r = readCard(inFrame(lines, 1000, 1800));
    expect(r.name, 'Sol Ring');
    expect(r.set, 'cmm');
  });
}
