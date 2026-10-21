import { describe, expect, test } from 'vitest'
import { clock, nextTurn, startTurns, turnTotal } from './turns'

const game = (players) => ({
  players,
  lives: Array(6).fill(40),
  poison: Array(6).fill(0),
  commander: Array.from({ length: 6 }, () => Array(6).fill(0)),
})

describe('turnos', () => {
  test('sentido horário, pula quem morreu e a rodada avança', () => {
    let g = startTurns(game(4), 2, 0)
    g = nextTurn(g, 1000)
    expect(g.turnPlayer).toBe(3)
    expect(g.turnTotals[2]).toBe(1000)
    g = { ...g, lives: g.lives.map((v, i) => (i === 0 ? 0 : v)) }
    g = nextTurn(g, 3000)
    expect(g.turnPlayer).toBe(1)
    expect(g.turnRound).toBe(1)
    g = nextTurn(g, 4000)
    expect(g.turnPlayer).toBe(2)
    expect(g.turnRound).toBe(2)
    expect(turnTotal(g, 2, 4500)).toBe(1500)
  })

  test('relógio', () => {
    expect(clock(65000)).toBe('01:05')
    expect(clock(3 * 3600000 + 5 * 60000)).toBe('3h05')
  })
})
