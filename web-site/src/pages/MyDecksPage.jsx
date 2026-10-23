import { useState } from 'react'
import { Link } from 'react-router-dom'
import CardImage from '../components/CardImage'
import CardDetails from '../components/CardDetails'
import ExpandingGrid from '../components/ExpandingGrid'
import { Modal, PageHeader, btnPrimary, btnSecondary, inputClass } from '../components/ui'
import { ManaPip } from '../components/Mana'
import { matchStats } from '../lib/matches'
import { ClipboardList, Crown, DollarSign, Hand, Lightbulb, PackageSearch, Pencil, Plus, Share2, Trash2, X } from 'lucide-react'
import { scryfallIdOf } from '../lib/deckCards'
import { deckList, deleteDeck, saveDeck, useUserData } from '../lib/userData'
import { incrementDecksCreated } from '../lib/xp'
import { useAuth } from '../lib/auth'
import { DeckAnalysis, ExportDeck, ImportListModal, MissingCards, Suggestions, TestHand } from '../components/DeckTools'
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
      <h2 className="mb-5 font-display text-2xl font-bold">Novo deck</h2>
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
          className={inputClass}
        />
        <select value={type} onChange={(e) => setType(e.target.value)} className={inputClass}>
          {TYPES.map((t) => (
            <option key={t}>{t}</option>
          ))}
        </select>
        <button type="submit" className={`${btnPrimary} h-11`}>
          Criar deck
        </button>
      </form>
    </Modal>
  )
}

