import { beforeEach, describe, expect, test } from 'vitest'
import { averageDuration, matchFromGame, matchStats, timelineOf } from './matches'
import { clearAll, fromCloud, toCloud } from './userData'

beforeEach(() => clearAll())

const hasNestedList = (v, inList = false) =>
  Array.isArray(v) ? inList || v.some((x) => hasNestedList(x, true)) : v && typeof v === 'object' ? Object.values(v).some((x) => hasNestedList(x)) : false

describe('partidas', () => {
  test('a partida guarda jogadores, deck, vencedor e a vida ao longo do jogo', () => {
    const game = { players: 2, startingLife: 40, names: ['Ana', 'Bia'], lives: [40, 0], playerDecks: [' Atraxa ', ''], turnPlayer: -1 }
    const log = [
      { i: 1, delta: -10, life: 30, at: 1000 },
      { i: 1, delta: -30, life: 0, at: 61000 },
    ]
    const m = matchFromGame(game, log, { winner: 0, now: 121000 })
    expect(m.durationMs).toBe(120000)
    expect(m.players[0].deck).toBe('Atraxa')
    expect(timelineOf(m, 1)).toEqual([40, 30, 0])
    expect(timelineOf(m, 0)).toEqual([40])
    expect(hasNestedList(m)).toBe(false)
  })

  test('estatísticas por jogador e por deck', () => {
    const match = (winner, players) => ({ winner, durationMs: 1800000, players: players.map(([name, deck]) => ({ name, deck })) })
    const list = [match(0, [['Ana', 'Atraxa'], ['Bia', 'Krenko']]), match(1, [['ana', 'Atraxa'], ['Bia', '']]), match(0, [['Ana', 'Atraxa'], ['Caio', 'Krenko']])]
    const players = matchStats(list)
    expect(players[0]).toMatchObject({ name: 'Ana', wins: 2, played: 3 })
    expect(matchStats(list, { byDeck: true }).map((d) => [d.name, d.wins, d.played])).toEqual([['Atraxa', 2, 3], ['Krenko', 0, 2]])
    expect(averageDuration(list)).toBe(1800000)
  })

  test('na conta, o dano de comandante vai sem lista dentro de lista', () => {
    const game = { lives: [40], commanderDamage: [[0, 5], [1, 0]] }
    const cloud = toCloud('game', game)
    expect(hasNestedList(cloud)).toBe(false)
    expect(fromCloud({ game: cloud }).game.commanderDamage[0].slice(0, 2)).toEqual([0, 5])
  })

  test('o dano do 2º comandante (parceiro) vai e volta à parte', () => {
    const game = { lives: [40], partners: [0, 1], commanderDamage: [[0, 5]], partnerDamage: [[0, 9]] }
    const cloud = toCloud('game', game)
    expect(hasNestedList(cloud)).toBe(false)
    const back = fromCloud({ game: cloud }).game
    expect(back.partnerDamage[0][1]).toBe(9)
    expect(back.commanderDamage[0][1]).toBe(5)
    expect(back.partners).toEqual([0, 1])
  })
})
