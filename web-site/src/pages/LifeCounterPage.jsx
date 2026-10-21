import { useEffect, useRef, useState } from 'react'
import { defaultGame, updateSection, useUserData } from '../lib/userData'
import { incrementMatches } from '../lib/xp'

// O mesmo contador do app (game_provider.dart): 2 a 6 jogadores, vida 20 ou
// 40 (Commander), veneno até 10 e dano de comandante até 21, que também tira
// vida. É a mesma partida do app: com a conta, o que muda aqui aparece lá.

// As mesmas cores do app (GameProvider.palette); cada jogador escolhe a sua no app.
const PALETTE = ['#6A3DE8', '#1BA655', '#D32F2F', '#1E6FE0', '#E08A1E', '#00897B', '#C2185B', '#5D4037', '#455A64', '#B8860B']
const colorOf = (game, i) => PALETTE[(game.colors?.[i] ?? i) % PALETTE.length]

// Formato do app (users/{uid}.data.game) → nomes curtos usados nesta tela.
// O resto (energia, experiência, imposto, cores) passa direto, sem se perder.
const view = (g) => ({ ...g, players: g.playerCount, names: g.playerNames, commander: g.commanderDamage })
const toApp = ({ players, names, commander, ...rest }) => ({ ...rest, playerCount: players, playerNames: names, commanderDamage: commander })
// Partida nova: zera tudo, mas mantém nomes e cores.
const newGame = (g, startingLife) => ({ ...g, ...view(defaultGame(startingLife, g.players, g.names)) })

const isDead = (g, i) => g.lives[i] <= 0 || g.poison[i] >= 10 || g.commander[i].some((d) => d >= 21)

const clamp = (v, min, max) => Math.min(max, Math.max(min, v))

function Step({ onClick, children, label }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-black/25 text-xl font-black hover:bg-black/40 active:scale-95"
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

  // Cada jogador ocupa o seu pedaço da tela; o número cresce com o espaço
  // (unidades cq, do tamanho deste quadro).
  return (
    <div
      className="relative flex min-h-0 min-w-0 flex-1 flex-col rounded-2xl p-3 text-white shadow-lg [container-type:size]"
      style={{ background: colorOf(game, i), opacity: dead ? 0.55 : 1 }}
    >
      <input
        value={game.names[i]}
        onChange={(e) => update((g) => ({ ...g, names: g.names.map((n, k) => (k === i ? e.target.value : n)) }))}
        className="w-full bg-transparent text-center text-lg font-bold outline-none"
        aria-label="Nome do jogador"
      />
      {/* Botões em coluna dos dois lados: cabem até nos quadros estreitos (6 jogadores). */}
      <div className="flex min-h-0 flex-1 items-center justify-between gap-1">
        <div className="flex flex-col gap-2">
          <Step label="Tirar 1 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v - 1 : v)) }))}>
            −
          </Step>
          <Step label="Tirar 5 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v - 5 : v)) }))}>
            −5
          </Step>
        </div>
        <div className="font-black leading-none tabular-nums drop-shadow" style={{ fontSize: 'min(30cqw, 52cqh)' }}>
          {dead ? '☠' : life}
        </div>
        <div className="flex flex-col gap-2">
          <Step label="Somar 1 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v + 1 : v)) }))}>
            +
          </Step>
          <Step label="Somar 5 de vida" onClick={() => update((g) => ({ ...g, lives: g.lives.map((v, k) => (k === i ? v + 5 : v)) }))}>
            +5
          </Step>
        </div>
      </div>
      <button type="button" onClick={() => setDetails((d) => !d)} className="w-full truncate rounded-full bg-black/20 px-2 py-1 text-sm font-semibold">
        ☣ {game.poison[i]} · ⚔ Comandante {details ? '▲' : '▼'}
      </button>
      {details && (
        <div className="absolute inset-x-3 top-10 bottom-12 z-10 space-y-2 overflow-y-auto rounded-xl bg-black/55 p-2 text-sm backdrop-blur">
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

// Quantos jogadores vão em cada linha. Tela larga (computador, celular
// deitado): mais lado a lado; tela alta (celular em pé): mais um embaixo do outro.
const ROWS_WIDE = { 2: [2], 3: [3], 4: [2, 2], 5: [3, 2], 6: [3, 3] }
const ROWS_TALL = { 2: [1, 1], 3: [1, 2], 4: [2, 2], 5: [1, 2, 2], 6: [2, 2, 2] }

export function rowsFor(players, wide) {
  const sizes = (wide ? ROWS_WIDE : ROWS_TALL)[players] || [players]
  let next = 0
  return sizes.map((n) => Array.from({ length: n }, () => next++))
}

function useWide() {
  const get = () => window.innerWidth >= window.innerHeight
  const [wide, setWide] = useState(get)
  useEffect(() => {
    const onResize = () => setWide(get())
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])
  return wide
}

export default function LifeCounterPage() {
  const game = view(useUserData((s) => s.game))
  const wide = useWide()
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

  // A página ocupa a altura que sobra embaixo da barra de cima (72px) e as
  // vidas ficam com tudo o que sobra embaixo dos botões.
  return (
    <div className="flex flex-col" style={{ height: 'calc(100dvh - 72px - 24px)', minHeight: 420 }}>
      <div className="mb-3 flex shrink-0 flex-wrap items-center gap-3">
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
          onClick={() => setGame((g) => newGame(g, g.startingLife === 40 ? 20 : 40))}
          className="rounded-full bg-text/10 px-4 py-1.5 text-sm font-bold hover:bg-text/20"
        >
          {game.startingLife === 40 ? 'Commander (40)' : 'Normal (20)'}
        </button>
        <button
          type="button"
          onClick={() => setGame((g) => newGame(g, g.startingLife))}
          className="rounded-full bg-red-500 px-4 py-1.5 text-sm font-bold hover:brightness-110"
        >
          Reiniciar
        </button>
      </div>
      {alive.length === 1 && (
        <p className="mb-3 shrink-0 rounded-xl bg-amber-400/15 p-3 text-center font-bold text-amber-300">
          🏆 {game.names[alive[0]]} venceu! +50 XP{banner ? ` · Novo banner: ${banner}` : ''}
        </p>
      )}
      {/* A tela inteira para as vidas, dividida em linhas conforme o número
          de jogadores e o formato da tela. */}
      <div className="flex min-h-0 flex-1 flex-col gap-3">
        {rowsFor(game.players, wide).map((row, r) => (
          <div key={r} className="flex min-h-0 flex-1 gap-3">
            {row.map((i) => (
              <Player key={i} i={i} game={game} update={setGame} />
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}
