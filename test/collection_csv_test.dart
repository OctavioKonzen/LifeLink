import 'package:flutter_test/flutter_test.dart';
import 'package:magic/data/services/collection_csv.dart';
import 'package:magic/data/services/deck_tools.dart';

// Os mesmos casos do site (web-site/src/lib/collectionCsv.test.js).
List<String> lines(List<DeckLine> l) => [for (final x in l) '${x.qty}|${x.name}|${x.set}|${x.number}'];

void main() {
  test('CSV do Moxfield', () {
    const csv = '"Count","Tradelist Count","Name","Edition","Condition","Language","Foil","Tags","Last Modified","Collector Number","Alter","Proxy","Purchase Price"\n'
        '"2","0","Sol Ring","cmm","Near Mint","English","","","2025-01-01","410","False","False",""\n'
        '"1","0","Brazen Borrower // Petty Theft","eld","Near Mint","English","foil","","","39","False","False",""';
    expect(lines(CollectionCsv.parse(csv)), ['2|Sol Ring|cmm|410', '1|Brazen Borrower // Petty Theft|eld|39']);
  });

  test('CSV do ManaBox', () {
    const csv = 'Name,Set code,Set name,Collector number,Foil,Rarity,Quantity,ManaBox ID,Scryfall ID\nLightning Bolt,2X2,Double Masters 2022,117,normal,uncommon,4,1,abc\n"Atraxa, Praetors\' Voice",2XM,Double Masters,190,foil,mythic,1,2,def';
    expect(lines(CollectionCsv.parse(csv)), ['4|Lightning Bolt|2x2|117', "1|Atraxa, Praetors' Voice|2xm|190"]);
  });

  test('CSV do Deckbox (o nome da coleção não vale como código)', () {
    expect(lines(CollectionCsv.parse('Count,Tradelist Count,Name,Edition,Card Number,Condition\n3,0,Counterspell,Masters 25,46,Near Mint')), ['3|Counterspell|null|46']);
  });

  test('ponto e vírgula e aspas', () {
    expect(CollectionCsv.parseCsv('Quantidade;Nome\n2;"Raio; o ""clássico"""'), [
      ['Quantidade', 'Nome'],
      ['2', 'Raio; o "clássico"'],
    ]);
    expect(lines(CollectionCsv.parse('Quantidade;Nome\n2;Raio')), ['2|Raio|null|null']);
  });

  test('lista de texto', () {
    expect(lines(CollectionCsv.parse('1 Sol Ring (CMM) 410\n4x Lightning Bolt')), ['1|Sol Ring|cmm|410', '4|Lightning Bolt|null|null']);
  });

  test('exportar: CSV do Moxfield (e lê de volta) e lista', () {
    final rows = <CollectionRow>[
      (qty: 2, trade: true, name: 'Sol Ring', set: 'cmm', number: '410'),
      (qty: 1, trade: false, name: 'Say "hi"', set: '', number: ''),
    ];
    final csv = CollectionCsv.csv(rows);
    expect(csv.split('\n')[1], '"2","2","Sol Ring","cmm","Near Mint","English","","","","410","False","False",""');
    expect(lines(CollectionCsv.parse(csv)), ['2|Sol Ring|cmm|410', '1|Say "hi"|null|null']);
    expect(CollectionCsv.list(rows), '2 Sol Ring (CMM) 410\n1 Say "hi"');
  });
}
