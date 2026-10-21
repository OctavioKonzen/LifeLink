import { useEffect, useState } from 'react'
import CardImage from './CardImage'
import { Modal, Spinner } from './ui'
import { FORMATS, deckProblems, dollarInReais, fetchDeckList, parseDeckList, priceOf, refreshDeck, shuffled } from '../lib/deckTools'

// Ferramentas de deck do site (as mesmas do app, deck_tools_screens.dart):
// importar lista, preço e legalidade, mão de teste.

const TYPES = ['Commander', 'Challenger', 'Normal']

/**
 * Importar lista (Moxfield, Archidekt, MTG Arena, MTGO). Com askName cria um
 * deck novo: onDone({ name, type, cards }); senão só onDone({ cards }).
 */
export function ImportListModal({ askName = false, onDone, onClose }) {
  const [name, setName] = useState('')
  const [type, setType] = useState('Commander')
  const [text, setText] = useState('')
  const [state, setState] = useState({ busy: false, error: null, missing: [] })

  const submit = async (e) => {
    e.preventDefault()
    const lines = parseDeckList(text)
    if (!lines.length) return setState({ busy: false, error: 'Nenhuma carta na lista.', missing: [] })
    setState({ busy: true, error: null, missing: [] })
    try {
      const { cards, missing } = await fetchDeckList(lines)
      if (!cards.length) return setState({ busy: false, error: 'Nenhuma carta encontrada.', missing })
      onDone({ name: name.trim() || 'Deck importado', type, cards, missing })
      if (missing.length) setState({ busy: false, error: null, missing })
      else onClose()
    } catch (err) {
      setState({ busy: false, error: err.message || 'Não deu para importar agora.', missing: [] })
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2 className="mb-1 text-xl font-black">Importar lista</h2>
      <p className="mb-3 text-sm text-muted">Cole a lista exportada do Moxfield, Archidekt, MTG Arena ou MTGO. Ex.: "1 Sol Ring (CMM) 410" ou "4x Lightning Bolt".</p>
      {state.missing.length > 0 ? (
        <div className="space-y-3">
          <p className="rounded-xl bg-amber-400/15 p-3 text-sm text-amber-300">Importado! Não encontrei: {state.missing.join(', ')}</p>
          <button type="button" onClick={onClose} className="w-full rounded-xl bg-accent py-3 font-bold">
            Pronto
          </button>
        </div>
      ) : (
        <form onSubmit={submit} className="flex flex-col gap-3">
          {askName && (
            <div className="flex gap-2">
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Nome do deck"
                className="min-w-0 flex-1 rounded-xl border border-line bg-card px-4 py-2.5 outline-none focus:border-accent"
              />
              <select value={type} onChange={(e) => setType(e.target.value)} className="rounded-xl border border-line bg-card px-3">
                {TYPES.map((t) => (
                  <option key={t}>{t}</option>
                ))}
              </select>
            </div>
          )}
          <textarea
            autoFocus
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={12}
            placeholder={"Commander\n1 Atraxa, Praetors' Voice\n\nDeck\n1 Sol Ring\n..."}
            className="rounded-xl border border-line bg-card px-4 py-3 font-mono text-sm outline-none focus:border-accent"
          />
          {state.error && <p className="text-sm text-red-400">{state.error}</p>}
          <button type="submit" disabled={state.busy} className="rounded-xl bg-accent py-3 font-bold hover:brightness-110 disabled:opacity-60">
            {state.busy ? 'Buscando as cartas...' : 'Importar'}
          </button>
        </form>
      )}
    </Modal>
  )
}

const COLORS = [
  ['W', 'Branco', '#F9FAF4'],
  ['U', 'Azul', '#0E68AB'],
  ['B', 'Preto', '#6B5E5E'],
  ['R', 'Vermelho', '#D3202A'],
  ['G', 'Verde', '#00733E'],
]

/** Curva de mana (sem os terrenos) e quanto de cada cor aparece nos custos. */
export function ManaCurve({ cards }) {
  const curve = Array(8).fill(0)
  const colors = {}
  let lands = 0
  for (const c of cards) {
    if (/Land|Terreno/.test(c.type_line || '')) {
      lands++
      continue
    }
    curve[Math.min(7, Math.max(0, Math.round(Number(c.cmc) || 0)))]++
    for (const [k] of COLORS) {
      const n = ((c.mana_cost || '').match(new RegExp(`\\{[^}]*${k}[^}]*\\}`, 'g')) || []).length
      if (n) colors[k] = (colors[k] || 0) + n
    }
  }
  const top = Math.max(1, ...curve)
  const spells = curve.reduce((a, b) => a + b, 0)
  const avg = spells ? curve.reduce((a, n, i) => a + n * i, 0) / spells : 0
  const total = Object.values(colors).reduce((a, b) => a + b, 0)
  return (
    <section className="rounded-2xl bg-text/5 p-4 md:col-span-2">
      <h3 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Curva de mana e cores</h3>
      <div className="flex h-28 items-end gap-2">
        {curve.map((n, i) => (
          <div key={i} className="flex flex-1 flex-col items-center justify-end">
            <span className="text-xs font-bold text-muted">{n}</span>
            <div className="w-full rounded bg-accent" style={{ height: `${(70 * n) / top}px` }} />
            <span className="mt-1 text-sm font-black">{i === 7 ? '7+' : i}</span>
          </div>
        ))}
      </div>
      <p className="mt-2 text-sm text-muted">
        {spells} mágicas · {lands} terrenos · custo médio {avg.toFixed(2)}
      </p>
      {total > 0 && (
        <>
          <div className="mt-3 flex h-3.5 overflow-hidden rounded-md">
            {COLORS.filter(([k]) => colors[k]).map(([k, , hex]) => (
              <div key={k} style={{ flex: colors[k], background: hex }} />
            ))}
          </div>
          <p className="mt-1 text-sm text-muted">
            {COLORS.filter(([k]) => colors[k])
              .map(([k, name]) => `${name} ${Math.round((100 * colors[k]) / total)}%`)
              .join(' · ')}
          </p>
        </>
      )}
    </section>
  )
}

/** Preço de hoje (dólar, real e euro) e legalidade em cada formato. */
export function DeckAnalysis({ deck }) {
  const [state, setState] = useState({ loading: true, error: null, cards: [], brl: null })
  useEffect(() => {
    let alive = true
    Promise.all([refreshDeck(deck.cards), dollarInReais()])
      .then(([cards, brl]) => alive && setState({ loading: false, error: null, cards, brl }))
      .catch((e) => alive && setState({ loading: false, error: e.message || 'Não deu para buscar as cartas agora.', cards: [], brl: null }))
    return () => {
      alive = false
    }
  }, [deck])
  if (state.loading) return <Spinner />
  if (state.error) return <p className="py-6 text-center text-red-400">{state.error}</p>
  const { cards, brl } = state
  const usd = cards.reduce((a, c) => a + priceOf(c), 0)
  const eur = cards.reduce((a, c) => a + (Number.parseFloat(c.prices?.eur) || 0), 0)
  const grouped = new Map()
  for (const c of cards) {
    const name = c.printed_name || c.name
    const g = grouped.get(name) || { card: c, qty: 0 }
    g.qty++
    grouped.set(name, g)
  }
  const top = [...grouped.entries()].sort((a, b) => priceOf(b[1].card) * b[1].qty - priceOf(a[1].card) * a[1].qty).slice(0, 8)
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <ManaCurve cards={deck.cards} />
      <section className="rounded-2xl bg-text/5 p-4">
        <h3 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Preço de hoje (Scryfall)</h3>
        <p className="text-3xl font-black">US$ {usd.toFixed(2)}</p>
        {brl && (
          <p className="text-lg font-bold text-emerald-400">
            ≈ R$ {(usd * brl).toFixed(2)} <span className="text-sm font-normal text-muted">(dólar a R$ {brl.toFixed(2)})</span>
          </p>
        )}
        {eur > 0 && <p className="font-semibold text-muted">€ {eur.toFixed(2)}</p>}
        <h4 className="mt-3 text-xs font-bold uppercase text-muted">As mais caras</h4>
        <ul className="mt-1 space-y-0.5 text-sm">
          {top.map(([name, { card, qty }]) => (
            <li key={name} className="flex justify-between gap-2">
              <span className="truncate">
                {qty}× {name}
              </span>
              <span className="font-bold">US$ {(priceOf(card) * qty).toFixed(2)}</span>
            </li>
          ))}
        </ul>
      </section>
      <section className="rounded-2xl bg-text/5 p-4">
        <h3 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Legalidade</h3>
        <ul className="space-y-1">
          {Object.entries(FORMATS).map(([key, label]) => {
            const problems = deckProblems(key, cards)
            return (
              <li key={key}>
                <details>
                  <summary className="flex cursor-pointer items-center gap-2 font-bold">
                    <span>{problems.length ? '❌' : '✅'}</span>
                    <span className="flex-1">{label}</span>
                    <span className="text-sm font-normal text-muted">{problems.length ? `${problems.length} problema${problems.length > 1 ? 's' : ''}` : 'Legal'}</span>
                  </summary>
                  {problems.length > 0 && (
                    <ul className="ml-7 mt-1 list-disc text-sm text-muted">
                      {problems.slice(0, 40).map((p) => (
                        <li key={p}>{p}</li>
                      ))}
                    </ul>
                  )}
                </details>
              </li>
            )
          })}
        </ul>
      </section>
    </div>
  )
}

