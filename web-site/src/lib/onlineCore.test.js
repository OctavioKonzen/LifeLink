import { describe, expect, test } from 'vitest'
import { changedFields, flattenGame, nestFields, newTableCode, unflattenGame } from './onlineCore'
import { defaultGame, toCloud } from './userData'

describe('mesa online', () => {
  test('cada jogador separado e só vai o que mudou', () => {
    const game = toCloud('game', defaultGame(40, 2))
    const before = flattenGame(game)
    expect(before['p0.lives']).toBe(40)
    expect(before['g.playerCount']).toBe(2)
    const after = flattenGame({ ...game, lives: game.lives.map((v, i) => (i === 1 ? 37 : v)) })
    expect(changedFields(before, after)).toEqual({ 'p1.lives': 37 })
    const back = unflattenGame(nestFields(after))
    expect(back.lives.slice(0, 2)).toEqual([40, 37])
    expect(back.cmdRows[0]).toBe('0,0,0,0,0,0')
  })

  test('código fácil de ler', () => {
    expect(newTableCode()).toMatch(/^[A-HJ-NP-Z2-9]{6}$/)
  })
})
