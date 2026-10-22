import { describe, expect, test } from 'vitest'
import { foldersOf, missingFor, publicTrade, qtyOf, savedOf, totalEur, totalUsd, tradeMatches } from './collection'

describe('coleção', () => {
  test('carta guardada no mesmo formato do app', () => {
    const saved = savedOf({ id: '0000579f-7b35-4ed3-b44c-db2a538066fe', name: 'Sol Ring', setName: 'Commander', usdPrice: '1.50', oracle_id: 'o-sol' })
    expect(saved).toMatchObject({ id: '0000579f-7b35-4ed3-b44c-db2a538066fe', name: 'Sol Ring', set: 'Commander', usd: 1.5, oracle_id: 'o-sol' })
  })

  test('valor total e quantidade', () => {
    const collection = { list: [{ id: 'a', usd: 2, qty: 3 }, { id: 'b', usd: 1.5, qty: 1 }] }
    expect(totalUsd(collection)).toBe(7.5)
    expect(qtyOf(collection, 'a')).toBe(3)
  })

  test('o que falta: qualquer versão serve e básicos não contam', () => {
    const collection = { list: [{ id: 'x', name: 'Sol Ring', oracle_id: 'o-sol', qty: 1 }] }
    const deck = [
      { name: 'Sol Ring', oracle_id: 'o-sol', usdPrice: '2.00' },
      { name: 'Sol Ring', oracle_id: 'o-sol', usdPrice: '2.00' },
      { name: 'Forest', type_line: 'Basic Land — Forest' },
      { name: 'Rhystic Study', oracle_id: 'o-rs', usdPrice: '30.00' },
    ]
    expect(missingFor(deck, collection).map((m) => `${m.name} ${m.have}/${m.need}`)).toEqual(['Rhystic Study 0/1', 'Sol Ring 1/2'])
  })

  test('euro só quando tem preço', () => {
    expect(savedOf({ id: 'x', name: 'Sol Ring', usdPrice: '1.50', eurPrice: '1.20' }).eur).toBe(1.2)
    expect('eur' in savedOf({ id: 'x', name: 'Sol Ring', usdPrice: '1.50', eurPrice: null })).toBe(false)
    expect(totalEur({ list: [{ id: 'a', eur: 2, qty: 2 }, { id: 'b', usd: 1 }] })).toBe(4)
  })

  test('pastas e o que vai para os amigos', () => {
    const collection = { list: [{ id: 'a', name: 'A', folder: 'Fichário', trade: true, usd: 1, qty: 2 }, { id: 'b', name: 'B', folder: 'Caixa' }, { id: 'c', name: 'C' }] }
    expect(foldersOf(collection)).toEqual(['Caixa', 'Fichário'])
    const pub = publicTrade(collection, { list: [{ id: 'w', name: 'W', set: 'S', img: 'i', usd: 3, added: 3, at: 1 }] })
    expect(pub.trade).toEqual([{ id: 'a', name: 'A', set: '', img: '', usd: 1 }])
    expect(pub.wish).toEqual([{ id: 'w', name: 'W', set: 'S', img: 'i', usd: 3 }])
  })

  test('trocas com um amigo: pelo nome, sem diferença de maiúsculas', () => {
    const collection = { list: [{ id: 'a', name: 'Sol Ring', trade: true, usd: 1 }, { id: 'b', name: 'Counterspell', usd: 2 }] }
    const wishlist = { list: [{ id: 'w', name: 'Rhystic Study' }] }
    const theirTrade = [{ id: 'x', name: 'rhystic study', usd: 30 }, { id: 'y', name: 'Opt' }]
    const theirWish = [{ name: 'SOL RING' }, { name: 'Counterspell' }]
    const m = tradeMatches(collection, wishlist, theirTrade, theirWish)
    expect(m.theyHave.map((c) => c.id)).toEqual(['x'])
    expect(m.iHave).toEqual([{ id: 'a', name: 'Sol Ring', set: '', img: '', usd: 1 }])
  })
})
