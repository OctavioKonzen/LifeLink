import { useEffect, useState } from 'react'
import CardDetails from '../components/CardDetails'
import CardImage from '../components/CardImage'
import { Modal, PageHeader, btnPrimary, btnSecondary, inputClass, panel } from '../components/ui'
import { ArrowDown, ArrowUp, Folder, MoreHorizontal, Minus, Plus, RefreshCw, Repeat, Search, X } from 'lucide-react'
import { useUserData } from '../lib/userData'
import { dollarInReais } from '../lib/deckTools'
import { foldersOf, refreshPrices, removeWish, setFolder, setQty, setTrade, totalCards, totalEur, totalUsd } from '../lib/collection'

// Minha coleção e lista de desejos, as mesmas do app (collection_screen.dart).
// Para guardar uma carta: os botões na página da carta (ou o scan do app).

const money = (usd, brl) => `US$ ${usd.toFixed(2)}${brl ? ` · R$ ${(usd * brl).toFixed(2)}` : ''}`

/** As opções de uma carta da coleção: a pasta (uma que já existe ou nova) e "para troca". */
function CardOptions({ card, folders, onClose }) {
  const [name, setName] = useState('')
  const save = (folder) => {
    setFolder(card.id, folder)
    onClose()
  }
  return (
    <div className="space-y-4 text-sm">
      <h2 className="pr-10 font-display text-2xl font-bold">{card.name}</h2>
      <label className="flex cursor-pointer items-start gap-3 rounded-xl bg-bg p-3">
        <input type="checkbox" checked={!!card.trade} onChange={(e) => setTrade(card.id, e.target.checked)} className="mt-0.5 size-4 accent-amber-400" />
        <span>
          <span className="flex items-center gap-1.5 font-semibold">
            <Repeat className="size-4 text-accent" aria-hidden="true" /> Para troca
          </span>
          <span className="text-muted">Os amigos veem e o site mostra quem quer esta carta.</span>
        </span>
      </label>
      <p className="flex items-center gap-1.5 text-xs font-medium uppercase tracking-widest text-muted">
        <Folder className="size-3.5" aria-hidden="true" /> Pasta{card.folder ? `: ${card.folder}` : ''}
      </p>
      <div className="flex flex-wrap gap-1.5">
        {folders.map((f) => (
          <button key={f} type="button" onClick={() => save(f)} className={`rounded-lg px-3 py-1 text-xs font-bold ${card.folder === f ? 'bg-accent text-on-accent' : 'bg-card hover:brightness-125'}`}>
            {f}
          </button>
        ))}
        {card.folder && (
          <button type="button" onClick={() => save('')} className="rounded-lg bg-card px-3 py-1 text-xs font-bold hover:brightness-125">
            Sem pasta
          </button>
        )}
      </div>
      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault()
          if (name.trim()) save(name)
        }}
      >
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nova pasta (ex.: Fichário, Caixa)" className={`${inputClass} h-10 min-w-0 flex-1`} />
        <button type="submit" className={btnPrimary}>
          Salvar
        </button>
      </form>
    </div>
  )
}

function Thumb({ img }) {
  return img ? <img src={img} alt="" loading="lazy" className="h-12 w-9 shrink-0 rounded-md object-cover" /> : <div className="h-12 w-9 shrink-0 rounded-md bg-card" />
}

