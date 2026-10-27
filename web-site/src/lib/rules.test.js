import { describe, expect, test } from 'vitest'
import { family, norm, searchRules, termsOf } from './rules'

const data = {
  sections: { 702: 'Keyword Abilities', 704: 'State-Based Actions' },
  rules: [
    ['702.2', 'Deathtouch'],
    ['702.2b', 'A creature with toughness greater than 0 that has been dealt damage by a source with deathtouch is destroyed.'],
    ['702.19', 'Trample'],
    ['702.19a', 'Trample is a static ability that modifies the rules for assigning an attacking creature’s combat damage.'],
    ['702.19c', 'If an attacking creature with trample or trample over planeswalkers is blocked by a creature with deathtouch, it assigns lethal damage.'],
    ['704.5c', 'If a player has ten or more poison counters, that player loses the game.'],
  ],
  glossary: [
    ['Trample', 'A keyword ability that modifies how a creature assigns combat damage. See rule 702.19.'],
    ['Poison Counter', 'A counter that may be given to a player. See rule 122.1f.'],
  ],
  pt: { atropelar: 'trample', 'toque mortífero': 'deathtouch', veneno: 'poison counter', perde: 'loses the game' },
  stop: ['com', 'que', 'uma', 'quantos', 'the'],
}

describe('juiz de regras', () => {
  test('português vira os termos das regras', () => {
    expect(norm('Toque Mortífero')).toBe('toque mortifero')
    expect(termsOf('atropelar com toque mortífero', data).map((t) => t.term)).toEqual(['deathtouch', 'trample'])
  })

  test('acha a regra da habilidade e as que juntam os dois termos primeiro', () => {
    const r = searchRules(data, 'atropelar com toque mortífero')
    expect(r.rules[0][0]).toBe('702.19c')
    expect(r.glossary[0][0]).toBe('Trample')
  })

  test('veneno', () => {
    const r = searchRules(data, 'quantos veneno perde')
    expect(r.rules[0][0]).toBe('704.5c')
    expect(r.glossary[0][0]).toBe('Poison Counter')
  })

  test('número da regra', () => {
    expect(searchRules(data, '702.19').rules.map((x) => x[0])).toEqual(['702.19', '702.19a', '702.19c'])
    expect(family(data, '702.19a').length).toBe(3)
  })

  test('sem nada para buscar', () => {
    expect(searchRules(data, 'com que').rules).toEqual([])
  })
})
