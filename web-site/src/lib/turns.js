// Turnos do contador (o mesmo do app, game_provider.dart): a vez passa no
// sentido horário (a ordem dos jogadores), pula quem morreu e a rodada
// avança quando volta para quem começou. Funções puras sobre a partida no
// formato da tela (players, lives, poison, commander).

export const isDead = (g, i) => g.lives[i] <= 0 || g.poison[i] >= 10 || g.commander[i].some((d) => d >= 21) || (g.partnerDamage?.[i] || []).some((d) => d >= 21)

export function startTurns(g, first, now = Date.now()) {
  return { ...g, turnFirst: first, turnPlayer: first, turnRound: 1, turnStartedAt: now, turnTotals: Array(6).fill(0) }
}

export function stopTurns(g) {
  return { ...g, turnPlayer: -1 }
}

export function nextTurn(g, now = Date.now()) {
  const from = g.turnPlayer ?? -1
  if (from < 0) return g
  const totals = Array.from({ length: 6 }, (_, i) => g.turnTotals?.[i] ?? 0)
  totals[from] += Math.max(0, now - (g.turnStartedAt ?? now))
  let next = from
  for (let k = 1; k <= g.players; k++) {
    const i = (from + k) % g.players
    if (!isDead(g, i)) {
      next = i
      break
    }
  }
  let round = g.turnRound ?? 1
  for (let k = 1; k <= g.players; k++) {
    const i = (from + k) % g.players
    if (i === (g.turnFirst ?? 0)) {
      round++
      break
    }
    if (i === next) break
  }
  return { ...g, turnPlayer: next, turnRound: round, turnStartedAt: now, turnTotals: totals }
}

/** Tempo total do jogador nas vezes dele (contando a atual), em ms. */
export const turnTotal = (g, i, now = Date.now()) =>
  (g.turnTotals?.[i] ?? 0) + (g.turnPlayer === i ? Math.max(0, now - (g.turnStartedAt ?? now)) : 0)

export function clock(ms) {
  const s = Math.floor(ms / 1000)
  const m = Math.floor(s / 60)
  return m >= 60 ? `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}` : `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}
