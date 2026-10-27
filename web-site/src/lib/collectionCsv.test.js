import { describe, expect, test } from 'vitest'
import { collectionCsv, collectionList, parseCollection, parseCsv } from './collectionCsv'

describe('importar a coleção', () => {
  test('CSV do Moxfield', () => {
    const csv = [
      '"Count","Tradelist Count","Name","Edition","Condition","Language","Foil","Tags","Last Modified","Collector Number","Alter","Proxy","Purchase Price"',
      '"2","0","Sol Ring","cmm","Near Mint","English","","","2025-01-01","410","False","False",""',
      '"1","0","Brazen Borrower // Petty Theft","eld","Near Mint","English","foil","","","39","False","False",""',
    ].join('\n')
    expect(parseCollection(csv)).toEqual([
      { qty: 2, name: 'Sol Ring', set: 'cmm', number: '410' },
      { qty: 1, name: 'Brazen Borrower // Petty Theft', set: 'eld', number: '39' },
    ])
  })

  test('CSV do ManaBox', () => {
    const csv = 'Name,Set code,Set name,Collector number,Foil,Rarity,Quantity,ManaBox ID,Scryfall ID\nLightning Bolt,2X2,Double Masters 2022,117,normal,uncommon,4,1,abc\n"Atraxa, Praetors\' Voice",2XM,Double Masters,190,foil,mythic,1,2,def'
    expect(parseCollection(csv)).toEqual([
      { qty: 4, name: 'Lightning Bolt', set: '2x2', number: '117' },
      { qty: 1, name: "Atraxa, Praetors' Voice", set: '2xm', number: '190' },
    ])
  })

  test('CSV do Deckbox (o nome da coleção não vale como código)', () => {
    const csv = 'Count,Tradelist Count,Name,Edition,Card Number,Condition\n3,0,Counterspell,Masters 25,46,Near Mint'
    expect(parseCollection(csv)).toEqual([{ qty: 3, name: 'Counterspell', set: null, number: '46' }])
  })

  test('ponto e vírgula e aspas', () => {
    expect(parseCsv('Quantidade;Nome\n2;"Raio; o ""clássico"""')).toEqual([['Quantidade', 'Nome'], ['2', 'Raio; o "clássico"']])
    expect(parseCollection('Quantidade;Nome\n2;Raio')).toEqual([{ qty: 2, name: 'Raio', set: null, number: null }])
  })

  test('lista de texto', () => {
    expect(parseCollection('1 Sol Ring (CMM) 410\n4x Lightning Bolt')).toEqual([
      { qty: 1, name: 'Sol Ring', set: 'cmm', number: '410' },
      { qty: 4, name: 'Lightning Bolt', set: null, number: null },
    ])
  })
})

describe('exportar a coleção', () => {
  const rows = [
    { qty: 2, trade: true, name: 'Sol Ring', set: 'cmm', number: '410' },
    { qty: 1, trade: false, name: 'Say "hi"', set: '', number: '' },
  ]

  test('CSV do Moxfield (e lê de volta)', () => {
    const csv = collectionCsv(rows)
    expect(csv.split('\n')[1]).toBe('"2","2","Sol Ring","cmm","Near Mint","English","","","","410","False","False",""')
    expect(parseCollection(csv)).toEqual([
      { qty: 2, name: 'Sol Ring', set: 'cmm', number: '410' },
      { qty: 1, name: 'Say "hi"', set: null, number: null },
    ])
  })

  test('lista de texto', () => {
    expect(collectionList(rows)).toBe('2 Sol Ring (CMM) 410\n1 Say "hi"')
  })
})
