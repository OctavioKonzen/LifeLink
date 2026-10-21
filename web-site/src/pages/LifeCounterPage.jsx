import { useEffect, useRef, useState } from 'react'
import { defaultGame, updateSection, useUserData } from '../lib/userData'
import { incrementMatches } from '../lib/xp'
import DiceModal from '../components/DiceModal'
import { playSound, setSoundsOn, soundFor, soundsOn } from '../lib/sounds'

// O mesmo contador do app (game_provider.dart): 2 a 6 jogadores, vida
// inicial à vontade, veneno até 10 e dano de comandante até 21, que também tira
// vida. É a mesma partida do app: com a conta, o que muda aqui aparece lá.

// As mesmas cores do app (GameProvider.palette), na mesma ordem.
const PALETTE = [
  '#6A3DE8', '#1BA655', '#D32F2F', '#1E6FE0', '#E08A1E', '#00897B', '#C2185B', '#5D4037', '#455A64', '#B8860B',
  '#7CB342', '#1B5E20', '#C0CA33', '#00ACC1', '#F06292', '#F9A825', '#3949AB', '#212121',
]
const LIFE_OPTIONS = [20, 25, 30, 40, 50, 60]
const colorOf = (game, i) => PALETTE[(game.colors?.[i] ?? i) % PALETTE.length]
// Segunda cor (degradê, como deck de duas cores); -1 ou vazio = uma cor só.
const secondColorOf = (game, i) => {
  const c = game.colors2?.[i] ?? -1
  return c < 0 ? null : PALETTE[c % PALETTE.length]
}
const backgroundOf = (game, i) => {
  const second = secondColorOf(game, i)
  return second ? `linear-gradient(135deg, ${colorOf(game, i)}, ${second})` : colorOf(game, i)
}
const setList = (list, i, value, fill) => Array.from({ length: 6 }, (_, m) => (m === i ? value : (list?.[m] ?? fill(m))))

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

/** Como a vida mudou (mais novo em cima). */
function LifeHistory({ entries, start }) {
  if (!entries.length) return <p className="px-1 text-white/60">Ainda sem mudanças de vida nesta partida.</p>
  return (
    <ul className="space-y-1">
      {[...entries].reverse().map((e, k) => (
        <li key={k} className="flex items-center gap-2 rounded-lg bg-black/20 px-2 py-1">
          <span className={`w-10 font-black ${e.delta < 0 ? 'text-red-300' : 'text-emerald-300'}`}>{e.delta > 0 ? `+${e.delta}` : e.delta}</span>
          <span className="flex-1 truncate text-white/75">{e.kind === 'cmd' ? 'comandante' : e.delta < 0 ? 'dano' : 'cura'}</span>
          <span className="font-black tabular-nums">{e.life}</span>
        </li>
      ))}
      <li className="px-2 text-white/50">Começou com {start}</li>
    </ul>
  )
}

