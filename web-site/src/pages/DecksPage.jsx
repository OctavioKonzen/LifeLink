import { useEffect, useMemo, useRef, useState } from 'react'
import CardImage from '../components/CardImage'
import CardDetails from '../components/CardDetails'
import ExpandingGrid from '../components/ExpandingGrid'
import { ErrorBox, Modal, Spinner } from '../components/ui'
import { coverIds, deck as loadDeck, deckCards, deckList, imageFor } from '../lib/mtgjson'
import { fromMtgjson } from '../lib/deckCards'
import { saveDeck } from '../lib/userData'
import { incrementCardsAdded, incrementDecksCreated } from '../lib/xp'

const CATEGORIES = ['Commander', 'Challenger', 'Secret Lair', 'Iniciante']

/** Capa com 3 cartas, carregada só quando o deck aparece na tela. */
function Cover({ fileName }) {
  const ref = useRef(null)
  const [ids, setIds] = useState(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return
      observer.disconnect()
      loadDeck(fileName).then((d) => setIds(coverIds(d)), () => setIds([]))
    }, { rootMargin: '200px' })
    observer.observe(el)
    return () => observer.disconnect()
  }, [fileName])
  const urls = [0, 1, 2].map((i) => imageFor(ids?.[i]))
  return (
    <div ref={ref} className="relative mx-auto h-36 w-32">
      <img src={urls[2] || undefined} alt="" className="absolute left-0 top-3 w-20 -rotate-10 rounded-md bg-black/30 shadow aspect-[488/680]" loading="lazy" />
      <img src={urls[1] || undefined} alt="" className="absolute right-0 top-3 w-20 rotate-10 rounded-md bg-black/30 shadow aspect-[488/680]" loading="lazy" />
      <img src={urls[0] || undefined} alt="" className="absolute left-1/2 top-0 w-[88px] -translate-x-1/2 rounded-md bg-black/40 shadow-lg aspect-[488/680]" loading="lazy" />
    </div>
  )
}

function DeckModal({ info, onClose }) {
  const [state, setState] = useState({ loading: true })
  useEffect(() => {
    loadDeck(info.fileName).then(
      (data) => setState({ loading: false, cards: deckCards(data) }),
      (e) => setState({ loading: false, error: e.message }),
    )
  }, [info.fileName])
  const total = state.cards?.reduce((n, c) => n + c.count, 0)
  const [saved, setSaved] = useState(false)
  // Igual ao "Salvar nos Meus Decks" do app: uma carta por cópia.
  const save = () => {
    const cards = state.cards.flatMap((c) =>
      Array.from({ length: c.count }, () => ({ ...fromMtgjson(c.item, imageFor(c.scryfallId) || ''), ...(c.board === 'commander' ? { commander: true } : {}) })),
    )
    const raw = (info.type || '').toLowerCase()
    const type = raw.includes('commander') ? 'Commander' : raw.includes('challenger') ? 'Challenger' : 'Normal'
    saveDeck({ id: String(Date.now()), name: info.name || 'Novo Deck', type, cards })
    incrementDecksCreated()
    incrementCardsAdded(cards.length)
    setSaved(true)
  }
  return (
    <Modal onClose={onClose} wide>
      <h2 className="pr-10 text-2xl font-black">{info.name}</h2>
      <p className="mb-4 text-sm text-muted">
        {info.type} · {info.releaseDate}
        {total ? ` · ${total} cartas` : ''}
      </p>
      {state.cards?.length > 0 && (
        <button
          type="button"
          disabled={saved}
          onClick={save}
          className="mb-4 rounded-full bg-emerald-600 px-4 py-2 text-sm font-bold hover:brightness-110 disabled:opacity-60"
        >
          {saved ? '✓ Salvo em Meus decks' : '+ Salvar nos Meus decks'}
        </button>
      )}
      {state.loading ? (
        <Spinner />
      ) : state.error ? (
        <ErrorBox message={state.error} />
      ) : (
        <ExpandingGrid
          items={state.cards}
          keyOf={(c) => `${c.board}-${c.name}`}
          minWidth={130}
          renderItem={(c, i, open, selected) => (
            <button
              type="button"
              onClick={() => c.scryfallId && open()}
              className={`relative block w-full rounded-[4.5%] text-left transition hover:scale-[1.03] ${selected ? 'ring-4 ring-accent' : ''}`}
              title={c.name}
            >
              <CardImage src={imageFor(c.scryfallId)} alt={c.name} />
              {c.count > 1 && (
                <span className="absolute right-1 top-1 rounded-full bg-black/80 px-2 text-xs font-black">{c.count}x</span>
              )}
            </button>
          )}
          renderPanel={(c, { close, previous, next }) => <CardDetails id={c.scryfallId} onClose={close} onPrevious={previous} onNext={next} />}
        />
      )}
    </Modal>
  )
}

export default function DecksPage() {
  const [state, setState] = useState({ loading: true })
  const [category, setCategory] = useState(0)
  const [text, setText] = useState('')
  const [open, setOpen] = useState(null)
  const [retry, setRetry] = useState(0)
  const [limit, setLimit] = useState(60)

  useEffect(() => {
    setState({ loading: true })
    deckList().then(
      (lists) => setState({ loading: false, lists }),
      (e) => setState({ loading: false, error: e.message }),
    )
  }, [retry])

  const shown = useMemo(() => {
    const list = state.lists?.[category] || []
    const q = text.trim().toLowerCase()
    return q ? list.filter((d) => d.name.toLowerCase().includes(q)) : list
  }, [state.lists, category, text])

  return (
    <div>
      <h1 className="mb-4 text-2xl font-black">Decks oficiais</h1>
      <input
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Pesquisar deck..."
        type="search"
        className="mb-3 w-full rounded-2xl border border-line bg-surface px-4 py-3 outline-none focus:border-accent"
      />
      <div className="mb-4 flex gap-2 overflow-x-auto">
        {CATEGORIES.map((name, i) => (
          <button
            key={name}
            type="button"
            onClick={() => {
              setCategory(i)
              setLimit(60)
            }}
            className={`whitespace-nowrap rounded-full px-5 py-2 text-sm font-bold ${category === i ? 'bg-accent' : 'bg-accent/10 text-accent'}`}
          >
            {name}
          </button>
        ))}
      </div>
      {state.loading ? (
        <Spinner />
      ) : state.error ? (
        <ErrorBox message={state.error} onRetry={() => setRetry((r) => r + 1)} />
      ) : shown.length === 0 ? (
        <p className="py-12 text-center text-muted">Nenhum deck encontrado.</p>
      ) : (
        <>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-4">
            {shown.slice(0, limit).map((d) => (
              <button
                key={d.fileName}
                type="button"
                onClick={() => setOpen(d)}
                className="rounded-2xl bg-card p-3 text-left shadow transition hover:scale-[1.02]"
              >
                <Cover fileName={d.fileName} />
                <div className="mt-3 truncate text-sm font-bold">{d.name}</div>
                <div className="text-xs text-muted">{d.releaseDate}</div>
              </button>
            ))}
          </div>
          {shown.length > limit && (
            <button
              type="button"
              onClick={() => setLimit((l) => l + 60)}
              className="mx-auto mt-6 block rounded-full bg-text/10 px-6 py-2 font-bold hover:bg-text/20"
            >
              Mostrar mais ({shown.length - limit})
            </button>
          )}
        </>
      )}
      {open && <DeckModal info={open} onClose={() => setOpen(null)} />}
    </div>
  )
}
