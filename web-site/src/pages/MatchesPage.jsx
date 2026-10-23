import { useState } from 'react'
import { useUserData } from '../lib/userData'
import { ChevronDown, ChevronUp, Trophy } from 'lucide-react'
import { averageDuration, clearMatches, duration, matchStats, timelineOf } from '../lib/matches'

// O mesmo histórico do app (match_history_screen.dart): cada partida
// terminada no contador, com a vida de todos ao longo do jogo, e as
// estatísticas do grupo (vitórias por jogador e por deck).

// As mesmas cores do contador (GameProvider.palette).
const PALETTE = [
  '#6A3DE8', '#1BA655', '#D32F2F', '#1E6FE0', '#E08A1E', '#00897B', '#C2185B', '#5D4037', '#455A64', '#B8860B',
  '#7CB342', '#1B5E20', '#C0CA33', '#00ACC1', '#F06292', '#F9A825', '#3949AB', '#212121',
]
const colorOf = (p) => PALETTE[(p.color ?? 0) % PALETTE.length]

const date = (ms) => new Date(ms).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })

function Chart({ match }) {
  const lines = match.players.map((_, i) => timelineOf(match, i))
  const all = lines.flat()
  if (!all.length) return null
  const hi = Math.max(...all) + 2
  const lo = Math.max(0, Math.min(...all) - 2)
  const span = Math.max(1, hi - lo)
  return (
    <svg viewBox="0 0 300 100" preserveAspectRatio="none" className="h-28 w-full" aria-label="Vida ao longo da partida">
      {[0, 50, 100].map((y) => (
        <line key={y} x1="0" x2="300" y1={y} y2={y} stroke="currentColor" strokeOpacity="0.1" />
      ))}
      {lines.map((t, i) =>
        t.length < 2 ? null : (
          <polyline
            key={i}
            fill="none"
            stroke={colorOf(match.players[i])}
            strokeWidth={i === match.winner ? 3 : 2}
            vectorEffect="non-scaling-stroke"
            strokeLinejoin="round"
            points={t.map((v, k) => `${(300 * k) / (t.length - 1)},${100 * (1 - (v - lo) / span)}`).join(' ')}
          />
        ),
      )}
    </svg>
  )
}

function MatchCard({ match }) {
  const [open, setOpen] = useState(false)
  const winner = match.players[match.winner]
  return (
    <li className="rounded-2xl border border-line bg-surface p-5">
      <button type="button" onClick={() => setOpen((o) => !o)} className="flex w-full items-center gap-3 text-left">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full text-lg" style={{ background: winner ? colorOf(winner) : '#777' }}>
          <Trophy className="size-5 text-white" aria-hidden="true" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-lg font-semibold">{winner ? `${winner.name} venceu` : 'Empate'}</span>
          <span className="block text-xs text-muted">
            {date(match.at)} · {duration(match.durationMs)}
            {match.rounds > 0 ? ` · ${match.rounds} rodadas` : ''} · vida {match.startingLife}
          </span>
        </span>
        {open ? <ChevronUp className="size-5 text-muted" aria-hidden="true" /> : <ChevronDown className="size-5 text-muted" aria-hidden="true" />}
      </button>
      {open && (
        <div className="mt-3">
          <Chart match={match} />
          <ul className="mt-2 space-y-1">
            {match.players.map((p, i) => (
              <li key={i} className="flex items-center gap-2">
                <span className="h-3 w-3 rounded-full" style={{ background: colorOf(p) }} />
                <span className={`flex-1 truncate ${i === match.winner ? 'font-bold' : 'font-semibold'}`}>
                  {p.name}
                  {p.deck && <span className="font-normal text-muted"> · {p.deck}</span>}
                </span>
                {i === match.winner && '👑'}
                <span className="font-bold tabular-nums">{p.life}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </li>
  )
}

function Ranking({ title, rows, empty }) {
  return (
    <section className="rounded-2xl border border-line bg-surface p-5">
      <h2 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">{title}</h2>
      {!rows.length && <p className="text-sm text-muted">{empty}</p>}
      <ul className="space-y-2.5">
        {rows.map((s, k) => (
          <li key={s.name}>
            <div className="flex items-center gap-2">
              <span className="w-7">{['🥇', '🥈', '🥉'][k] ?? `${k + 1}.`}</span>
              <span className="flex-1 truncate font-bold">{s.name}</span>
              <span className="text-sm font-bold text-muted">
                {s.wins}/{s.played} · {Math.round(s.rate * 100)}%
              </span>
            </div>
            <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-card">
              <div className="h-full rounded-full bg-amber-400" style={{ width: `${s.rate * 100}%` }} />
            </div>
          </li>
        ))}
      </ul>
    </section>
  )
}

export default function MatchesPage() {
  const matches = useUserData((s) => s.matches?.list || [])
  const [tab, setTab] = useState('historico')
  const avg = averageDuration(matches)
  const rounds = matches.reduce((a, m) => Math.max(a, m.rounds || 0), 0)

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-8 flex flex-wrap items-center gap-2">
        <h1 className="mr-auto mb-4 w-full font-display sm:mb-0 sm:w-auto text-3xl font-bold tracking-wide sm:text-4xl">Partidas</h1>
        {['historico', 'estatisticas'].map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={`cursor-pointer rounded-lg px-4 py-2 text-sm font-medium ${tab === t ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`}
          >
            {t === 'historico' ? 'Histórico' : 'Estatísticas'}
          </button>
        ))}
        {matches.length > 0 && (
          <button
            type="button"
            onClick={() => window.confirm('Apagar todas as partidas (também no app)?') && clearMatches()}
            className="rounded-lg bg-danger/10 px-3 py-1.5 text-sm font-bold text-danger hover:bg-danger/20"
          >
            Apagar
          </button>
        )}
      </div>
      {!matches.length ? (
        <p className="rounded-2xl border border-line bg-surface p-5 text-center text-muted">Nenhuma partida ainda. Quando sobrar um jogador vivo no contador, a partida aparece aqui.</p>
      ) : tab === 'historico' ? (
        <ul className="space-y-3">
          {matches.map((m) => (
            <MatchCard key={m.id} match={m} />
          ))}
        </ul>
      ) : (
        <div className="space-y-4">
          <section className="grid grid-cols-3 gap-2 rounded-2xl border border-line bg-surface p-5 text-center shadow">
            <div>
              <div className="text-2xl font-bold">{matches.length}</div>
              <div className="text-xs text-muted">partidas</div>
            </div>
            <div>
              <div className="text-2xl font-bold">{avg ? duration(avg) : '—'}</div>
              <div className="text-xs text-muted">duração média</div>
            </div>
            <div>
              <div className="text-2xl font-bold">{rounds || '—'}</div>
              <div className="text-xs text-muted">mais rodadas</div>
            </div>
          </section>
          <Ranking title="Vitórias por jogador" rows={matchStats(matches)} empty="" />
          <Ranking
            title="Vitórias por deck / comandante"
            rows={matchStats(matches, { byDeck: true })}
            empty="Escolha o deck de cada jogador no contador (abra os contadores do jogador) para ver qual deck mais ganha."
          />
        </div>
      )}
    </div>
  )
}
