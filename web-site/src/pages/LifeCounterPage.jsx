import { useEffect, useRef, useState } from 'react'
import { defaultGame, updateSection, useUserData } from '../lib/userData'
import { incrementMatches } from '../lib/xp'

// O mesmo contador do app (game_provider.dart): 2 a 6 jogadores, vida 20 ou
// 40 (Commander), veneno até 10 e dano de comandante até 21, que também tira
// vida. É a mesma partida do app: com a conta, o que muda aqui aparece lá.

const COLORS = ['#ef4444', '#3b82f6', '#22c55e', '#eab308', '#a855f7', '#f97316']

// Formato do app (users/{uid}.data.game) → nomes curtos usados nesta tela.
const view = (g) => ({ players: g.playerCount, startingLife: g.startingLife, names: g.playerNames, lives: g.lives, poison: g.poison, commander: g.commanderDamage })
const toApp = (v) => ({ playerCount: v.players, startingLife: v.startingLife, playerNames: v.names, lives: v.lives, poison: v.poison, commanderDamage: v.commander })
const newGame = (players, startingLife, names) => view(defaultGame(startingLife, players, names))

const isDead = (g, i) => g.lives[i] <= 0 || g.poison[i] >= 10 || g.commander[i].some((d) => d >= 21)

const clamp = (v, min, max) => Math.min(max, Math.max(min, v))

function Step({ onClick, children, label }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="grid h-12 w-12 place-items-center rounded-full bg-black/25 text-2xl font-black hover:bg-black/40 active:scale-95"
    >
      {children}
    </button>
  )
}

function Player({ i, game, update }) {
  const [details, setDetails] = useState(false)
  const life = game.lives[i]
  const dead = isDead(game, i)
  const others = Array.from({ length: game.players }, (_, j) => j).filter((j) => j !== i)

  return (
    <div className="rounded-2xl p-4 text-white shadow-lg" style={{ background: COLORS[i], opacity: dead ? 0.55 : 1 }}>
      <input
        value={game.names[i]}
        onChange={(e) => update((g) => ({ ...g, names: g.names.map((n, k) => (k === i ? e.target.value : n)) }))}
        className="w-full bg-transparent text-center font-bold outline-none"
        aria-label="Nome do jogador"
      />
      <div className="my-2 flex items-center justify-between">
        <Step label="Tirar 5 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v - 5 : v)) }))}>
          −5
        </Step>
        <Step label="Tirar 1 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v - 1 : v)) }))}>
          −
        </Step>
        <div className="text-6xl font-black tabular-nums drop-shadow">{dead ? '☠' : life}</div>
        <Step label="Somar 1 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v + 1 : v)) }))}>
          +
        </Step>
        <Step label="Somar 5 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v + 5 : v)) }))}>
          +5
        </Step>
      </div>
      <button type="button" onClick={() => setDetails((d) => !d)} className="w-full rounded-full bg-black/20 py-1 text-sm font-semibold">
        ☣ {game.poison[i]} veneno · ⚔ dano de comandante {details ? '▲' : '▼'}
      </button>
      {details && (
        <div className="mt-3 space-y-2 text-sm">
          <Row
            label="Veneno"
            value={game.poison[i]}
            onChange={(d) => update((g) => ({ ...g, poison: g.poison.map((v, k) => (k === i ? clamp(v + d, 0, 10) : v)) }))}
          />
          {others.map((j) => (
            <Row
              key={j}
              label={`Comandante de ${game.names[j]}`}
              value={game.commander[i][j]}
              onChange={(d) =>
                update((g) => {
                  const before = g.commander[i][j]
                  const after = clamp(before + d, 0, 21)
                  return {
                    ...g,
                    commander: g.commander.map((row, k) => (k === i ? row.map((v, m) => (m === j ? after : v)) : row)),
                    // O dano de comandante também tira vida.
                    lives: g.lives.map((v, k) => (k === i ? v - (after - before) : v)),
                  }
                })
              }
            />
          ))}
        </div>
      )}
    </div>
  )
}

function Row({ label, value, onChange }) {
  return (
    <div className="flex items-center justify-between gap-2 rounded-xl bg-black/20 px-3 py-1.5">
      <span className="truncate">{label}</span>
      <div className="flex items-center gap-2">
        <button type="button" onClick={() => onChange(-1)} className="h-8 w-8 rounded-full bg-black/25 font-bold" aria-label={`Diminuir ${label}`}>
          −
        </button>
        <span className="w-6 text-center font-black tabular-nums">{value}</span>
        <button type="button" onClick={() => onChange(1)} className="h-8 w-8 rounded-full bg-black/25 font-bold" aria-label={`Aumentar ${label}`}>
          +
        </button>
      </div>
    </div>
  )
}

export default function LifeCounterPage() {
  const game = view(useUserData((s) => s.game))
  const setGame = (update) => updateSection('game', (g) => toApp(update(view(g))))
  const [banner, setBanner] = useState(null)

  // Sobrou um só jogador vivo: a partida conta para o perfil (+50 XP), uma
  // vez por partida, como no app.
  const alive = Array.from({ length: game.players }, (_, i) => i).filter((i) => !isDead(game, i))
  const counted = useRef(alive.length === 1) // partida que já tinha acabado não conta de novo
  useEffect(() => {
    if (alive.length === 1 && !counted.current) {
      counted.current = true
      const unlocked = incrementMatches()
      if (unlocked) setBanner(unlocked)
    } else if (alive.length > 1) {
      counted.current = false
    }
  }, [alive.length])

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <h1 className="mr-auto text-2xl font-black">Contador de vida</h1>
        <label className="flex items-center gap-2 text-sm">
          Jogadores
          <select
            value={game.players}
            onChange={(e) => setGame((g) => ({ ...g, players: Number(e.target.value) }))}
            className="rounded-lg border border-line bg-card px-2 py-1"
          >
            {[2, 3, 4, 5, 6].map((n) => (
              <option key={n}>{n}</option>
            ))}
          </select>
        </label>
        <button
          type="button"
          onClick={() => setGame((g) => newGame(g.players, g.startingLife === 40 ? 20 : 40, g.names))}
          className="rounded-full bg-white/10 px-4 py-1.5 text-sm font-bold hover:bg-white/20"
        >
          {game.startingLife === 40 ? 'Commander (40)' : 'Normal (20)'}
        </button>
        <button
          type="button"
          onClick={() => setGame((g) => newGame(g.players, g.startingLife, g.names))}
          className="rounded-full bg-red-500 px-4 py-1.5 text-sm font-bold hover:brightness-110"
        >
          Reiniciar
        </button>
      </div>
      {alive.length === 1 && (
        <p className="mb-3 rounded-xl bg-amber-400/15 p-3 text-center font-bold text-amber-300">
          🏆 {game.names[alive[0]]} venceu! +50 XP{banner ? ` · Novo banner: ${banner}` : ''}
        </p>
      )}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: game.players }, (_, i) => (
          <Player key={i} i={i} game={game} update={setGame} />
        ))}
      </div>
    </div>
  )
}
