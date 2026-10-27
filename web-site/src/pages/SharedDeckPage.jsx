import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Check, ClipboardCopy, Crown, Save } from 'lucide-react'
import CardImage from '../components/CardImage'
import { ErrorBox, PageHeader, Spinner, btnPrimary, btnSecondary } from '../components/ui'
import { fetchDeckList, parseDeckList } from '../lib/deckTools'
import { decodeDeck } from '../lib/shareDeck'
import { saveDeck } from '../lib/userData'
import { incrementCardsAdded } from '../lib/xp'
import { createDeck } from './MyDecksPage'

/** Um deck que alguém compartilhou pelo link (#/d/<código>): ver e salvar nos meus decks. */
export default function SharedDeckPage() {
  const { code } = useParams()
  const [state, setState] = useState({ loading: true, error: null, deck: null, cards: [], missing: [] })
  const [saved, setSaved] = useState(false)
  const [copied, setCopied] = useState(false)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    let alive = true
    setState({ loading: true, error: null, deck: null, cards: [], missing: [] })
    setSaved(false)
    ;(async () => {
      let deck
      try {
        deck = await decodeDeck(code)
      } catch {
        throw new Error('Esse link de deck não abriu. Confira se ele veio inteiro.')
      }
      const { cards, missing } = await fetchDeckList(parseDeckList(deck.list))
      return { deck, cards, missing }
    })()
      .then((r) => alive && setState({ loading: false, error: null, ...r }))
      .catch((e) => alive && setState({ loading: false, error: e.message || 'Não deu para abrir o deck agora.', deck: null, cards: [], missing: [] }))
    return () => {
      alive = false
    }
  }, [code, retry])

  if (state.loading) return <Spinner />
  if (state.error) return <ErrorBox message={state.error} onRetry={() => setRetry((r) => r + 1)} />

  const { deck, cards, missing } = state
  // Uma por carta, com a quantidade (o comandante primeiro).
  const groups = []
  for (const c of cards) {
    const g = groups.find((x) => x.c.name === c.name && Boolean(x.c.commander) === Boolean(c.commander))
    if (g) g.n++
    else groups.push({ c, n: 1 })
  }
  groups.sort((a, b) => Number(Boolean(b.c.commander)) - Number(Boolean(a.c.commander)))

  const save = () => {
    const created = createDeck(deck.name, deck.type)
    saveDeck({ ...created, cards })
    incrementCardsAdded(cards.length)
    setSaved(true)
  }
  const copy = () => navigator.clipboard?.writeText(deck.list).then(() => setCopied(true), () => {})

  return (
    <div>
      <PageHeader
        title={deck.name}
        description={`Deck compartilhado · ${deck.type} · ${cards.length} cartas`}
        action={
          <div className="flex flex-wrap gap-2">
            {saved ? (
              <Link to="/meus-decks" className={btnPrimary}>
                <Check className="size-4" aria-hidden="true" /> Salvo! Ver meus decks
              </Link>
            ) : (
              <button type="button" onClick={save} className={btnPrimary}>
                <Save className="size-4" aria-hidden="true" /> Salvar em meus decks
              </button>
            )}
            <button type="button" onClick={copy} className={btnSecondary}>
              <ClipboardCopy className="size-4" aria-hidden="true" /> {copied ? 'Lista copiada' : 'Copiar lista'}
            </button>
          </div>
        }
      />
      {missing.length > 0 && <p className="mb-4 rounded-xl bg-amber-400/15 p-3 text-sm text-amber-300">Não encontrei: {missing.join(', ')}</p>}
      <div className="grid grid-cols-[repeat(auto-fill,minmax(130px,1fr))] gap-4">
        {groups.map(({ c, n }) => (
          <div key={`${c.commander ? 'c' : ''}${c.name}`} className="relative">
            <CardImage src={c.imageUrl} alt={c.name} className="shadow-xl shadow-black/50" />
            {n > 1 && <span className="absolute right-1.5 top-1.5 rounded-full bg-black/80 px-2 py-0.5 text-sm font-bold text-white">{n}x</span>}
            {c.commander && (
              <span className="absolute left-1.5 top-1.5 grid size-7 place-items-center rounded-full bg-accent text-on-accent" title="Comandante">
                <Crown className="size-4" aria-hidden="true" />
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
