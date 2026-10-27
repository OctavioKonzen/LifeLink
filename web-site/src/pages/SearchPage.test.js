import { describe, expect, test } from 'vitest'
import { ORDERS, buildQuery, noFilters, ownQuery } from './SearchPage'

const f = (extra) => ({ ...noFilters(), ...extra })

describe('busca no banco do LifeLink (igual ao app)', () => {
  test('sem texto: os comandantes mais jogados', () => {
    expect(ownQuery('')).toMatchObject({ text: '', types: ['Legendary Creature'], order: 'popular' })
  })

  test('com texto: relevância e os filtros (tipos, raça e subtipo juntos)', () => {
    expect(ownQuery('raio', f({ types: ['Instant'], colors: ['R', 'C'], set: 'm10' }))).toEqual({
      setOnly: false,
      text: 'raio',
      nameOnly: false,
      types: ['Instant'],
      set: 'm10',
      colors: 'RC',
      order: undefined,
      desc: false,
      lang: 'pt',
    })
    expect(ownQuery('', f({ types: ['Creature', 'Legendary'], race: 'Elf' })).types).toEqual(['Creature', 'Legendary', 'Elf'])
  })

  test('a ordem escolhida', () => {
    expect(ownQuery('dragão', noFilters(), ORDERS[1])).toMatchObject({ order: 'usd', desc: true })
    expect(ownQuery('', noFilters(), ORDERS[3])).toMatchObject({ order: 'cmc', desc: false })
  })

  test('só a coleção: lista na ordem dos números', () => {
    expect(ownQuery('', f({ set: 'cmm' }))).toMatchObject({ setOnly: true, set: 'cmm' })
    expect(ownQuery('anel', f({ set: 'cmm' }))).toMatchObject({ setOnly: false })
    expect(ownQuery('', f({ set: 'cmm' }), ORDERS[1])).toMatchObject({ setOnly: false })
  })

  test('nome exato (sugestão escolhida)', () => {
    expect(ownQuery('!"Sol Ring"')).toMatchObject({ text: 'Sol Ring', nameOnly: true })
  })

  test('sintaxe da Scryfall: fica com a Scryfall', () => {
    expect(ownQuery('t:dragon')).toBeNull()
  })

  test('a busca de reserva na Scryfall, igual ao app', () => {
    expect(buildQuery('', f({ types: ['Creature', 'Artifact'], race: 'Elf', colors: ['G', 'W'], set: 'tle' }))).toBe(
      'is:commander (t:"Creature" or t:"Artifact") t:"Elf" id<=WG set:tle',
    )
  })
})
