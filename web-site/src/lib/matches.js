// Histórico de partidas e estatísticas (o mesmo do app, match_provider.dart).
// Fica em users/{uid}.data.matches.list. As linhas da vida vão como texto
// ("40,33,30"), porque o Firestore não aceita lista dentro de lista.

import { getState, updateSection } from './userData'

const MAX = 150

/**
 * A partida que acabou de terminar. game: a partida no formato da tela
 * (players, names, lives...); log: as mudanças de vida desta partida
 * ({ i, delta, life, at }); startedAt: quando começou (ms).
 */
export function matchFromGame(game, log, { winner, now = Date.now(), startedAt } = {}) {
  const start = startedAt ?? log[0]?.at ?? now
  return {
    id: String(now),
    at: now,
    durationMs: Math.max(0, now - start),
    startingLife: game.startingLife,
    rounds: game.turnPlayer >= 0 ? game.turnRound : 0,
    winner: winner ?? -1,
    players: Array.from({ length: game.players }, (_, i) => ({
      name: game.names[i],
      color: game.colors?.[i] ?? i,
      color2: game.colors2?.[i] ?? -1,
      deck: (game.playerDecks?.[i] || '').trim(),
      life: game.lives[i],
    })),
    timelines: Array.from({ length: game.players }, (_, i) => {
      const mine = log.filter((e) => e.i === i)
      const first = game.lives[i] - mine.reduce((a, e) => a + e.delta, 0)
      let points = [first, ...mine.map((e) => e.life)]
      if (points.length > 60) {
        const step = points.length / 59
        points = [...Array.from({ length: 59 }, (_, k) => points[Math.floor(k * step)]), points.at(-1)]
      }
      return points.join(',')
    }),
  }
}

export const timelineOf = (match, i) =>
  String(match.timelines?.[i] ?? '')
    .split(',')
    .filter(Boolean)
    .map(Number)

export const matchList = () => getState().matches?.list || []

export function addMatch(match) {
  updateSection('matches', (m) => ({ list: [match, ...(m?.list || [])].slice(0, MAX) }))
}

export function removeMatch(id) {
  updateSection('matches', (m) => ({ list: (m?.list || []).filter((x) => x.id !== id) }))
}

export function clearMatches() {
  updateSection('matches', () => ({ list: [] }))
}

/** Vitórias e partidas por jogador (nome, sem diferença de maiúscula) ou por deck. */
export function matchStats(matches, { byDeck = false } = {}) {
  const table = new Map()
  for (const m of matches) {
    m.players.forEach((p, i) => {
      const name = String(byDeck ? p.deck || '' : p.name || '').trim()
      if (!name) return
      const key = name.toLowerCase()
      if (!table.has(key)) table.set(key, { name, played: 0, wins: 0 })
      const s = table.get(key)
      s.played++
      if (m.winner === i) s.wins++
    })
  }
  return [...table.values()]
    .map((s) => ({ ...s, rate: s.played ? s.wins / s.played : 0 }))
    .sort((a, b) => b.wins - a.wins || b.rate - a.rate)
}

export function averageDuration(matches) {
  const real = matches.map((m) => m.durationMs).filter((ms) => ms > 60000)
  return real.length ? Math.round(real.reduce((a, b) => a + b, 0) / real.length) : 0
}

export function duration(ms) {
  const m = Math.floor(ms / 60000)
  if (m < 1) return 'menos de 1 min'
  return m >= 60 ? `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}` : `${m} min`
}