function Player({ i, game, update, history }) {
  const [details, setDetails] = useState(false)
  const life = game.lives[i]
  const dead = isDead(game, i)
  const others = Array.from({ length: game.players }, (_, j) => j).filter((j) => j !== i)

  // Cada jogador ocupa o seu pedaço da tela; o número cresce com o espaço
  // (unidades cq, do tamanho deste quadro).
  return (
    <div
      className="relative flex min-h-0 min-w-0 flex-1 flex-col rounded-2xl p-3 text-white shadow-lg [container-type:size]"
      style={{ background: backgroundOf(game, i), opacity: dead ? 0.55 : 1 }}
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
        ☣ {game.poison[i]} · ⚔ Comandante · 📈 Histórico {details ? '▲' : '▼'}
      </button>
      {details && (
        <div className="absolute inset-x-3 top-10 bottom-12 z-10 space-y-2 overflow-y-auto rounded-xl bg-black/55 p-2 text-sm backdrop-blur">
          <p className="px-1 text-xs font-bold uppercase tracking-wide text-white/60">Cor</p>
          <div className="flex flex-wrap gap-1.5 px-1 pb-1" aria-label="Cor do jogador">
            {PALETTE.map((c, k) => (
              <button
                key={c}
                type="button"
                onClick={() => update((g) => ({ ...g, colors: setList(g.colors, i, k, (m) => m) }), { silent: true })}
                className={`h-6 w-6 rounded-full ${colorOf(game, i) === c ? 'ring-2 ring-white' : ''}`}
                style={{ background: c }}
                aria-label={`Cor ${k + 1}`}
              />
            ))}
          </div>
          <p className="px-1 text-xs font-bold uppercase tracking-wide text-white/60">Cor 2 (degradê)</p>
          <div className="flex flex-wrap gap-1.5 px-1 pb-1" aria-label="Segunda cor do jogador">
            <button
              type="button"
              onClick={() => update((g) => ({ ...g, colors2: setList(g.colors2, i, -1, () => -1) }), { silent: true })}
              className={`grid h-6 w-6 place-items-center rounded-full border border-white/40 text-xs ${secondColorOf(game, i) ? '' : 'ring-2 ring-white'}`}
              aria-label="Sem degradê"
            >
              ⦸
            </button>
            {PALETTE.map((c, k) => (
              <button
                key={c}
                type="button"
                onClick={() => update((g) => ({ ...g, colors2: setList(g.colors2, i, k, () => -1) }), { silent: true })}
                className={`h-6 w-6 rounded-full ${secondColorOf(game, i) === c ? 'ring-2 ring-white' : ''}`}
                style={{ background: c }}
                aria-label={`Segunda cor ${k + 1}`}
              />
            ))}
          </div>
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
          <p className="px-1 pt-1 text-xs font-bold uppercase tracking-wide text-white/60">📈 Histórico de vida</p>
          <LifeHistory entries={history} start={game.lives[i] - history.reduce((a, e) => a + e.delta, 0)} />
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
  // Cada toque toca o som da mudança (dano, cura, veneno, comandante, morte).
  // Partida nova, nomes e número de jogadores não tocam som (silent).
  // Histórico de vida desta partida (neste navegador): cada mudança, com
  // toques seguidos juntos (ex.: −7).
  const [log, setLog] = useState([])
  const record = (before, after) => {
    const now = Date.now()
    const changes = []
    for (let i = 0; i < after.players; i++) {
      const delta = after.lives[i] - before.lives[i]
      if (!delta) continue
      const cmd = after.commander[i].reduce((a, b) => a + b, 0) > before.commander[i].reduce((a, b) => a + b, 0)
      changes.push({ i, delta, life: after.lives[i], kind: cmd ? 'cmd' : 'life', at: now })
    }
    if (!changes.length) return
    setLog((old) => {
      const next = [...old]
      for (const c of changes) {
        const last = next.findLast((e) => e.i === c.i)
        if (last && last.kind === c.kind && now - last.at < 3000 && Math.sign(last.delta) === Math.sign(c.delta)) {
          next[next.lastIndexOf(last)] = { ...last, delta: last.delta + c.delta, life: c.life, at: now }
        } else next.push(c)
      }
      return next.slice(-300)
    })
  }
  const setGame = (update, { silent = false, reset = false } = {}) =>
    updateSection('game', (g) => {
      const before = view(g)
      const after = update(before)
      const sound = silent ? null : soundFor(before, after)
      if (sound) playSound(sound)
      if (reset) setLog([])
      else if (!silent) record(before, after)
      return toApp(after)
    })
  /** Vida inicial à vontade: 20, 25, 30, 40, 50, 60 ou outra. */
  const chooseLife = (value) => {
    let life = Number(value)
    if (value === 'outro') {
      life = Number(window.prompt('Vida inicial (1 a 999):', String(game.startingLife)))
      if (!Number.isInteger(life) || life < 1 || life > 999) return
    }
    setGame((g) => newGame(g, life), { silent: true, reset: true })
  }
  const [sounds, setSounds] = useState(soundsOn)
  const [banner, setBanner] = useState(null)
  const [dice, setDice] = useState(false)

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
            onChange={(e) => setGame((g) => ({ ...g, players: Number(e.target.value) }), { silent: true })}
            className="rounded-lg border border-line bg-card px-2 py-1"
          >
            {[2, 3, 4, 5, 6].map((n) => (
              <option key={n}>{n}</option>
            ))}
          </select>
        </label>
        <label className="flex items-center gap-2 text-sm">
          Vida
          <select
            value={LIFE_OPTIONS.includes(game.startingLife) ? game.startingLife : 'atual'}
            onChange={(e) => chooseLife(e.target.value)}
            className="rounded-lg border border-line bg-card px-2 py-1"
          >
            {LIFE_OPTIONS.map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
            {!LIFE_OPTIONS.includes(game.startingLife) && <option value="atual">{game.startingLife}</option>}
            <option value="outro">Outro…</option>
          </select>
        </label>
        <button
          type="button"
          onClick={() => {
            setSoundsOn(!sounds)
            setSounds(!sounds)
          }}
          title={sounds ? 'Desligar os sons' : 'Ligar os sons'}
          className="rounded-full bg-text/10 px-3 py-1.5 text-sm font-bold hover:bg-text/20"
        >
          {sounds ? '🔊' : '🔇'}
        </button>
        <button
          type="button"
          onClick={() => setDice(true)}
          className="rounded-full bg-amber-500 px-4 py-1.5 text-sm font-bold text-black hover:brightness-110"
        >
          🎲 Dados
        </button>
        <button
          type="button"
          onClick={() => setGame((g) => newGame(g, g.startingLife), { silent: true, reset: true })}
          className="rounded-full bg-red-500 px-4 py-1.5 text-sm font-bold hover:brightness-110"
        >
          Reiniciar
        </button>
      </div>
      {dice && <DiceModal onClose={() => setDice(false)} />}
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
              <Player key={i} i={i} game={game} update={setGame} history={log.filter((e) => e.i === i)} />
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}