function DeckView({ deck, onClose }) {
  const [tool, setTool] = useState(null) // 'import' | 'analysis' | 'hand' | 'export' | 'missing' | 'suggestions'
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
      <h2 className="pr-10 font-display text-2xl font-bold sm:text-3xl">
        {deck.name}{' '}
        <button
          type="button"
          onClick={() => {
            const name = window.prompt('Nome do deck:', deck.name)
            if (name?.trim()) saveDeck({ ...deck, name: name.trim() })
          }}
          className="ml-1 cursor-pointer align-middle text-muted hover:text-text"
          title="Renomear o deck"
          aria-label="Renomear o deck"
        >
          <Pencil className="size-4" aria-hidden="true" />
        </button>
      </h2>
      <p className="mb-5 text-sm text-muted">
        {deck.type} · {total} cartas{price > 0 ? ` · ~US$ ${price.toFixed(2)}` : ''}
      </p>
      <div className="mb-4 flex flex-wrap gap-2">
        <button type="button" onClick={() => setTool('import')} className="inline-flex cursor-pointer items-center gap-2 rounded-lg bg-card px-3.5 py-2 text-sm font-medium hover:brightness-125">
          <ClipboardList className="size-4" aria-hidden="true" /> Importar lista
        </button>
        <button
          type="button"
          disabled={!total}
          onClick={() => setTool(tool === 'analysis' ? null : 'analysis')}
          className={`inline-flex cursor-pointer items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium disabled:opacity-40 ${tool === 'analysis' ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}
        >
          <DollarSign className="size-4" aria-hidden="true" /> Preço e legalidade
        </button>
        <button
          type="button"
          disabled={total < 7}
          onClick={() => setTool(tool === 'hand' ? null : 'hand')}
          className={`inline-flex cursor-pointer items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium disabled:opacity-40 ${tool === 'hand' ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}
        >
          <Hand className="size-4" aria-hidden="true" /> Mão de teste e simulação
        </button>
        <button
          type="button"
          disabled={total < 1}
          onClick={() => setTool(tool === 'suggestions' ? null : 'suggestions')}
          className={`inline-flex cursor-pointer items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium disabled:opacity-40 ${tool === 'suggestions' ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}
        >
          <Lightbulb className="size-4" aria-hidden="true" /> Sugestões
        </button>
        <button
          type="button"
          disabled={total < 1}
          onClick={() => setTool(tool === 'export' ? null : 'export')}
          className={`inline-flex cursor-pointer items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium disabled:opacity-40 ${tool === 'export' ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}
        >
          <Share2 className="size-4" aria-hidden="true" /> Exportar
        </button>
        <button
          type="button"
          disabled={total < 1}
          onClick={() => setTool(tool === 'missing' ? null : 'missing')}
          className={`inline-flex cursor-pointer items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium disabled:opacity-40 ${tool === 'missing' ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}
        >
          <PackageSearch className="size-4" aria-hidden="true" /> O que falta
        </button>
      </div>
      {tool === 'suggestions' && (
        <div className="mb-5 rounded-2xl border border-line bg-bg p-5">
          <h3 className="mb-3 text-lg font-semibold">Sugestões para o deck</h3>
          <Suggestions deck={deck} />
        </div>
      )}
      {tool === 'missing' && (
        <div className="mb-5 rounded-2xl border border-line bg-bg p-5">
          <MissingCards deck={deck} />
        </div>
      )}
      {tool === 'export' && (
        <div className="mb-5 rounded-2xl border border-line bg-bg p-5">
          <ExportDeck deck={deck} />
        </div>
      )}
      {tool === 'analysis' && (
        <div className="mb-5">
          <DeckAnalysis deck={deck} />
        </div>
      )}
      {tool === 'hand' && (
        <div className="mb-5 rounded-2xl border border-line bg-bg p-5">
          <h3 className="mb-3 text-lg font-semibold">Mão de teste e simulação</h3>
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
          Deck vazio. Abra uma carta em{' '}
          <Link to="/" onClick={onClose} className="text-accent hover:underline">
            Cartas
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
                className="group block w-full cursor-pointer"
                title={c.name}
              >
                <CardImage
                  src={c.imageUrl}
                  alt={c.name}
                  className={`shadow-xl shadow-black/50 transition duration-300 group-hover:-translate-y-1 ${selected ? 'ring-4 ring-accent' : ''}`}
                />
              </button>
              {(copies.length > 1 || c.commander) && (
                <span className="absolute bottom-1.5 left-1.5 flex items-center gap-1 rounded-lg bg-black/75 px-2 py-0.5 text-sm font-bold text-white">
                  {c.commander && <Crown className="size-3.5 text-accent" aria-label="Comandante" />}
                  {copies.length > 1 ? `${copies.length}×` : ''}
                </span>
              )}
              <button
                type="button"
                onClick={() => saveDeck({ ...deck, cards: [...deck.cards, c] })}
                aria-label={`Mais uma cópia de ${c.name}`}
                className="absolute -left-2 -top-2 grid size-7 cursor-pointer place-items-center rounded-full bg-success text-black shadow-lg"
              >
                <Plus className="size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                onClick={() => removeCard(i)}
                aria-label={`Tirar ${c.name} do deck`}
                className="absolute -right-2 -top-2 grid size-7 cursor-pointer place-items-center rounded-full bg-danger text-white shadow-lg"
              >
                <X className="size-4" aria-hidden="true" />
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
        className="mt-6 inline-flex cursor-pointer items-center gap-2 rounded-lg bg-danger/10 px-4 py-2 text-sm font-medium text-danger hover:bg-danger/20"
      >
        <Trash2 className="size-4" aria-hidden="true" /> Apagar deck
      </button>
    </Modal>
  )
}

/** As cores do deck: a identidade de cor do comandante (ou de todas as cartas). */
function deckColors(deck) {
  const from = deck.cards.filter((c) => c.commander)
  const cards = from.length ? from : deck.cards
  const set = new Set(cards.flatMap((c) => String(c.color_identity || '').split('')).filter((c) => 'WUBRG'.includes(c)))
  const colors = ['W', 'U', 'B', 'R', 'G'].filter((c) => set.has(c))
  return colors.length ? colors : ['C']
}

/** A capa: a carta do comandante (ou a primeira), cortada mostrando a arte. */
function cover(deck) {
  return (deck.cards.find((c) => c.commander) || deck.cards[0])?.imageUrl
}

export default function MyDecksPage() {
  const decks = useUserData((s) => s.decks)
  const matches = useUserData((s) => s.matches)?.list || []
  const { status } = useAuth()
  const [creating, setCreating] = useState(false)
  const [importing, setImporting] = useState(false)
  const [openId, setOpenId] = useState(null)
  const list = deckList(decks)
  const open = openId ? decks[openId] : null
  const stats = new Map(matchStats(matches, { byDeck: true }).map((s) => [s.name.toLowerCase(), s]))

  return (
    <div>
      <PageHeader
        title="Meus decks"
        description="Seus decks montados, com o desempenho de cada um nas partidas."
        action={
          <div className="flex gap-2">
            <button type="button" onClick={() => setImporting(true)} className={btnSecondary}>
              <ClipboardList className="size-4" aria-hidden="true" /> Importar lista
            </button>
            <button type="button" onClick={() => setCreating(true)} className={btnPrimary}>
              <Plus className="size-4" aria-hidden="true" /> Novo deck
            </button>
          </div>
        }
      />
      {status === 'signedOut' && (
        <p className="mb-6 rounded-xl border border-accent/30 bg-accent/10 p-3 text-sm text-accent">
          Estes decks estão só neste navegador.{' '}
          <Link to="/conta" className="font-semibold underline">
            Entre na conta
          </Link>{' '}
          para ver os mesmos decks no app.
        </p>
      )}
      <ul className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {list.map((d) => {
          const s = stats.get(d.name.trim().toLowerCase())
          const rate = s?.played ? Math.round(s.rate * 100) : null
          const price = d.cards.reduce((sum, c) => sum + (Number.parseFloat(c.usdPrice) || 0), 0)
          const img = cover(d)
          return (
            <li key={d.id}>
              <button
                type="button"
                onClick={() => setOpenId(d.id)}
                className="group block w-full cursor-pointer overflow-hidden rounded-2xl border border-line bg-surface text-left transition hover:border-accent/50"
              >
                <div className="relative h-40 overflow-hidden bg-card">
                  {img && (
                    <img
                      src={img}
                      alt=""
                      loading="lazy"
                      className="absolute inset-0 h-full w-full scale-[1.35] object-cover object-[50%_28%] transition duration-500 group-hover:scale-[1.42]"
                    />
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-surface to-transparent" />
                  <span className="absolute left-4 top-4 rounded-full bg-black/60 px-2.5 py-1 text-xs font-medium text-white backdrop-blur">{d.type}</span>
                </div>
                <div className="flex flex-col gap-4 p-5 pt-1">
                  <div className="flex items-center justify-between gap-3">
                    <h2 className="truncate text-lg font-semibold">{d.name}</h2>
                    <span className="flex shrink-0 gap-1">
                      {deckColors(d).map((c) => (
                        <ManaPip key={c} color={c} size="md" />
                      ))}
                    </span>
                  </div>
                  <div className="flex flex-col gap-2">
                    <div className="flex justify-between gap-2 text-sm">
                      <span className="text-muted">
                        {s ? `${s.wins}V · ${s.played - s.wins}D · ` : ''}
                        {d.cards.length} cartas{price > 0 ? ` · US$ ${price.toFixed(0)}` : ''}
                      </span>
                      {rate !== null && <span className="font-semibold text-accent">{rate}%</span>}
                    </div>
                    <div className="h-1.5 overflow-hidden rounded-full bg-card">
                      <div className="h-full rounded-full bg-accent" style={{ width: `${rate ?? 0}%` }} />
                    </div>
                  </div>
                </div>
              </button>
            </li>
          )
        })}
        <li>
          <button
            type="button"
            onClick={() => setCreating(true)}
            className="flex h-full min-h-64 w-full cursor-pointer flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-line text-muted transition hover:border-accent/60 hover:text-text"
          >
            <span className="grid size-12 place-items-center rounded-full bg-card">
              <Plus className="size-5" aria-hidden="true" />
            </span>
            {list.length ? 'Criar um novo deck' : 'Nenhum deck ainda. Crie o primeiro (ou salve um dos decks oficiais).'}
          </button>
        </li>
      </ul>
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
