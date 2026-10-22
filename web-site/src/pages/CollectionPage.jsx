import { useEffect, useState } from 'react'
import CardDetails from '../components/CardDetails'
import { useUserData } from '../lib/userData'
import { dollarInReais } from '../lib/deckTools'
import { refreshPrices, removeWish, setQty, totalCards, totalUsd } from '../lib/collection'

// Minha coleção e lista de desejos, as mesmas do app (collection_screen.dart).
// Para guardar uma carta: os botões na página da carta (ou o scan do app).

const money = (usd, brl) => `US$ ${usd.toFixed(2)}${brl ? ` · R$ ${(usd * brl).toFixed(2)}` : ''}`

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

  const cards = (collection?.list || []).filter((c) => !query || `${c.name} ${c.set}`.toLowerCase().includes(query.toLowerCase()))
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
            <p className="text-xs text-muted">
              {totalCards(collection)} cartas · {(collection?.list || []).length} diferentes
            </p>
          </div>
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Procurar na coleção" className="mb-3 w-full rounded-xl bg-text/10 px-4 py-2" />
          {!collection?.list?.length && <p className="py-8 text-center text-muted">Sua coleção está vazia. Use o botão 📦 na página de uma carta, ou o scan do app.</p>}
          <ul className="space-y-1">
            {cards.map((c) => (
              <li key={c.id} className="flex items-center gap-3 rounded-xl p-2 hover:bg-text/5">
                <button type="button" onClick={() => setOpen(c)} className="flex min-w-0 flex-1 items-center gap-3 text-left">
                  <Thumb img={c.img} />
                  <span className="min-w-0">
                    <span className="block truncate font-bold">{c.name}</span>
                    <span className="block truncate text-xs text-muted">
                      {c.set} · US$ {(c.usd || 0).toFixed(2)}
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
