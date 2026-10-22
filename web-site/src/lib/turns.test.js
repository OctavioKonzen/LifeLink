import { describe, expect, test } from 'vitest'
import { clock, nextTurn, shuffleSeats, startTurns, toggleDayNight, turnTotal } from './turns'

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

  test('dia e noite: começa de dia e alterna', () => {
    expect(toggleDayNight({ dayNight: 0 }).dayNight).toBe(1)
    expect(toggleDayNight({ dayNight: 1 }).dayNight).toBe(2)
    expect(toggleDayNight({ dayNight: 2 }).dayNight).toBe(1)
  })

  test('sortear lugares: nome, cores, deck e parceiro andam juntos', () => {
    let seed = 7
    const random = () => ((seed = (seed * 16807) % 2147483647) / 2147483647)
    const g = {
      players: 4,
      names: ['A', 'B', 'C', 'D', 'E', 'F'],
      colors: [0, 1, 2, 3, 4, 5],
      colors2: [-1, 7, -1, -1, -1, -1],
      playerDecks: ['dA', 'dB', 'dC', 'dD', '', ''],
      partners: [0, 1, 0, 0, 0, 0],
    }
    const s = shuffleSeats(g, random)
    expect(s.names.slice(0, 4).sort()).toEqual(['A', 'B', 'C', 'D'])
    expect(s.names.slice(4)).toEqual(['E', 'F'])
    for (let i = 0; i < 4; i++) {
      const from = g.names.indexOf(s.names[i])
      expect([s.colors[i], s.colors2[i], s.playerDecks[i], s.partners[i]]).toEqual([g.colors[from], g.colors2[from], g.playerDecks[from], g.partners[from]])
    }
    // Sem as listas (partida antiga): os valores padrão.
    expect(shuffleSeats({ players: 2, names: ['A', 'B'] }, random).colors2).toEqual(Array(6).fill(-1))
  })
})