/** Mão de teste: 7 cartas, mulligan de Londres (põe uma no fundo por mulligan) e comprar mais. */
export function TestHand({ deck }) {
  const deal = (mulligans) => {
    const library = shuffled(deck.cards)
    return { hand: library.slice(0, 7), library: library.slice(7), mulligans, toBottom: mulligans, turn: 1 }
  }
  const [s, setS] = useState(() => deal(0))
  if (deck.cards.length < 7) return <p className="py-6 text-center text-muted">O deck precisa de pelo menos 7 cartas.</p>
  const lands = s.hand.filter((c) => /Land|Terreno/.test(c.type_line || '')).length
  const toBottom = (i) =>
    s.toBottom > 0 && setS({ ...s, hand: s.hand.filter((_, k) => k !== i), library: [...s.library, s.hand[i]], toBottom: s.toBottom - 1 })
  const draw = () => s.library.length && !s.toBottom && setS({ ...s, hand: [...s.hand, s.library[0]], library: s.library.slice(1), turn: s.turn + 1 })
  return (
    <div>
      <p className={`mb-3 text-center font-bold ${s.toBottom ? 'text-amber-400' : 'text-muted'}`}>
        {s.toBottom
          ? `Mulligan ${s.mulligans}: clique em ${s.toBottom} carta${s.toBottom > 1 ? 's' : ''} para pôr no fundo do grimório.`
          : `${s.hand.length} cartas na mão · ${lands} terreno${lands === 1 ? '' : 's'} · ${s.library.length} no grimório${s.turn > 1 ? ` · turno ${s.turn}` : ''}`}
      </p>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
        {s.hand.map((c, i) => (
          <button
            key={`${i}-${c.name}`}
            type="button"
            onClick={() => toBottom(i)}
            className={`block rounded-[4.5%] transition ${s.toBottom ? 'ring-2 ring-amber-400 hover:scale-[1.03]' : 'cursor-default'}`}
            title={c.name}
          >
            <CardImage src={c.imageUrl} alt={c.name} eager />
          </button>
        ))}
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        <button type="button" onClick={() => setS(deal(0))} className="flex-1 rounded-full bg-text/10 py-2.5 font-bold hover:bg-text/20">
          🔀 Nova mão
        </button>
        <button
          type="button"
          disabled={s.mulligans >= 6}
          onClick={() => setS(deal(s.mulligans + 1))}
          className="flex-1 rounded-full bg-text/10 py-2.5 font-bold hover:bg-text/20 disabled:opacity-40"
        >
          ↺ Mulligan
        </button>
        <button
          type="button"
          disabled={!!s.toBottom || !s.library.length}
          onClick={draw}
          className="flex-1 rounded-full bg-accent py-2.5 font-bold text-white hover:brightness-110 disabled:opacity-40"
        >
          + Comprar
        </button>
      </div>
    </div>
  )
}
