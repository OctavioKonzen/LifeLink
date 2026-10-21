import { expect, test } from 'vitest'
import { soundFor } from './sounds'

const game = (over = {}) => ({ players: 2, lives: [40, 40], poison: [0, 0], commander: [[0, 0], [0, 0]], ...over })

test('o som de cada mudança', () => {
  expect(soundFor(game(), game({ lives: [39, 40] }))).toBe('dano')
  expect(soundFor(game({ lives: [30, 40] }), game({ lives: [31, 40] }))).toBe('cura')
  expect(soundFor(game(), game({ poison: [1, 0] }))).toBe('veneno')
  expect(soundFor(game(), game({ lives: [37, 40], commander: [[0, 3], [0, 0]] }))).toBe('comandante')
  expect(soundFor(game({ lives: [1, 40] }), game({ lives: [0, 40] }))).toBe('morte')
  expect(soundFor(game({ poison: [9, 0] }), game({ poison: [10, 0] }))).toBe('morte')
  expect(soundFor(game(), game())).toBe(null)
})
