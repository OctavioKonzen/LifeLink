import { useEffect, useState } from 'react'
import { Spinner } from './ui'
import { ManaText } from './Mana'
import CardImage from './CardImage'
import {
  RARITY_COLORS,
  backImageOf,
  cardById,
  displayName,
  getJson,
  imageOf,
  manaCost,
  oracleText,
  search,
  typeLine,
} from '../lib/scryfall'
import { toDeckCard } from '../lib/deckCards'
import { deckList, saveDeck, useUserData } from '../lib/userData'
import { incrementArtsViewed, incrementCardsAdded } from '../lib/xp'
import { addToCollection, qtyOf, setQty, toggleWish, wished } from '../lib/collection'

const LANGS = [
  ['pt', 'Português'],
  ['en', 'English'],
  ['ja', '日本語'],
  ['es', 'Español'],
  ['fr', 'Français'],
  ['de', 'Deutsch'],
  ['it', 'Italiano'],
]

const FORMATS = [
  ['commander', 'Commander'],
  ['standard', 'Standard'],
  ['pioneer', 'Pioneer'],
  ['modern', 'Modern'],
  ['legacy', 'Legacy'],
  ['vintage', 'Vintage'],
  ['pauper', 'Pauper'],
]

const LEGALITY = {
  legal: ['Legal', 'bg-emerald-600'],
  restricted: ['Restrita', 'bg-sky-600'],
  banned: ['Banida', 'bg-red-600'],
  not_legal: ['Não', 'bg-text/10 text-text/50'],
}

/**
 * Imagem em PNG (melhor qualidade do Scryfall). Enquanto ela carrega, aparece
 * a "normal", que já veio da lista e está no cache do navegador.
 */
function BestImage({ card, back }) {
  const normal = back ? backImageOf(card, 'normal') : imageOf(card, 'normal')
  const png = back ? backImageOf(card, 'png') : imageOf(card, 'png')
  const [loaded, setLoaded] = useState(false)
  return (
    <div className="relative">
      <CardImage src={normal} alt={displayName(card)} eager />
      {png && (
        <img
          src={png}
          alt=""
          onLoad={() => setLoaded(true)}
          className={`absolute inset-0 aspect-[488/680] w-full rounded-[4.5%] object-cover transition-opacity duration-200 ${loaded ? 'opacity-100' : 'opacity-0'}`}
        />
      )}
    </div>
  )
}

function Price({ label, value, prefix }) {
  if (!value) return null
  return (
    <div className="rounded-xl bg-text/5 px-3 py-2">
      <div className="text-xs text-muted">{label}</div>
      <div className="text-lg font-black text-emerald-400">
        {prefix} {value}
      </div>
    </div>
  )
}

function Versions({ card, onPick }) {
  const [lang, setLang] = useState(card.lang === 'en' ? 'pt' : card.lang || 'pt')
  const [state, setState] = useState({ loading: true, cards: [] })

  useEffect(() => {
    let alive = true
    const q = card.oracle_id ? `oracleid:${card.oracle_id} lang:${lang}` : `!"${card.name}" lang:${lang}`
    setState({ loading: true, cards: [] })
    search(q, { order: 'released', unique: 'prints', multilingual: false })
      .then((page) => alive && setState({ loading: false, cards: page.cards.filter((c) => imageOf(c, 'small')) }))
      .catch((e) => alive && setState({ loading: false, cards: [], error: e.message }))
    return () => {
      alive = false
    }
  }, [card.oracle_id, card.name, lang])

  return (
    <section className="mt-6 xl:mt-0">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h3 className="text-lg font-bold">Outras versões</h3>
        <select
          value={lang}
          onChange={(e) => setLang(e.target.value)}
          className="rounded-lg border border-line bg-card px-2 py-1 text-sm"
        >
          {LANGS.map(([code, name]) => (
            <option key={code} value={code}>
              {name}
            </option>
          ))}
        </select>
      </div>
      {state.loading ? (
        <Spinner className="py-4" />
      ) : state.error ? (
        <p className="text-sm text-red-400">{state.error}</p>
      ) : state.cards.length === 0 ? (
        <p className="text-sm text-muted">Nada encontrado neste idioma.</p>
      ) : (
        <div className="grid grid-cols-[repeat(auto-fill,minmax(80px,1fr))] gap-2">
          {state.cards.map((v) => (
            <button
              key={v.id}
              type="button"
              onClick={() => onPick(v)}
              title={`${v.set_name} #${v.collector_number}`}
              className={`rounded-[5%] transition hover:scale-105 ${v.id === card.id ? 'ring-2 ring-accent' : ''}`}
            >
              <CardImage src={imageOf(v, 'normal')} alt={v.set_name} />
            </button>
          ))}
        </div>
      )}
    </section>
  )
}

