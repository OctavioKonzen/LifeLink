import { describe, expect, test } from 'vitest'
import { deckProblems, parseDeckList, shuffled } from './deckTools'

describe('ferramentas de deck', () => {
  test('lê listas do Moxfield, Archidekt, Arena e MTGO', () => {
    const lines = parseDeckList(`Commander
1 Atraxa, Praetors' Voice (ONE) 196 *F*

Deck
1x Sol Ring (CMM) 410 [Ramp]
4 Lightning Bolt
Island
Creatures (2)
2 Llanowar Elves
// Sideboard
3 Duress
SB: 1 Negate
Maybeboard
1 Opt`)
    expect(lines.map((l) => [l.qty, l.name, l.set, l.number])).toEqual([
      [1, "Atraxa, Praetors' Voice", 'one', '196'],
      [1, 'Sol Ring', 'cmm', '410'],
      [4, 'Lightning Bolt', null, null],
      [1, 'Island', null, null],
      [2, 'Llanowar Elves', null, null],
    ])
    expect(lines[0].commander).toBe(true)
    expect(lines[1].commander).toBe(false)
  })

  const card = (name, type = 'Creature', legalities = { commander: 'legal', modern: 'legal' }) => ({ name, type_line: type, oracle_text: '', legalities })

  test('legalidade: tamanho, cópias e banidas', () => {
    const deck = [...Array.from({ length: 98 }, (_, i) => card(`Carta ${i}`)), card('Sol Ring', 'Artifact', { commander: 'legal', modern: 'not_legal' }), card('Forest', 'Basic Land — Forest')]
    expect(deckProblems('commander', deck)).toEqual([])
    expect(deckProblems('commander', [...deck, card('Carta 1')]).join('\n')).toContain('2 cópias')
    expect(deckProblems('modern', deck)).toContain('Sol Ring: não é legal')
    expect(deckProblems('modern', Array.from({ length: 59 }, () => card('X')))[0]).toContain('59 cartas')
  })

  test('embaralhar mantém as mesmas cartas', () => {
    let seed = 1
    const random = () => ((seed = (seed * 16807) % 2147483647) / 2147483647)
    const list = Array.from({ length: 60 }, (_, i) => i)
    const s = shuffled(list, random)
    expect(s).not.toEqual(list)
    expect([...s].sort((a, b) => a - b)).toEqual(list)
  })
})
