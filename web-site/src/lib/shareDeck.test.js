import { describe, expect, test } from 'vitest'
import { codeFromLink, decodeDeck, deckLink, encodeDeck } from './shareDeck'

describe('link do deck', () => {
  test('vai e volta', async () => {
    const deck = { name: 'Atraxa ção', type: 'Commander', list: "Commander\n1 Atraxa, Praetors' Voice\n\nDeck\n1 Sol Ring\n35 Forest" }
    const code = await encodeDeck(deck)
    expect(code).toMatch(/^[A-Za-z0-9_-]+$/)
    expect(await decodeDeck(code)).toEqual(deck)
    expect(codeFromLink(`Olha meu deck: ${deckLink(code)}`)).toBe(code)
  })

  test('o mesmo código que o app gera (deflate raw + base64 de URL)', async () => {
    // Gerado no Dart (test/deck_share_test.dart) para { n: "Teste", t: "Normal", l: "4 Lightning Bolt" }.
    expect(await decodeDeck('q1bKU7JSCkktLklV0lEqUbJS8ssvyk3MUdJRylGyUjJR8MlMzyjJy8xLV3DKzylRqgUA')).toEqual({ name: 'Teste', type: 'Normal', list: '4 Lightning Bolt' })
  })

  test('sem link', () => {
    expect(codeFromLink('1 Sol Ring')).toBeNull()
  })
})
