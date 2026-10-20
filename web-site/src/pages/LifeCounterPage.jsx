import { useEffect, useState } from 'react'

// O mesmo contador do app (game_provider.dart): 2 a 6 jogadores, vida 20 ou
// 40 (Commander), veneno até 10 e dano de comandante até 21, que também tira
// vida. Fica guardado no navegador.

const KEY = 'life_counter_v1'
const COLORS = ['#ef4444', '#3b82f6', '#22c55e', '#eab308', '#a855f7', '#f97316']

function newGame(players, startingLife, names) {
  return {
    players,
    startingLife,
    names: names || Array.from({ length: 6 }, (_, i) => `Jogador ${i + 1}`),
    lives: Array(6).fill(startingLife),
    poison: Array(6).fill(0),
    commander: Array.from({ length: 6 }, () => Array(6).fill(0)),
  }
}

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY))
    if (saved?.lives?.length === 6) return saved
  } catch {
    // Sem jogo salvo ou armazenamento bloqueado.
  }
  return newGame(2, 40)
}

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
  const dead = life <= 0 || game.poison[i] >= 10 || game.commander[i].some((d) => d >= 21)
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
  const [game, setGame] = useState(load)

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(game))
    } catch {
      // Navegação privada: o jogo só não fica salvo.
    }
  }, [game])

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
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: game.players }, (_, i) => (
          <Player key={i} i={i} game={game} update={setGame} />
        ))}
      </div>
    </div>
  )
}
