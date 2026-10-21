import { useState } from 'react'
import { Link } from 'react-router-dom'
import CardImage from '../components/CardImage'
import CardDetails from '../components/CardDetails'
import ExpandingGrid from '../components/ExpandingGrid'
import { Modal } from '../components/ui'
import { scryfallIdOf } from '../lib/deckCards'
import { deckList, deleteDeck, saveDeck, useUserData } from '../lib/userData'
import { incrementDecksCreated } from '../lib/xp'
import { useAuth } from '../lib/auth'
import { DeckAnalysis, ImportListModal, TestHand } from '../components/DeckTools'
import { incrementCardsAdded } from '../lib/xp'

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
  const [tool, setTool] = useState(null) // 'import' | 'analysis' | 'hand'
  const total = deck.cards.length
  const price = deck.cards.reduce((sum, c) => sum + (Number.parseFloat(c.usdPrice) || 0), 0)
  const removeCard = (index) => saveDeck({ ...deck, cards: deck.cards.filter((_, i) => i !== index) })
  // Cópias iguais (mesmo nome e arte) aparecem juntas, com "4×"; o comandante primeiro.
  const groups = (() => {
    const map = new Map()
    deck.cards.forEach((c, i) => {
      const key = `${c.name}|${c.imageUrl}`
      if (!map.has(key)) map.set(key, { c, i, copies: [] })
      map.get(key).copies.push(i)
    })
    return [...map.values()]
      .map((g) => ({ ...g, i: g.copies.at(-1) }))
      .sort((a, b) => (b.c.commander ? 1 : 0) - (a.c.commander ? 1 : 0) || a.copies[0] - b.copies[0])
  })()
  return (
    <Modal onClose={onClose} wide>
      <h2 className="pr-10 text-2xl font-black">
        {deck.name}{' '}
        <button
          type="button"
          onClick={() => {
            const name = window.prompt('Nome do deck:', deck.name)
            if (name?.trim()) saveDeck({ ...deck, name: name.trim() })
          }}
          className="align-middle text-base text-muted hover:text-text"
          title="Renomear o deck"
        >
          ✏️
        </button>
      </h2>
      <p className="mb-4 text-sm text-muted">
        {deck.type} · {total} cartas{price > 0 ? ` · ~US$ ${price.toFixed(2)}` : ''}
      </p>
      <div className="mb-4 flex flex-wrap gap-2">
        <button type="button" onClick={() => setTool('import')} className="rounded-full bg-text/10 px-4 py-1.5 text-sm font-bold hover:bg-text/20">
          📋 Importar lista
        </button>
        <button
          type="button"
          disabled={!total}
          onClick={() => setTool(tool === 'analysis' ? null : 'analysis')}
          className={`rounded-full px-4 py-1.5 text-sm font-bold disabled:opacity-40 ${tool === 'analysis' ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}
        >
          💲 Preço e legalidade
        </button>
        <button
          type="button"
          disabled={total < 7}
          onClick={() => setTool(tool === 'hand' ? null : 'hand')}
          className={`rounded-full px-4 py-1.5 text-sm font-bold disabled:opacity-40 ${tool === 'hand' ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}
        >
          ✋ Mão de teste
        </button>
      </div>
      {tool === 'analysis' && (
        <div className="mb-5">
          <DeckAnalysis deck={deck} />
        </div>
      )}
      {tool === 'hand' && (
        <div className="mb-5 rounded-2xl bg-text/5 p-4">
          <TestHand deck={deck} />
        </div>
      )}
      {tool === 'import' && (
        <ImportListModal
          onDone={({ cards }) => {
            saveDeck({ ...deck, cards: [...deck.cards, ...cards] })
            incrementCardsAdded(cards.length)
          }}
          onClose={() => setTool(null)}
        />
      )}
      {total === 0 ? (
        <p className="py-10 text-center text-muted">
          Deck vazio. Abra uma carta na{' '}
          <Link to="/" onClick={onClose} className="text-accent underline">
            busca
          </Link>{' '}
          e use "Adicionar ao deck".
        </p>
      ) : (
        <ExpandingGrid
          items={groups}
          keyOf={({ c, i }) => `${i}-${c.name}`}
          minWidth={130}
          renderItem={({ c, i, copies }, _, open, selected) => (
            <div className="relative">
              <button
                type="button"
                onClick={() => scryfallIdOf(c) && open()}
                className={`block w-full rounded-[4.5%] transition hover:scale-[1.03] ${selected ? 'ring-4 ring-accent' : ''}`}
                title={c.name}
              >
                <CardImage src={c.imageUrl} alt={c.name} />
              </button>
              {(copies.length > 1 || c.commander) && (
                <span className="absolute bottom-1.5 left-1.5 rounded-lg bg-black/75 px-2 py-0.5 text-sm font-black text-white">
                  {c.commander ? '👑' : ''}
                  {copies.length > 1 ? `${copies.length}×` : ''}
                </span>
              )}
              <button
                type="button"
                onClick={() => saveDeck({ ...deck, cards: [...deck.cards, c] })}
                aria-label={`Mais uma cópia de ${c.name}`}
                className="absolute -left-1.5 -top-1.5 grid h-7 w-7 place-items-center rounded-full bg-emerald-500 text-sm font-black shadow"
              >
                +
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
          )}
          renderPanel={({ c }, { close, previous, next }) => <CardDetails id={scryfallIdOf(c)} onClose={close} onPrevious={previous} onNext={next} />}
        />
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
    </Modal>
  )
}

export default function MyDecksPage() {
  const decks = useUserData((s) => s.decks)
  const { status } = useAuth()
  const [creating, setCreating] = useState(false)
  const [importing, setImporting] = useState(false)
  const [openId, setOpenId] = useState(null)
  const list = deckList(decks)
  const open = openId ? decks[openId] : null

  return (
    <div>
      <div className="mb-4 flex items-center gap-3">
        <h1 className="mr-auto text-2xl font-black">Meus decks</h1>
        <button type="button" onClick={() => setImporting(true)} className="rounded-full bg-text/10 px-4 py-2 text-sm font-bold hover:bg-text/20">
          📋 Importar lista
        </button>
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
      {importing && (
        <ImportListModal
          askName
          onDone={({ name, type, cards }) => {
            const deck = createDeck(name, type)
            saveDeck({ ...deck, cards })
            incrementCardsAdded(cards.length)
          }}
          onClose={() => setImporting(false)}
        />
      )}
      {open && <DeckView deck={open} onClose={() => setOpenId(null)} />}
    </div>
  )
}
