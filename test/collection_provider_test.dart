import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/providers/collection_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CollectionProvider collection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    collection = CollectionProvider();
    await collection.ready;
  });

  const solRing = {'id': '0000579f-7b35-4ed3-b44c-db2a538066fe', 'name': 'Sol Ring', 'oracle_id': 'o-sol', 'setName': 'Commander', 'usdPrice': '1.50'};

  test('guardar, somar cópias, valor total e tirar', () {
    expect(collection.add(solRing), 1);
    expect(collection.add(solRing), 2);
    expect(collection.cards.length, 1);
    expect(collection.totalCards, 2);
    expect(collection.totalUsd, 3.0);
    collection.setQty(solRing['id']!, 0);
    expect(collection.cards, isEmpty);
  });

  test('o que falta para o deck: qualquer versão serve e básicos não contam', () {
    collection.add({...solRing, 'id': 'outra-versao'});
    final deck = [
      {'name': 'Sol Ring', 'oracle_id': 'o-sol', 'usdPrice': '2.00'},
      {'name': 'Sol Ring', 'oracle_id': 'o-sol', 'usdPrice': '2.00'},
      {'name': 'Forest', 'type_line': 'Basic Land — Forest'},
      {'name': 'Rhystic Study', 'oracle_id': 'o-rs', 'usdPrice': '30.00'},
    ];
    final missing = collection.missingFor(deck);
    expect([for (final m in missing) '${m.name} ${m.have}/${m.need}'], ['Rhystic Study 0/1', 'Sol Ring 1/2']);
  });

  test('lista de desejos guarda o preço de quando entrou e vai e volta pela conta', () async {
    collection.toggleWish(solRing);
    expect(collection.wished(solRing['id']!), isTrue);
    final sync = collection.wishes.first.toMap(wish: true);
    expect(sync['added'], 1.5);
    await Future<void>.delayed(const Duration(milliseconds: 20)); // gravou no aparelho
    final other = CollectionProvider();
    await other.ready; // o mesmo aparelho: carrega o que foi salvo
    expect(other.wished(solRing['id']!), isTrue);
    collection.toggleWish(solRing);
    expect(collection.wishes, isEmpty);
  });
}
