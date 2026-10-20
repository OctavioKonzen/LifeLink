import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/scryfall_service.dart';

void main() {
  group('buildTextQuery', () {
    test('procura no nome e no texto da carta', () {
      expect(ScryfallService.buildTextQuery('lightning bolt'), '((lightning bolt) or (o:lightning o:bolt))');
    });

    test('vazio continua vazio', () {
      expect(ScryfallService.buildTextQuery('   '), '');
    });

    test('a sintaxe do Scryfall é usada como está', () {
      expect(ScryfallService.buildTextQuery('t:dragon c:r'), 't:dragon c:r');
      expect(ScryfallService.buildTextQuery('!"Sol Ring"'), '!"Sol Ring"');
      expect(ScryfallService.buildTextQuery('elf or goblin'), 'elf or goblin');
    });

    test('palavras com acento e apóstrofo', () {
      expect(ScryfallService.buildTextQuery('dragão'), '((dragão) or (o:dragão))');
      expect(ScryfallService.buildTextQuery("urza's"), '''((urza's) or (o:"urza's"))''');
    });
  });

  group('CardImages.sized', () {
    const normal = 'https://cards.scryfall.io/normal/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.jpg?1562404626';

    test('troca o tamanho mantendo o resto do endereço', () {
      expect(CardImages.sized(normal, 'large'), 'https://cards.scryfall.io/large/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.jpg?1562404626');
      expect(CardImages.thumb(normal), 'https://cards.scryfall.io/small/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.jpg?1562404626');
    });

    test('png usa a extensão .png', () {
      expect(CardImages.best(normal), 'https://cards.scryfall.io/png/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.png?1562404626');
      expect(CardImages.sized(CardImages.best(normal), 'normal'), normal);
    });

    test('endereços de fora do Scryfall não mudam', () {
      expect(CardImages.best(CardImages.cardBack), CardImages.cardBack);
      expect(CardImages.sized('', 'large'), '');
    });

    test('pega a frente das cartas de duas faces', () {
      expect(CardImages.normalOf({'image_uris': {'normal': 'a'}}), 'a');
      expect(CardImages.normalOf({'card_faces': [{'image_uris': {'normal': 'b'}}, {}]}), 'b');
      expect(CardImages.normalOf({}), isNull);
    });
  });

  group('errorFor', () {
    test('mensagens compreensíveis', () {
      expect(ScryfallService.errorFor(404, {}).notFound, isTrue);
      expect(ScryfallService.errorFor(404, {}).message, 'Nenhuma carta encontrada.');
      expect(ScryfallService.errorFor(429, {}).message, contains('Espere'));
      expect(ScryfallService.errorFor(400, {'details': 'Unknown keyword'}).message, contains('Unknown keyword'));
      expect(ScryfallService.errorFor(503, {}).message, contains('503'));
    });
  });
}
