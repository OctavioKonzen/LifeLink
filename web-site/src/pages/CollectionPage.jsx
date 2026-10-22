import { useEffect, useState } from 'react'
import CardDetails from '../components/CardDetails'
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
    <div className="mb-1 ml-13 space-y-2 rounded-xl bg-text/5 p-3 text-sm">
      <label className="flex cursor-pointer items-center gap-2 font-bold">
        <input type="checkbox" checked={!!card.trade} onChange={(e) => setTrade(card.id, e.target.checked)} className="h-4 w-4 accent-amber-400" />
        🔁 Para troca
        <span className="font-normal text-muted">· os amigos veem e o site mostra quem quer esta carta.</span>
      </label>
      <p className="text-xs font-black uppercase tracking-wide text-muted">📁 Pasta{card.folder ? `: ${card.folder}` : ''}</p>
      <div className="flex flex-wrap gap-1.5">
        {folders.map((f) => (
          <button key={f} type="button" onClick={() => save(f)} className={`rounded-full px-3 py-1 text-xs font-bold ${card.folder === f ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}>
            {f}
          </button>
        ))}
        {card.folder && (
          <button type="button" onClick={() => save('')} className="rounded-full bg-text/10 px-3 py-1 text-xs font-bold hover:bg-text/20">
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
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nova pasta (ex.: Fichário, Caixa)" className="min-w-0 flex-1 rounded-lg bg-text/10 px-3 py-1.5" />
        <button type="submit" className="rounded-lg bg-accent px-3 font-bold text-white">
          Salvar
        </button>
      </form>
    </div>
  )
}

function Thumb({ img }) {
  return img ? <img src={img} alt="" loading="lazy" className="h-14 w-10 shrink-0 rounded object-cover" /> : <div className="h-14 w-10 shrink-0 rounded bg-text/10" />
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
    <button key={label} type="button" onClick={onClick} className={`shrink-0 rounded-full px-3 py-1 text-sm font-bold ${on ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}>
      {label}
    </button>
  )
  const wishes = wishlist?.list || []
  const tabClass = (on) => `rounded-full px-4 py-1.5 text-sm font-bold ${on ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="mb-3 text-2xl font-black">Minha coleção</h1>
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <button type="button" className={tabClass(tab === 'collection')} onClick={() => setTab('collection')}>
          Coleção ({totalCards(collection)})
        </button>
        <button type="button" className={tabClass(tab === 'wish')} onClick={() => setTab('wish')}>
          Desejos ({wishes.length})
        </button>
        <button type="button" onClick={refresh} className="ml-auto rounded-full bg-text/10 px-4 py-1.5 text-sm font-bold hover:bg-text/20">
          ↻ Atualizar preços
        </button>
      </div>
      {status && <p className="mb-3 text-sm font-bold text-emerald-400">{status}</p>}

      {tab === 'collection' ? (
        <>
          <div className="mb-3 rounded-2xl border border-amber-400/40 bg-amber-400/10 p-4">
            <p className="text-xs text-muted">Valor da coleção</p>
            <p className="text-xl font-black">{money(totalUsd(collection), brl)}</p>
            {totalEur(collection) > 0 && <p className="text-sm font-bold text-muted">Cardmarket: € {totalEur(collection).toFixed(2)}</p>}
            <p className="text-xs text-muted">
              {totalCards(collection)} cartas · {(collection?.list || []).length} diferentes · ⋯ numa carta para pasta e troca
            </p>
          </div>
          {/* Pastas (fichário, caixa...) e "para troca". */}
          <div className="mb-3 flex gap-1.5 overflow-x-auto pb-1">
            {chip('Todas', folder === null && !onlyTrade, () => {
              setFolderFilter(null)
              setOnlyTrade(false)
            })}
            {chip('🔁 Para troca', onlyTrade, () => setOnlyTrade(!onlyTrade))}
            {folders.map((f) => chip(f, folder === f, () => setFolderFilter(folder === f ? null : f)))}
            {folders.length > 0 && chip('Sem pasta', folder === '', () => setFolderFilter(folder === '' ? null : ''))}
          </div>
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Procurar na coleção" className="mb-3 w-full rounded-xl bg-text/10 px-4 py-2" />
          {!collection?.list?.length && <p className="py-8 text-center text-muted">Sua coleção está vazia. Use o botão 📦 na página de uma carta, ou o scan do app.</p>}
          <ul className="space-y-1">
            {cards.map((c) => (
              <li key={c.id}>
                <div className="flex items-center gap-3 rounded-xl p-2 hover:bg-text/5">
                  <button type="button" onClick={() => setOpen(c)} className="flex min-w-0 flex-1 items-center gap-3 text-left">
                    <Thumb img={c.img} />
                    <span className="min-w-0">
                      <span className="block truncate font-bold">{c.name}</span>
                      <span className="block truncate text-xs text-muted">
                        {c.trade ? '🔁 ' : ''}
                        {c.folder ? `${c.folder} · ` : ''}
                        {c.set} · US$ {(c.usd || 0).toFixed(2)}
                        {c.eur > 0 ? ` · € ${c.eur.toFixed(2)}` : ''}
                      </span>
                    </span>
                  </button>
                  <button type="button" aria-label="Tirar uma" onClick={() => setQty(c.id, (c.qty || 1) - 1)} className="grid h-8 w-8 place-items-center rounded-full bg-text/10 text-lg">
                    −
                  </button>
                  <span className="w-6 text-center font-black">{c.qty || 1}</span>
                  <button type="button" aria-label="Mais uma" onClick={() => setQty(c.id, (c.qty || 1) + 1)} className="grid h-8 w-8 place-items-center rounded-full bg-text/10 text-lg">
                    +
                  </button>
                  <button
                    type="button"
                    aria-label="Pasta e troca"
                    title="Pasta e troca"
                    onClick={() => setOptions(options === c.id ? null : c.id)}
                    className={`grid h-8 w-8 place-items-center rounded-full text-lg ${options === c.id ? 'bg-accent text-white' : 'bg-text/10'}`}
                  >
                    ⋯
                  </button>
                </div>
                {options === c.id && <CardOptions card={c} folders={folders} onClose={() => setOptions(null)} />}
              </li>
            ))}
          </ul>
        </>
      ) : (
        <>
          <p className="mb-3 text-sm text-muted">
            Tudo: {money(wishes.reduce((a, c) => a + (c.usd || 0), 0), brl)}. O app confere os preços uma vez por dia e avisa quando algum cai.
          </p>
          {!wishes.length && <p className="py-8 text-center text-muted">Sua lista de desejos está vazia. Use o ♡ na página de uma carta.</p>}
          <ul className="space-y-1">
            {wishes.map((c) => {
              const diff = c.added > 0 ? ((c.usd - c.added) / c.added) * 100 : 0
              return (
                <li key={c.id} className="flex items-center gap-3 rounded-xl p-2 hover:bg-text/5">
                  <button type="button" onClick={() => setOpen(c)} className="flex min-w-0 flex-1 items-center gap-3 text-left">
                    <Thumb img={c.img} />
                    <span className="min-w-0">
                      <span className="block truncate font-bold">{c.name}</span>
                      <span className="block truncate text-xs text-muted">
                        {c.set} · quando entrou: US$ {(c.added || 0).toFixed(2)}
                      </span>
                    </span>
                  </button>
                  <span className="text-right">
                    <span className="block font-black">US$ {(c.usd || 0).toFixed(2)}</span>
                    {Math.round(diff) !== 0 && (
                      <span className={`block text-xs font-bold ${diff < 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                        {diff < 0 ? '▼' : '▲'} {Math.abs(diff).toFixed(0)}%
                      </span>
                    )}
                  </span>
                  <button type="button" aria-label="Tirar da lista" onClick={() => removeWish(c.id)} className="grid h-8 w-8 place-items-center rounded-full bg-text/10">
                    ✕
                  </button>
                </li>
              )
            })}
          </ul>
        </>
      )}
      {open && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 p-3 sm:p-6" onClick={() => setOpen(null)}>
          <div className="mx-auto my-4 max-w-5xl" onClick={(e) => e.stopPropagation()}>
            <CardDetails id={/^[0-9a-f-]{36}$/.test(open.id) ? open.id : undefined} onClose={() => setOpen(null)} />
          </div>
        </div>
      )}
    </div>
  )
}