export default function CollectionPage() {
  const collection = useUserData((s) => s.collection)
  const wishlist = useUserData((s) => s.wishlist)
  const [tab, setTab] = useState(() => (window.location.hash.includes('desejos') ? 'wish' : 'collection'))
  const [brl, setBrl] = useState(null)
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(null)
  const [status, setStatus] = useState('')
  const [folder, setFolderFilter] = useState(null) // null = todas; '' = sem pasta
  const [onlyTrade, setOnlyTrade] = useState(false)
  const [options, setOptions] = useState(null) // id da carta com as opções abertas

  useEffect(() => {
    dollarInReais().then(setBrl, () => {})
  }, [])

  const refresh = async () => {
    setStatus('Atualizando os preços...')
    try {
      const drops = await refreshPrices(collection, wishlist)
      setStatus(drops.length ? `Ficaram mais baratas: ${drops.map((d) => `${d.name} (US$ ${d.before.toFixed(2)} → ${d.usd.toFixed(2)})`).join(', ')}` : 'Preços atualizados.')
    } catch (e) {
      setStatus(e.message)
    }
  }

  const folders = foldersOf(collection)
  const cards = (collection?.list || []).filter(
    (c) =>
      (!query || `${c.name} ${c.set}`.toLowerCase().includes(query.toLowerCase())) &&
      (folder === null || (c.folder || '') === folder) &&
      (!onlyTrade || c.trade),
  )
  const chip = (label, on, onClick) => (
    <button
      key={label}
      type="button"
      onClick={onClick}
      className={`shrink-0 cursor-pointer rounded-lg px-3 py-1.5 text-sm font-medium ${on ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`}
    >
      {label}
    </button>
  )
  const wishes = wishlist?.list || []
  const tabClass = (on) => `cursor-pointer rounded-lg px-4 py-2 text-sm font-medium ${on ? 'bg-card text-text' : 'text-muted hover:text-text'}`
  const optionsCard = (collection?.list || []).find((c) => c.id === options)
  const stats = [
    { label: 'Cartas na coleção', value: String(totalCards(collection)) },
    { label: 'Cartas únicas', value: String((collection?.list || []).length) },
    { label: 'Valor estimado', value: brl ? `R$ ${(totalUsd(collection) * brl).toFixed(2)}` : `US$ ${totalUsd(collection).toFixed(2)}`, sub: brl ? `US$ ${totalUsd(collection).toFixed(2)}` : null },
    { label: 'Cardmarket', value: totalEur(collection) > 0 ? `€ ${totalEur(collection).toFixed(2)}` : '—', sub: `${(collection?.list || []).filter((c) => c.trade).length} para troca` },
  ]

  return (
    <div>
      <PageHeader
        title="Coleção"
        description="Tudo o que você tem guardado, com o valor atualizado, e a lista de desejos."
        action={
          <button type="button" onClick={refresh} className={btnSecondary}>
            <RefreshCw className="size-4" aria-hidden="true" /> Atualizar preços
          </button>
        }
      />
      <div className="mb-6 inline-flex gap-1 rounded-xl border border-line bg-surface p-1">
        <button type="button" className={tabClass(tab === 'collection')} onClick={() => setTab('collection')}>
          Coleção ({totalCards(collection)})
        </button>
        <button type="button" className={tabClass(tab === 'wish')} onClick={() => setTab('wish')}>
          Desejos ({wishes.length})
        </button>
      </div>
      {status && <p className="mb-4 text-sm font-semibold text-success">{status}</p>}

      {tab === 'collection' ? (
        <>
          <dl className="mb-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
            {stats.map((st) => (
              <div key={st.label} className={`${panel} p-5`}>
                <dt className="text-sm text-muted">{st.label}</dt>
                <dd className="mt-2 text-2xl font-semibold tracking-tight">{st.value}</dd>
                {st.sub && <dd className="mt-0.5 text-xs text-muted">{st.sub}</dd>}
              </div>
            ))}
          </dl>
          <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center">
            <label className="relative sm:w-72">
              <span className="sr-only">Procurar na coleção</span>
              <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Procurar na coleção" className={`${inputClass} pl-10`} />
            </label>
            {/* Pastas (fichário, caixa...) e "para troca". */}
            <div className="flex gap-1.5 overflow-x-auto pb-1">
              {chip('Todas', folder === null && !onlyTrade, () => {
                setFolderFilter(null)
                setOnlyTrade(false)
              })}
              {chip('Para troca', onlyTrade, () => setOnlyTrade(!onlyTrade))}
              {folders.map((f) => chip(f, folder === f, () => setFolderFilter(folder === f ? null : f)))}
              {folders.length > 0 && chip('Sem pasta', folder === '', () => setFolderFilter(folder === '' ? null : ''))}
            </div>
          </div>
          {!collection?.list?.length && (
            <p className="rounded-2xl border border-dashed border-line py-16 text-center text-muted">
              Sua coleção está vazia. Use "Adicionar à coleção" na página de uma carta, ou o scan do app.
            </p>
          )}
          <ul className="grid grid-cols-2 gap-5 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {cards.map((c) => (
              <li key={c.id} className="flex flex-col gap-2">
                <div className="relative">
                  <button type="button" onClick={() => setOpen(c)} className="group block w-full cursor-pointer" title={c.name}>
                    <CardImage src={c.img} alt={c.name} className="shadow-xl shadow-black/50 transition duration-300 group-hover:-translate-y-1" />
                  </button>
                  <span className="absolute -right-2 -top-2 grid size-8 place-items-center rounded-full bg-accent text-sm font-bold text-on-accent shadow-lg">{c.qty || 1}x</span>
                  {c.trade && (
                    <span className="absolute left-2 top-2 grid size-7 place-items-center rounded-full bg-black/70 text-accent" title="Para troca">
                      <Repeat className="size-3.5" aria-label="Para troca" />
                    </span>
                  )}
                </div>
                <div className="px-0.5">
                  <p className="truncate text-sm font-medium">{c.name}</p>
                  <p className="truncate text-xs text-muted">
                    {c.folder ? `${c.folder} · ` : ''}US$ {(c.usd || 0).toFixed(2)}
                    {c.eur > 0 ? ` · € ${c.eur.toFixed(2)}` : ''}
                  </p>
                </div>
                <div className="flex items-center gap-1">
                  <button type="button" aria-label="Tirar uma" onClick={() => setQty(c.id, (c.qty || 1) - 1)} className="grid size-8 cursor-pointer place-items-center rounded-lg bg-card hover:brightness-125">
                    <Minus className="size-4" aria-hidden="true" />
                  </button>
                  <button type="button" aria-label="Mais uma" onClick={() => setQty(c.id, (c.qty || 1) + 1)} className="grid size-8 cursor-pointer place-items-center rounded-lg bg-card hover:brightness-125">
                    <Plus className="size-4" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label="Pasta e troca"
                    title="Pasta e troca"
                    onClick={() => setOptions(c.id)}
                    className="ml-auto grid size-8 cursor-pointer place-items-center rounded-lg bg-card hover:brightness-125"
                  >
                    <MoreHorizontal className="size-4" aria-hidden="true" />
                  </button>
                </div>
              </li>
            ))}
          </ul>
          {optionsCard && (
            <Modal onClose={() => setOptions(null)}>
              <CardOptions card={optionsCard} folders={folders} onClose={() => setOptions(null)} />
            </Modal>
          )}
        </>
      ) : (
        <>
          <p className="mb-4 text-sm text-muted">
            Tudo: {money(wishes.reduce((a, c) => a + (c.usd || 0), 0), brl)}. O app confere os preços uma vez por dia e avisa quando algum cai.
          </p>
          {!wishes.length && (
            <p className="rounded-2xl border border-dashed border-line py-16 text-center text-muted">Sua lista de desejos está vazia. Use "Lista de desejos" na página de uma carta.</p>
          )}
          {wishes.length > 0 && (
            <ul className={`${panel} overflow-hidden`}>
              {wishes.map((c) => {
                const diff = c.added > 0 ? ((c.usd - c.added) / c.added) * 100 : 0
                return (
                  <li key={c.id} className="flex items-center gap-3 border-b border-line/60 px-5 py-3 text-sm last:border-0 hover:bg-card/50">
                    <button type="button" onClick={() => setOpen(c)} className="flex min-w-0 flex-1 cursor-pointer items-center gap-3 text-left">
                      <Thumb img={c.img} />
                      <span className="min-w-0">
                        <span className="block truncate font-medium">{c.name}</span>
                        <span className="block truncate text-xs text-muted">
                          {c.set} · quando entrou: US$ {(c.added || 0).toFixed(2)}
                        </span>
                      </span>
                    </button>
                    <span className="text-right">
                      <span className="block font-semibold">US$ {(c.usd || 0).toFixed(2)}</span>
                      {Math.round(diff) !== 0 && (
                        <span className={`flex items-center justify-end gap-0.5 text-xs font-semibold ${diff < 0 ? 'text-success' : 'text-danger'}`}>
                          {diff < 0 ? <ArrowDown className="size-3" aria-hidden="true" /> : <ArrowUp className="size-3" aria-hidden="true" />}
                          {Math.abs(diff).toFixed(0)}%
                        </span>
                      )}
                    </span>
                    <button type="button" aria-label="Tirar da lista" onClick={() => removeWish(c.id)} className="grid size-8 cursor-pointer place-items-center rounded-lg bg-card hover:brightness-125">
                      <X className="size-4" aria-hidden="true" />
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </>
      )}
      {open && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 p-3 backdrop-blur-sm sm:p-6" onClick={() => setOpen(null)}>
          <div className="mx-auto my-4 max-w-5xl" onClick={(e) => e.stopPropagation()}>
            <CardDetails id={/^[0-9a-f-]{36}$/.test(open.id) ? open.id : undefined} onClose={() => setOpen(null)} />
          </div>
        </div>
      )}
    </div>
  )
}