/** Adiciona a carta a um dos "Meus decks" (os mesmos do app, com a conta). */
function AddToDeck({ card }) {
  const decks = deckList(useUserData((s) => s.decks))
  const [deckId, setDeckId] = useState('')
  const [done, setDone] = useState(null)
  const target = decks.find((d) => d.id === deckId) || decks[decks.length - 1]
  if (!decks.length) {
    return <p className="mt-5 text-sm text-muted">Crie um deck em "Meus decks" para adicionar cartas.</p>
  }
  return (
    <div className="mt-5 flex flex-wrap items-center gap-2">
      <select
        value={target.id}
        onChange={(e) => {
          setDeckId(e.target.value)
          setDone(null)
        }}
        className="min-w-0 flex-1 rounded-lg border border-line bg-card px-2 py-2 text-sm"
      >
        {decks.map((d) => (
          <option key={d.id} value={d.id}>
            {d.name} ({d.cards.length})
          </option>
        ))}
      </select>
      <button
        type="button"
        onClick={() => {
          saveDeck({ ...target, cards: [...target.cards, toDeckCard(card)] })
          incrementCardsAdded(1)
          setDone(target.name)
        }}
        className="rounded-full bg-accent px-4 py-2 text-sm font-bold hover:brightness-110"
      >
        + Adicionar ao deck
      </button>
      {done && <span className="w-full text-sm font-bold text-emerald-400">Adicionada em {done}!</span>}
    </div>
  )
}

/** Guardar na coleção (com quantas tenho) e pôr na lista de desejos. */
function CollectionButtons({ card }) {
  const collection = useUserData((s) => s.collection)
  const wishlist = useUserData((s) => s.wishlist)
  const deckCard = toDeckCard(card)
  const qty = qtyOf(collection, card.id)
  const wish = wished(wishlist, card.id)
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2">
      <button type="button" onClick={() => addToCollection(deckCard)} className="rounded-full bg-amber-400 px-4 py-2 text-sm font-bold text-black hover:brightness-110">
        📦 Guardar na coleção{qty > 0 ? ` (${qty})` : ''}
      </button>
      {qty > 0 && (
        <button type="button" onClick={() => setQty(card.id, qty - 1)} className="rounded-full bg-text/10 px-3 py-2 text-sm font-bold hover:bg-text/20" aria-label="Tirar uma da coleção">
          −1
        </button>
      )}
      <button
        type="button"
        onClick={() => toggleWish(deckCard)}
        className={`rounded-full px-4 py-2 text-sm font-bold ${wish ? 'bg-pink-500 text-white' : 'bg-text/10 hover:bg-text/20'}`}
      >
        {wish ? '♥ Na lista de desejos' : '♡ Lista de desejos'}
      </button>
    </div>
  )
}

function NavButton({ onClick, label, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!onClick}
      aria-label={label}
      className="grid h-9 w-9 place-items-center rounded-full bg-text/10 text-lg hover:bg-text/20 disabled:opacity-30"
    >
      {children}
    </button>
  )
}

/**
 * A ficha da carta, aberta dentro da grade (embaixo da linha da carta).
 * Aceita a carta da API ou só o id dela (cartas dos decks).
 */
// Raridade em português (a Scryfall manda em inglês).
const RARITY_PT = { common: 'Comum', uncommon: 'Incomum', rare: 'Rara', mythic: 'Mítica', special: 'Especial', bonus: 'Bônus' }

/** As regras oficiais sobre a carta (rulings), em inglês. */
function Rulings({ card }) {
  const [list, setList] = useState([])
  const uri = card.rulings_uri
  useEffect(() => {
    let alive = true
    setList([])
    if (uri) getJson(uri).then((r) => alive && setList(r.data || []), () => {})
    return () => {
      alive = false
    }
  }, [uri])
  if (!list.length) return null
  return (
    <details className="mt-5">
      <summary className="cursor-pointer text-lg font-bold">
        Regras da carta ({list.length}) <span className="text-xs font-normal text-muted">esclarecimentos oficiais, em inglês</span>
      </summary>
      <ul className="mt-2 space-y-3">
        {list.map((r, k) => (
          <li key={k} className="text-sm">
            <span className="block text-xs font-bold text-muted">{String(r.published_at || '').split('-').reverse().join('/')}</span>
            {r.comment}
          </li>
        ))}
      </ul>
    </details>
  )
}

