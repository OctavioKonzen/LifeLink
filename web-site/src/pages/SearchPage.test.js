import { describe, expect, test } from 'vitest'
import { ownQuery } from './SearchPage'

describe('busca no banco do LifeLink', () => {
  test('sem texto: os comandantes mais jogados', () => {
    expect(ownQuery('')).toMatchObject({ text: '', types: ['Legendary Creature'], order: 'popular' })
  })

  test('com texto: relevância (sem ordem) e os filtros', () => {
    expect(ownQuery('raio', { types: ['Instant'], colors: ['R', 'C'], set: 'm10' })).toEqual({
      text: 'raio',
      nameOnly: false,
      types: ['Instant'],
      set: 'm10',
      colors: 'RC',
      order: undefined,
    })
  })

  test('nome exato (sugestão escolhida)', () => {
    expect(ownQuery('!"Sol Ring"')).toMatchObject({ text: 'Sol Ring', nameOnly: true })
  })

  test('sintaxe da Scryfall ou vários tipos: fica com a Scryfall', () => {
    expect(ownQuery('t:dragon')).toBeNull()
    expect(ownQuery('', { types: ['Elf', 'Goblin'] })).toBeNull()
  })
})
