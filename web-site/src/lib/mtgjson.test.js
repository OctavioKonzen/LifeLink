import { describe, expect, test } from 'vitest'
import { coverIds, deckCards, deckCategory, imageFor } from './mtgjson'

describe('deckCategory', () => {
  test('igual ao app', () => {
    expect(deckCategory({ type: 'Commander Deck', name: 'Draconic Dissent' })).toBe(0)
    expect(deckCategory({ type: 'Challenger Deck', name: 'Mono Red' })).toBe(1)
    expect(deckCategory({ type: 'Starter Deck', name: 'x' })).toBe(2)
    expect(deckCategory({ type: 'Commander Deck', name: 'Avatar Aang' })).toBe(2)
    expect(deckCategory({ type: 'Theme Deck', name: 'x' })).toBeNull()
  })
})

describe('cartas do deck', () => {
  const data = {
    name: 'Teste',
    commander: [{ name: 'A', count: 1, identifiers: { scryfallId: 'aaaa' } }],
    mainBoard: [
      { name: 'B', count: 2, identifiers: { scryfallId: 'bbbb' } },
      { name: 'C', count: 1, identifiers: { scryfallId: 'aaaa' } },
      { name: 'D', count: 1, identifiers: { scryfallId: 'dddd' } },
      { name: 'E', count: 1, identifiers: { scryfallId: 'eeee' } },
    ],
    sideBoard: [],
  }

  test('lê todas as listas', () => {
    expect(deckCards(data).map((c) => `${c.count}x ${c.name}`)).toEqual(['1x A', '2x B', '1x C', '1x D', '1x E'])
  })

  test('capa sem repetir carta', () => {
    expect(coverIds(data)).toEqual(['aaaa', 'bbbb', 'dddd'])
  })

  test('endereço da imagem pelo id do Scryfall', () => {
    expect(imageFor('6da045f8-6278')).toBe('https://cards.scryfall.io/normal/front/6/d/6da045f8-6278.jpg')
    expect(imageFor(undefined)).toBeNull()
  })
})