export default function CardDetails({ card: initial, id, onClose, onPrevious, onNext }) {
  const [card, setCard] = useState(initial || null)
  const [error, setError] = useState(null)
  const [back, setBack] = useState(false)

  useEffect(() => {
    setBack(false)
    setError(null)
    if (initial) {
      setCard(initial)
      return
    }
    if (!id) return
    let alive = true
    setCard(null)
    cardById(id).then((c) => alive && setCard(c), (e) => alive && setError(e.message))
    return () => {
      alive = false
    }
  }, [id, initial])

  const pick = (v) => {
    if (v.id !== card.id) incrementArtsViewed()
    setCard(v)
    setBack(false)
  }

  return (
    <div className="relative rounded-2xl bg-surface p-4 shadow-2xl ring-1 ring-line sm:p-6">
      <div className="absolute right-3 top-3 z-10 flex gap-2">
        <NavButton onClick={onPrevious} label="Carta anterior">‹</NavButton>
        <NavButton onClick={onNext} label="Próxima carta">›</NavButton>
        <NavButton onClick={onClose} label="Fechar">✕</NavButton>
      </div>
      {!card ? (
        error ? <p className="py-10 text-center text-red-400">{error}</p> : <Spinner />
      ) : (
        <div className="grid gap-6 md:grid-cols-[minmax(0,340px)_1fr] xl:grid-cols-[minmax(0,340px)_1fr_minmax(0,1fr)]">
          <div className="pt-10 md:pt-0">
            <BestImage key={`${card.id}-${back}`} card={card} back={back} />
            {backImageOf(card) && (
              <button
                type="button"
                onClick={() => setBack((b) => !b)}
                className="mt-3 w-full rounded-full bg-text/10 py-2 text-sm font-bold hover:bg-text/20"
              >
                ↻ Ver o outro lado
              </button>
            )}
          </div>
          <div className="min-w-0 md:pr-32 xl:pr-0">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <h2 className="text-2xl font-black">{displayName(card)}</h2>
              <ManaText text={manaCost(card)} size={22} />
            </div>
            {card.printed_name && card.printed_name !== card.name && <p className="text-sm text-muted">{card.name}</p>}
            <p className="mt-2 font-semibold text-text/80">{typeLine(card)}</p>
            <div className="oracle mt-3 rounded-xl bg-text/5 p-3 leading-relaxed">
              <ManaText text={oracleText(card)} size={15} />
              {card.flavor_text && <p className="mt-3 italic text-muted">{card.flavor_text}</p>}
            </div>
            {(card.power || card.card_faces?.[0]?.power) && (
              <p className="mt-2 font-bold">
                {card.power ?? card.card_faces[0].power}/{card.toughness ?? card.card_faces[0].toughness}
              </p>
            )}
            {card.loyalty && <p className="mt-2 font-bold">Lealdade: {card.loyalty}</p>}

            <p className="mt-3 text-sm text-muted">
              {card.set_name} · #{card.collector_number} ·{' '}
              <span className="font-bold capitalize" style={{ color: RARITY_COLORS[card.rarity] }}>
                {RARITY_PT[card.rarity] || card.rarity}
              </span>
              {card.artist && <> · Arte: {card.artist}</>}
            </p>

            <section className="mt-5">
              <h3 className="mb-2 text-lg font-bold">Preços</h3>
              {card.prices && Object.values(card.prices).some(Boolean) ? (
                <div className="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-2">
                  <Price label="Normal" value={card.prices.usd} prefix="US$" />
                  <Price label="Foil" value={card.prices.usd_foil} prefix="US$" />
                  <Price label="Europa" value={card.prices.eur} prefix="€" />
                  <Price label="MTGO" value={card.prices.tix} prefix="tix" />
                </div>
              ) : (
                <p className="text-sm text-muted">Sem preço para esta versão. Tente a versão em inglês.</p>
              )}
            </section>

            {card.legalities && (
              <section className="mt-5">
                <h3 className="mb-2 text-lg font-bold">Formatos</h3>
                <div className="flex flex-wrap gap-2">
                  {FORMATS.map(([key, name]) => {
                    const [label, cls] = LEGALITY[card.legalities[key]] || LEGALITY.not_legal
                    return (
                      <span key={key} className={`rounded-full px-3 py-1 text-xs font-bold ${cls}`}>
                        {name}: {label}
                      </span>
                    )
                  })}
                </div>
              </section>
            )}

            <Rulings card={card} />

            <AddToDeck card={card} />
            <CollectionButtons card={card} />

            <a href={card.scryfall_uri} target="_blank" rel="noreferrer" className="mt-5 inline-block text-sm text-accent underline">
              Ver no Scryfall
            </a>
          </div>
          <div className="min-w-0 md:col-span-2 xl:col-span-1 xl:max-h-[640px] xl:overflow-y-auto xl:pt-10">
            <Versions card={card} onPick={pick} />
          </div>
        </div>
      )}
    </div>
  )
}
