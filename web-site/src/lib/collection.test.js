import { describe, expect, test } from 'vitest'
import { missingFor, qtyOf, savedOf, totalUsd } from './collection'

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
})
