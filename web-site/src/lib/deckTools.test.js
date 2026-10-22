import { describe, expect, test } from 'vitest'
import { bracket, deckProblems, edhrecNames, edhrecSlug, exportList, parseDeckList, shuffled } from './deckTools'

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

  test('exportar: comandante à parte, cópias juntas e nome em inglês', () => {
    const id = '0000579f-7b35-4ed3-b44c-db2a538066fe'
    const cards = [{ name: 'Atraxa', commander: true }, { name: 'Anel Solar', id }, { name: 'Anel Solar', id }, { name: 'Island' }]
    const text = exportList(cards, new Map([[id, 'Sol Ring']]))
    expect(text).toBe('Commander\n1 Atraxa\n\nDeck\n1 Island\n2 Sol Ring')
    expect(parseDeckList(text).map((l) => `${l.qty} ${l.name}`)).toEqual(expect.arrayContaining(['1 Atraxa', '2 Sol Ring', '1 Island']))
  })

  test('nível do deck (bracket)', () => {
    const plain = { name: 'Llanowar Elves', oracle_text: '{T}: Add {G}.' }
    expect(bracket([plain]).bracket).toBe(2)
    const gc = (n) => ({ name: `GC ${n}`, game_changer: true, oracle_text: '' })
    expect(bracket([plain, gc(1)])).toMatchObject({ bracket: 3, gameChangers: ['GC 1'] })
    expect(bracket([gc(1), gc(2), gc(3)]).bracket).toBe(3)
    expect(bracket([gc(1), gc(2), gc(3), gc(4)]).bracket).toBe(4)
    const turn = (n) => ({ name: `Turn ${n}`, oracle_text: 'Take an extra turn after this one.' })
    expect(bracket([turn(1)])).toMatchObject({ bracket: 3, extraTurns: ['Turn 1'] })
    expect(bracket([turn(1), turn(2)]).bracket).toBe(4)
    // Texto na outra face e destruição de terrenos em massa.
    const mld = { name: 'Armageddon', printed_name: 'Armagedom', card_faces: [{ oracle_text: '' }, { oracle_text: 'Destroy all lands.' }] }
    expect(bracket([mld])).toMatchObject({ bracket: 4, landDestruction: ['Armagedom'] })
    expect(bracket([{ name: 'Winter Orb', oracle_text: "As long as Winter Orb is untapped, players can't untap more than one land during their untap steps." }]).bracket).toBe(2)
    expect(bracket([{ name: 'Static Orb', oracle_text: 'Each player sacrifices four lands.' }]).bracket).toBe(4)
  })

  test('página do comandante no EDHREC', () => {
    expect(edhrecSlug("Atraxa, Praetors' Voice")).toBe('atraxa-praetors-voice')
    expect(edhrecSlug('Esika, God of the Tree // The Prismatic Bridge')).toBe('esika-god-of-the-tree')
    expect(edhrecSlug('Kenrith, the Returned King')).toBe('kenrith-the-returned-king')
    expect(edhrecSlug('Lord Windgrace - Planeswalker')).toBe('lord-windgrace-planeswalker')
  })

  test('sugestões do EDHREC: as mais usadas primeiro, sem as do deck', () => {
    const page = {
      container: {
        json_dict: {
          cardlists: [
            { cardviews: [{ name: 'Sol Ring', inclusion: 900, potential_decks: 1000, synergy: 0 }, { name: 'Doubling Season', inclusion: 300, potential_decks: 1000, synergy: 0.5 }] },
            { cardviews: [{ name: 'Doubling Season', inclusion: 300, potential_decks: 1000, synergy: 0.1 }, { name: 'Opt', num_decks: 100, potential_decks: 1000 }, { name: '' }, { name: 'Forest', num_decks: 1000, potential_decks: 1000 }] },
          ],
        },
      },
    }
    // Sol Ring 0.9; Doubling Season 0.3 + 0.15 = 0.45 (a maior das duas); Opt 0.1; terreno básico fica de fora.
    expect(edhrecNames(page)).toEqual(['Sol Ring', 'Doubling Season', 'Opt'])
    expect(edhrecNames(page, new Set(['sol ring']))).toEqual(['Doubling Season', 'Opt'])
    expect(edhrecNames({})).toEqual([])
  })
})
