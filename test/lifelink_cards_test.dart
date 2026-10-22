import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magic/data/services/lifelink_cards.dart';

void main() {
  const oracle = '6ad8011d-3471-4369-9d68-b264cc027487';
  const en = '8ee443cc-e17a-493b-9c93-1f9e141a30e4';
  const pt = 'be683141-ac97-4990-9ceb-c721c29335f8';
  final files = {
    'c/$oracle.json': {
      'id': en, 'o': oracle, 'n': 'Sol Ring', 't': 'Artifact', 'x': '{T}: Add {C}{C}.', 'm': '{1}', 'cmc': 1.0,
      'lg': {'commander': 'l', 'vintage': 'r'}, 'gc': 1, 'pn': 'Anel Solar', 'pt': 'Artefato', 'px': '{T}: Adicione {C}{C}.',
      'v': [
        {'id': en, 's': 'cmm', 'cn': '410', 'r': 'uncommon', 'l': 'en', 'a': 'Mike Bierek', 'i': 1},
        {'id': pt, 's': 'cmm', 'cn': '410', 'r': 'uncommon', 'l': 'pt', 'pn': 'Anel Solar'},
      ],
    },
    'pr/6a.json': {oracle: {en: {'usd': '1.50', 'eur': '1.10'}}},
    'id/8ee.json': {en: oracle},
    'id/be6.json': {pt: oracle},
    'set/cmm.json': {'410|en': en, '410|pt': pt},
    'sets.json': {'cmm': 'Commander Masters'},
    'data/config.json': {'search': 'https://busca.test'},
  };
  final asked = <String>[];

  setUp(() {
    asked.clear();
    LifeLinkCards.instance.client = MockClient((req) async {
      asked.add(req.url.toString());
      if (req.url.host == 'busca.test') {
        expect(req.url.queryParameters['q'], 'anel');
        return http.Response(jsonEncode({'cards': [{'o': oracle, 'id': en, 'n': 'Sol Ring', 'pn': 'Anel Solar', 't': 'Artifact', 'pt': 'Artefato', 'img': 1, 'usd': 1.5}], 'hasMore': false}), 200);
      }
      final path = req.url.path.substring(1);
      final body = files[path];
      return body == null ? http.Response('', 404) : http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
  });

  test('carta pelo código: português, preço do dia e imagem do R2', () async {
    final card = await LifeLinkCards.instance.appCard(en);
    expect(card!['name'], 'Anel Solar');
    expect(card['enName'], 'Sol Ring');
    expect(card['oracle_text'], '{T}: Adicione {C}{C}.');
    expect(card['usdPrice'], '1.50');
    expect(card['setName'], 'Commander Masters');
    expect(card['imageUrl'], '${LifeLinkCards.r2}/img/$en.jpg');
    // A versão em português ainda sem imagem no R2: vem do servidor de imagens.
    final ptCard = await LifeLinkCards.instance.appCard(pt);
    expect(ptCard!['imageUrl'], 'https://cards.scryfall.io/normal/front/b/e/$pt.jpg');
    expect(await LifeLinkCards.instance.appCard('000-nao-existe'), isNull);
  });

  test('ficha (legalidade, artista, game changer), versões e câmera', () async {
    final c = (await LifeLinkCards.instance.card(oracle))!;
    final d = LifeLinkCards.details(c, LifeLinkCards.variationFor(c, lang: 'en'));
    expect(d['legalities'], {'commander': 'legal', 'vintage': 'restricted'});
    expect(d['artist'], 'Mike Bierek');
    expect(d['game_changer'], isTrue);
    expect((await LifeLinkCards.instance.versions(oracle, lang: 'pt')).map((v) => v['id']), [pt]);
    expect(await LifeLinkCards.instance.printBySetNumber('CMM', '410', lang: 'pt'), pt);
  });

  test('busca no Worker', () async {
    final r = await LifeLinkCards.instance.search(text: 'anel');
    expect(r.cards.single['name'], 'Anel Solar');
    expect(r.cards.single['usdPrice'], '1.50');
    expect(asked.where((u) => u.contains('config.json')).length, lessThanOrEqualTo(1));
  });
}
