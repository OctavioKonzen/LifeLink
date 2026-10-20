import { describe, expect, test } from 'vitest'
import { buildTextQuery, errorFor, imageOf, sized, backImageOf } from './scryfall'

describe('buildTextQuery', () => {
  test('procura no nome e no texto da carta', () => {
    expect(buildTextQuery('lightning bolt')).toBe('((lightning bolt) or (o:lightning o:bolt))')
  })

  test('vazio continua vazio', () => {
    expect(buildTextQuery('   ')).toBe('')
  })

  test('a sintaxe do Scryfall é usada como está', () => {
    expect(buildTextQuery('t:dragon c:r')).toBe('t:dragon c:r')
    expect(buildTextQuery('!"Sol Ring"')).toBe('!"Sol Ring"')
    expect(buildTextQuery('elf or goblin')).toBe('elf or goblin')
  })

  test('palavras com acento e apóstrofo', () => {
    expect(buildTextQuery('dragão')).toBe('((dragão) or (o:dragão))')
    expect(buildTextQuery("urza's")).toBe(`((urza's) or (o:"urza's"))`)
  })
})

describe('sized', () => {
  const normal = 'https://cards.scryfall.io/normal/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.jpg?1562404626'

  test('troca o tamanho mantendo o resto do endereço', () => {
    expect(sized(normal, 'large')).toBe('https://cards.scryfall.io/large/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.jpg?1562404626')
  })

  test('png usa a extensão .png', () => {
    expect(sized(normal, 'png')).toBe('https://cards.scryfall.io/png/front/6/d/6da045f8-6278-4c84-9d39-025adf0789c1.png?1562404626')
    expect(sized(sized(normal, 'png'), 'normal')).toBe(normal)
  })

  test('endereços de fora do Scryfall não mudam', () => {
    expect(sized('https://example.com/a.jpg', 'png')).toBe('https://example.com/a.jpg')
    expect(sized('', 'png')).toBe('')
  })
})

describe('imagens de cartas', () => {
  test('frente e verso das cartas de duas faces', () => {
    const dfc = { card_faces: [{ image_uris: { normal: 'a' } }, { image_uris: { normal: 'b' } }] }
    expect(imageOf(dfc)).toBe('a')
    expect(backImageOf(dfc)).toBe('b')
    expect(imageOf({ image_uris: { normal: 'c' } })).toBe('c')
    expect(backImageOf({ image_uris: { normal: 'c' } })).toBeNull()
  })
})

describe('errorFor', () => {
  test('mensagens compreensíveis', () => {
    expect(errorFor(404).notFound).toBe(true)
    expect(errorFor(404).message).toBe('Nenhuma carta encontrada.')
    expect(errorFor(429).message).toContain('Espere')
    expect(errorFor(400, { details: 'Unknown keyword' }).message).toContain('Unknown keyword')
    expect(errorFor(503).message).toContain('503')
  })
})
