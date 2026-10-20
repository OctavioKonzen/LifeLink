import { useState } from 'react'
import { Link } from 'react-router-dom'
import CardImage from '../components/CardImage'
import CardModal from '../components/CardModal'
import { Modal } from '../components/ui'
import { scryfallIdOf } from '../lib/deckCards'
import { deckList, deleteDeck, saveDeck, useUserData } from '../lib/userData'
import { incrementDecksCreated } from '../lib/xp'
import { useAuth } from '../lib/auth'

const TYPES = ['Commander', 'Challenger', 'Normal'] // os mesmos do app (my_decks_screen.dart)

/** Cria um deck vazio, com o id na mesma forma do app (hora em milissegundos). */
export function createDeck(name, type) {
  const deck = { id: String(Date.now()), name, type, cards: [] }
  saveDeck(deck)
  incrementDecksCreated()
  return deck
}

function NewDeck({ onClose }) {
  const [name, setName] = useState('')
  const [type, setType] = useState('Commander')
  return (
    <Modal onClose={onClose}>
      <h2 className="mb-4 text-xl font-black">Novo deck</h2>
      <form
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault()
          if (!name.trim()) return
          createDeck(name.trim(), type)
          onClose()
        }}
      >
        <input
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nome do deck"
          className="rounded-xl border border-line bg-card px-4 py-3 outline-none focus:border-accent"
        />
        <select value={type} onChange={(e) => setType(e.target.value)} className="rounded-xl border border-line bg-card px-4 py-3">
          {TYPES.map((t) => (
            <option key={t}>{t}</option>
          ))}
        </select>
        <button type="submit" className="rounded-xl bg-accent py-3 font-bold hover:brightness-110">
          Criar
        </button>
      </form>
    </Modal>
  )
}

function DeckView({ deck, onClose }) {
  const [open, setOpen] = useState(null)
  const total = deck.cards.length
  const price = deck.cards.reduce((sum, c) => sum + (Number.parseFloat(c.usdPrice) || 0), 0)
  const removeCard = (index) => saveDeck({ ...deck, cards: deck.cards.filter((_, i) => i !== index) })
  return (
    <Modal onClose={onClose} wide>
      <h2 className="pr-10 text-2xl font-black">{deck.name}</h2>
      <p className="mb-4 text-sm text-muted">
        {deck.type} · {total} cartas{price > 0 ? ` · ~US$ ${price.toFixed(2)}` : ''}
      </p>
      {total === 0 ? (
        <p className="py-10 text-center text-muted">
          Deck vazio. Abra uma carta na{' '}
          <Link to="/" onClick={onClose} className="text-accent underline">
            busca
          </Link>{' '}
          e use "Adicionar ao deck".
        </p>
      ) : (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-6">
          {deck.cards.map((c, i) => (
            <div key={i} className="relative">
              <button type="button" onClick={() => scryfallIdOf(c) && setOpen(scryfallIdOf(c))} className="block w-full transition hover:scale-[1.03]" title={c.name}>
                <CardImage src={c.imageUrl} alt={c.name} />
              </button>
              <button
                type="button"
                onClick={() => removeCard(i)}
                aria-label={`Tirar ${c.name} do deck`}
                className="absolute -right-1.5 -top-1.5 grid h-7 w-7 place-items-center rounded-full bg-red-500 text-sm font-black shadow"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      )}
      <button
        type="button"
        onClick={() => {
          if (window.confirm('Tem certeza que deseja excluir este deck permanentemente?')) {
            deleteDeck(deck.id)
            onClose()
          }
        }}
        className="mt-6 rounded-full bg-red-500/15 px-5 py-2 text-sm font-bold text-red-400 hover:bg-red-500/25"
      >
        Apagar deck
      </button>
      {open && <CardModal id={open} onClose={() => setOpen(null)} />}
    </Modal>
  )
}

export default function MyDecksPage() {
  const decks = useUserData((s) => s.decks)
  const { status } = useAuth()
  const [creating, setCreating] = useState(false)
  const [openId, setOpenId] = useState(null)
  const list = deckList(decks)
  const open = openId ? decks[openId] : null

  return (
    <div>
      <div className="mb-4 flex items-center gap-3">
        <h1 className="mr-auto text-2xl font-black">Meus decks</h1>
        <button type="button" onClick={() => setCreating(true)} className="rounded-full bg-accent px-4 py-2 text-sm font-bold hover:brightness-110">
          + Novo deck
        </button>
      </div>
      {status === 'signedOut' && (
        <p className="mb-4 rounded-xl bg-accent/10 p-3 text-sm text-accent">
          Estes decks estão só neste navegador.{' '}
          <Link to="/conta" className="font-bold underline">
            Entre na conta
          </Link>{' '}
          para ver os mesmos decks no app.
        </p>
      )}
      {list.length === 0 ? (
        <p className="py-12 text-center text-muted">Nenhum deck ainda. Crie um ou salve um dos decks oficiais.</p>
      ) : (
        <div className="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-4">
          {list.map((d) => (
            <button key={d.id} type="button" onClick={() => setOpenId(d.id)} className="rounded-2xl bg-card p-3 text-left shadow transition hover:scale-[1.02]">
              <div className="mx-auto w-24">
                <CardImage src={d.cards[0]?.imageUrl} alt="" />
              </div>
              <div className="mt-3 truncate text-sm font-bold">{d.name}</div>
              <div className="text-xs text-muted">
                {d.type} • {d.cards.length} cartas
              </div>
            </button>
          ))}
        </div>
      )}
      {creating && <NewDeck onClose={() => setCreating(false)} />}
      {open && <DeckView deck={open} onClose={() => setOpenId(null)} />}
    </div>
  )
}
