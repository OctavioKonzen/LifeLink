import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { codeFromLink, decodeDeck, deckLink, encodeDeck } from '../lib/shareDeck'
import CardImage from './CardImage'
import { Modal, Spinner } from './ui'
import { missingFor } from '../lib/collection'
import { saveDeck, useUserData } from '../lib/userData'
import { toDeckCard } from '../lib/deckCards'
import { imageOf } from '../lib/scryfall'
import { incrementCardsAdded } from '../lib/xp'
import {
  BRACKET_NAMES,
  FORMATS,
  bracket,
  deckProblems,
  dollarInReais,
  englishNames,
  exportList,
  fetchDeckList,
  parseDeckList,
  priceOf,
  refreshDeck,
  shuffled,
  suggestions,
} from '../lib/deckTools'

// Ferramentas de deck do site (as mesmas do app, deck_tools_screens.dart):
// importar lista, preço, legalidade e nível, mão de teste e simulação,
// sugestões para o comandante, exportar.

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
    // Um link de deck do LifeLink: a lista (e o nome) vêm de dentro dele.
    let list = text
    let shared = null
    const code = codeFromLink(text)
    if (code) {
      try {
        shared = await decodeDeck(code)
        list = shared.list
      } catch {
        return setState({ busy: false, error: 'Esse link de deck não abriu. Confira se copiou inteiro.', missing: [] })
      }
    }
    const lines = parseDeckList(list)
    if (!lines.length) return setState({ busy: false, error: 'Nenhuma carta na lista.', missing: [] })
    setState({ busy: true, error: null, missing: [] })
    try {
      const { cards, missing } = await fetchDeckList(lines)
      if (!cards.length) return setState({ busy: false, error: 'Nenhuma carta encontrada.', missing })
      onDone({ name: name.trim() || shared?.name || 'Deck importado', type: shared && !name.trim() ? shared.type : type, cards, missing })
      if (missing.length) setState({ busy: false, error: null, missing })
      else onClose()
    } catch (err) {
      setState({ busy: false, error: err.message || 'Não deu para importar agora.', missing: [] })
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2 className="mb-1 text-xl font-bold">Importar lista</h2>
      <p className="mb-3 text-sm text-muted">Cole a lista exportada do Moxfield, Archidekt, MTG Arena ou MTGO (ex.: "1 Sol Ring (CMM) 410" ou "4x Lightning Bolt") ou um link de deck do LifeLink.</p>
      {state.missing.length > 0 ? (
        <div className="space-y-3">
          <p className="rounded-xl bg-amber-400/15 p-3 text-sm text-amber-300">Importado! Não encontrei: {state.missing.join(', ')}</p>
          <button type="button" onClick={onClose} className="w-full rounded-xl bg-accent text-on-accent py-3 font-bold">
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
                className="min-w-0 flex-1 h-11 rounded-lg border border-line bg-surface px-3.5 text-sm outline-none placeholder:text-muted/70 focus:border-accent"
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
          {state.error && <p className="text-sm text-danger">{state.error}</p>}
          <button type="submit" disabled={state.busy} className="rounded-xl bg-accent text-on-accent py-3 font-bold hover:brightness-110 disabled:opacity-60">
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
    <section className="rounded-2xl bg-bg p-4 md:col-span-2">
      <h3 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Curva de mana e cores</h3>
      <div className="flex h-28 items-end gap-2">
        {curve.map((n, i) => (
          <div key={i} className="flex flex-1 flex-col items-center justify-end">
            <span className="text-xs font-bold text-muted">{n}</span>
            <div className="w-full rounded bg-accent text-on-accent" style={{ height: `${(70 * n) / top}px` }} />
            <span className="mt-1 text-sm font-bold">{i === 7 ? '7+' : i}</span>
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

const BRACKET_TEXT = {
  2: 'Sem Game Changers, turnos extras nem destruição de terrenos. Se for um deck temático bem leve, pode ser o 1.',
  3: 'Até 3 Game Changers e nada de destruição de terrenos em massa.',
  4: 'Mais de 3 Game Changers, destruição de terrenos em massa ou vários turnos extras. Se for feito para vencer o mais rápido possível, é o 5 (cEDH).',
}

/** O nível do deck (Bracket do Commander) e o porquê. cards: atualizadas na Scryfall. */
function BracketSection({ cards }) {
  const b = bracket(cards)
  const list = (title, names, color) =>
    names.length > 0 && (
      <p className={`mt-2 text-sm ${color}`}>
        {title} ({names.length}): {names.join(', ')}
      </p>
    )
  return (
    <section className="rounded-2xl bg-bg p-4 md:col-span-2">
      <h3 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Nível do deck (Bracket)</h3>
      <div className="flex items-center gap-3">
        <span className="grid h-13 w-13 shrink-0 place-items-center rounded-2xl bg-violet-700 text-3xl font-bold text-white">{b.bracket}</span>
        <div>
          <p className="text-lg font-bold">
            Bracket {b.bracket}: {BRACKET_NAMES[b.bracket]}
          </p>
          <p className="text-sm text-muted">{BRACKET_TEXT[b.bracket]}</p>
        </div>
      </div>
      {list('Game Changers', b.gameChangers, 'text-amber-400')}
      {list('Turnos extras', b.extraTurns, 'text-sky-400')}
      {list('Destruição de terrenos em massa', b.landDestruction, 'text-danger')}
      <p className="mt-2 text-xs text-muted">Combos de duas cartas não entram na conta: confira com a mesa.</p>
    </section>
  )
}

/** Preço de hoje (dólar, real e euro), legalidade em cada formato e, no Commander, o nível. */
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
  if (state.error) return <p className="py-6 text-center text-danger">{state.error}</p>
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
      {deck.type === 'Commander' && <BracketSection cards={cards} />}
      <section className="rounded-2xl bg-bg p-4">
        <h3 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Preço de hoje (Scryfall)</h3>
        <p className="text-3xl font-bold">US$ {usd.toFixed(2)}</p>
        {brl && (
          <p className="text-lg font-bold text-success">
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
      <section className="rounded-2xl bg-bg p-4">
        <h3 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Legalidade</h3>
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

const isLand = (c) => /Land|Terreno/.test(c.type_line || '')

/** Uma fileira de cartas pequenas (em jogo e zona de comando). */
function Strip({ title, cards, onPick }) {
  return (
    <div className="mb-3">
      <p className="mb-1 text-xs font-medium uppercase tracking-widest text-muted">{title}</p>
      <div className="flex gap-2 overflow-x-auto pb-1">
        {cards.map((c, i) => (
          <button key={`${i}-${c.name}`} type="button" onClick={() => onPick(i)} className="block w-16 shrink-0 rounded-[4.5%] transition hover:scale-[1.05]" title={c.name}>
            <CardImage src={c.imageUrl} alt={c.name} eager />
          </button>
        ))}
      </div>
    </div>
  )
}

/**
 * Mão de teste e simulação: 7 cartas, mulligan de Londres (põe uma no fundo
 * por mulligan), jogar cartas (um terreno por turno), o comandante na zona
 * de comando e os turnos (compra uma a cada turno).
 */
export function TestHand({ deck }) {
  const deal = (mulligans) => {
    const library = shuffled(deck.cards.filter((c) => !c.commander))
    return {
      hand: library.slice(0, 7),
      library: library.slice(7),
      battlefield: [],
      command: deck.cards.filter((c) => c.commander),
      mulligans,
      toBottom: mulligans,
      turn: 1,
      landPlayed: false,
      msg: '',
    }
  }
  const [s, setS] = useState(() => deal(0))
  if (deck.cards.length < 7) return <p className="py-6 text-center text-muted">O deck precisa de pelo menos 7 cartas.</p>
  const lands = s.hand.filter(isLand).length
  const mana = s.battlefield.filter(isLand).length
  // Clicar numa carta da mão: no mulligan vai para o fundo; depois, joga.
  const tap = (i) => {
    const card = s.hand[i]
    const hand = s.hand.filter((_, k) => k !== i)
    if (s.toBottom > 0) return setS({ ...s, hand, library: [...s.library, card], toBottom: s.toBottom - 1 })
    if (isLand(card) && s.landPlayed) return setS({ ...s, msg: 'Já jogou um terreno neste turno.' })
    setS({ ...s, hand, battlefield: [...s.battlefield, card], landPlayed: s.landPlayed || isLand(card), msg: '' })
  }
  // Clicar numa carta em jogo: volta para a mão (o comandante, para a zona de comando).
  const back = (i) => {
    const card = s.battlefield[i]
    const battlefield = s.battlefield.filter((_, k) => k !== i)
    if (card.commander) return setS({ ...s, battlefield, command: [...s.command, card], msg: '' })
    setS({ ...s, battlefield, hand: [...s.hand, card], landPlayed: isLand(card) ? false : s.landPlayed, msg: '' })
  }
  const cast = (i) => !s.toBottom && setS({ ...s, command: s.command.filter((_, k) => k !== i), battlefield: [...s.battlefield, s.command[i]], msg: '' })
  const draw = () => s.library.length && !s.toBottom && setS({ ...s, hand: [...s.hand, s.library[0]], library: s.library.slice(1), msg: '' })
  const nextTurn = () =>
    !s.toBottom &&
    setS({ ...s, turn: s.turn + 1, landPlayed: false, hand: s.library.length ? [...s.hand, s.library[0]] : s.hand, library: s.library.slice(1), msg: '' })
  return (
    <div>
      <p className={`mb-3 text-center font-bold ${s.toBottom ? 'text-amber-400' : 'text-muted'}`}>
        {s.toBottom ? (
          `Mulligan ${s.mulligans}: clique em ${s.toBottom} carta${s.toBottom > 1 ? 's' : ''} para pôr no fundo do grimório.`
        ) : (
          <>
            Turno {s.turn} · {s.hand.length} na mão ({lands} terreno{lands === 1 ? '' : 's'}) · {mana} de mana em jogo · {s.library.length} no grimório
            <span className="block text-xs font-normal">Clique numa carta da mão para jogar (um terreno por turno).</span>
          </>
        )}
      </p>
      {s.msg && <p className="mb-3 text-center text-sm font-bold text-amber-400">{s.msg}</p>}
      {s.command.length > 0 && <Strip title="Zona de comando (clique para jogar)" cards={s.command} onPick={cast} />}
      {s.battlefield.length > 0 && <Strip title={`Em jogo (${s.battlefield.length}) · clique para voltar para a mão`} cards={s.battlefield} onPick={back} />}
      <div className="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
        {s.hand.map((c, i) => (
          <button
            key={`${i}-${c.name}`}
            type="button"
            onClick={() => tap(i)}
            className={`block rounded-[4.5%] transition hover:scale-[1.03] ${s.toBottom ? 'ring-2 ring-amber-400' : ''}`}
            title={c.name}
          >
            <CardImage src={c.imageUrl} alt={c.name} eager />
          </button>
        ))}
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        <button type="button" onClick={() => setS(deal(0))} className="flex-1 rounded-lg bg-card py-2.5 font-bold hover:brightness-125">
          🔀 Nova mão
        </button>
        <button
          type="button"
          disabled={s.mulligans >= 6 || s.turn > 1 || s.battlefield.length > 0}
          onClick={() => setS(deal(s.mulligans + 1))}
          className="flex-1 rounded-lg bg-card py-2.5 font-bold hover:brightness-125 disabled:opacity-40"
        >
          ↺ Mulligan
        </button>
        <button
          type="button"
          disabled={!!s.toBottom || !s.library.length}
          onClick={draw}
          className="flex-1 rounded-lg bg-card py-2.5 font-bold hover:brightness-125 disabled:opacity-40"
        >
          + Comprar 1
        </button>
        <button
          type="button"
          disabled={!!s.toBottom}
          onClick={nextTurn}
          className="flex-1 rounded-lg bg-accent py-2.5 font-bold text-on-accent hover:brightness-110 disabled:opacity-40"
        >
          ⏭ Próximo turno
        </button>
      </div>
    </div>
  )
}

/**
 * Sugestões de cartas para o comandante do deck (EDHREC ou, se não der, as
 * mais populares nas cores dele), com o "+" para pôr no deck.
 */
export function Suggestions({ deck }) {
  const [state, setState] = useState({ loading: true, error: null, cards: [], source: '' })
  const [added, setAdded] = useState(() => new Set())
  const [attempt, setAttempt] = useState(0)
  // O deck muda a cada "+": as sugestões ficam as mesmas até "Tentar de novo".
  const [cards] = useState(deck.cards)
  useEffect(() => {
    let alive = true
    const load = async () => {
      const commanders = cards.filter((c) => c.commander)
      if (!commanders.length) return { error: 'Marque o comandante do deck primeiro (no app: segure a carta no deck → "Marcar como comandante"; ou importe a lista com a seção "Commander").' }
      // Os nomes em inglês (o deck pode estar traduzido).
      const fresh = await refreshDeck(cards)
      const commander = fresh[cards.indexOf(commanders[0])] || commanders[0]
      const result = await suggestions(commander, fresh)
      return result.cards.length ? result : { error: 'Não achei sugestões para este comandante.' }
    }
    load()
      .then((r) => alive && setState({ loading: false, error: r.error || null, cards: r.cards || [], source: r.source || '' }))
      .catch((e) => alive && setState({ loading: false, error: e.message || 'Não deu para buscar as sugestões agora. Verifique a internet.', cards: [], source: '' }))
    return () => {
      alive = false
    }
  }, [cards, attempt])
  const add = (card) => {
    saveDeck({ ...deck, cards: [...deck.cards, toDeckCard(card)] })
    incrementCardsAdded(1)
    setAdded(new Set([...added, card.id]))
  }
  if (state.loading) return <div className="grid place-items-center py-6"><Spinner /></div>
  if (state.error)
    return (
      <div className="py-4 text-center">
        <p className="mb-3">{state.error}</p>
        <button
          type="button"
          onClick={() => {
            setState({ loading: true, error: null, cards: [], source: '' })
            setAttempt(attempt + 1)
          }}
          className="rounded-lg bg-accent px-4 py-1.5 text-sm font-bold text-on-accent"
        >
          Tentar de novo
        </button>
      </div>
    )
  return (
    <div>
      <p className="mb-3 text-sm text-muted">As cartas mais usadas com este comandante (fonte: {state.source}). Clique no + para pôr no deck.</p>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
        {state.cards.map((c) => {
          const done = added.has(c.id)
          return (
            <div key={c.id}>
              <CardImage src={imageOf(c, 'normal')} alt={c.name} />
              <div className="mt-1 flex items-center justify-between gap-1">
                <span className="text-xs font-bold text-muted">US$ {priceOf(c).toFixed(2)}</span>
                <button
                  type="button"
                  disabled={done}
                  onClick={() => add(c)}
                  aria-label={`Pôr ${c.name} no deck`}
                  title="Pôr no deck"
                  className={`grid h-7 w-7 place-items-center rounded-full text-sm font-bold ${done ? 'bg-success text-white' : 'bg-amber-400 text-black hover:brightness-110'}`}
                >
                  {done ? '✓' : '+'}
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

/** Exportar o deck: a lista (nomes em inglês) para copiar ou compartilhar (WhatsApp...). */
export function ExportDeck({ deck }) {
  const [text, setText] = useState(null)
  const [done, setDone] = useState('')
  const [link, setLink] = useState('')
  const [qr, setQr] = useState('')
  useEffect(() => {
    let alive = true
    englishNames(deck.cards).then((names) => alive && setText(exportList(deck.cards, names)))
    return () => {
      alive = false
    }
  }, [deck])
  // O link do deck (o deck vai dentro do link) e o QR code dele.
  useEffect(() => {
    if (text == null) return
    let alive = true
    encodeDeck({ name: deck.name, type: deck.type, list: text })
      .then((code) => {
        const url = deckLink(code)
        if (!alive) return
        setLink(url)
        return QRCode.toDataURL(url, { errorCorrectionLevel: 'L', margin: 1, width: 360 }).then((img) => alive && setQr(img))
      })
      .catch(() => {})
    return () => {
      alive = false
    }
  }, [text, deck.name, deck.type])
  if (text == null) return <div className="grid place-items-center py-6"><Spinner /></div>
  const copy = (value, message) => navigator.clipboard?.writeText(value).then(() => setDone(message), () => setDone('Não deu para copiar: selecione o texto.'))
  const share = () => navigator.share({ title: deck.name, text: `${deck.name}\n\n${text}` }).catch(() => {})
  const whatsapp = `https://wa.me/?text=${encodeURIComponent(`${deck.name}\n\n${text}`)}`
  return (
    <div>
      {link && (
        <div className="mb-5 flex flex-col gap-4 rounded-2xl border border-line bg-bg p-4 sm:flex-row sm:items-center">
          {qr && <img src={qr} alt="QR code do deck" className="mx-auto size-40 rounded-lg bg-white p-1 sm:mx-0" />}
          <div className="min-w-0 flex-1">
            <p className="font-semibold">Link do deck</p>
            <p className="mb-2 text-sm text-muted">Quem abrir o link (ou ler o QR code com a câmera) vê o deck e salva nos decks dele.</p>
            <div className="flex flex-wrap gap-2">
              <button type="button" onClick={() => copy(link, 'Link copiado.')} className="rounded-lg bg-accent px-4 py-1.5 text-sm font-bold text-on-accent hover:brightness-110">🔗 Copiar link</button>
              <a href={`https://wa.me/?text=${encodeURIComponent(`${deck.name}: ${link}`)}`} target="_blank" rel="noreferrer" className="rounded-lg bg-success px-4 py-1.5 text-sm font-bold text-white hover:brightness-110">WhatsApp</a>
            </div>
          </div>
        </div>
      )}
      <p className="mb-2 text-sm text-muted">A lista no formato do Moxfield, Arena e Archidekt (nomes em inglês).</p>
      <textarea readOnly value={text} rows={10} className="w-full rounded-xl bg-black/20 p-3 font-mono text-sm" onFocus={(e) => e.target.select()} />
      <div className="mt-2 flex flex-wrap gap-2">
        <button type="button" onClick={() => copy(text, 'Lista copiada.')} className="rounded-lg bg-card px-4 py-1.5 text-sm font-bold hover:brightness-125">📋 Copiar</button>
        {typeof navigator !== 'undefined' && navigator.share && (
          <button type="button" onClick={share} className="rounded-lg bg-card px-4 py-1.5 text-sm font-bold hover:brightness-125">📤 Compartilhar</button>
        )}
        <a href={whatsapp} target="_blank" rel="noreferrer" className="rounded-lg bg-success px-4 py-1.5 text-sm font-bold text-white hover:brightness-110">WhatsApp</a>
        {done && <span className="self-center text-sm font-bold text-success">{done}</span>}
      </div>
    </div>
  )
}

/** O que falta na coleção para montar o deck, com o custo. */
export function MissingCards({ deck }) {
  const collection = useUserData((s) => s.collection)
  const [brl, setBrl] = useState(null)
  useEffect(() => {
    dollarInReais().then(setBrl, () => {})
  }, [])
  const missing = missingFor(deck.cards, collection)
  const cost = missing.reduce((a, m) => a + m.usd * (m.need - m.have), 0)
  if (!missing.length) return <p className="py-4 text-center font-bold text-success">Você tem todas as cartas deste deck!</p>
  return (
    <div>
      <p className="mb-2 text-sm text-muted">
        {missing.length} carta(s) · US$ {cost.toFixed(2)}
        {brl ? ` · R$ ${(cost * brl).toFixed(2)}` : ''}. Terrenos básicos não contam; qualquer versão da carta serve.
      </p>
      <ul className="divide-y divide-text/10">
        {missing.map((m) => (
          <li key={m.name} className="flex items-center justify-between gap-3 py-1.5 text-sm">
            <span className="min-w-0 truncate font-semibold">{m.name}</span>
            <span className="shrink-0 text-muted">
              tenho {m.have} de {m.need} · <span className="font-bold text-amber-400">US$ {(m.usd * (m.need - m.have)).toFixed(2)}</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
