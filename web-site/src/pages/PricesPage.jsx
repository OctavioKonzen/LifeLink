import { useEffect, useState } from 'react'
import CardModal from '../components/CardModal'
import { ErrorBox, Spinner } from '../components/ui'
import { buildTextQuery, displayName, imageOf, search } from '../lib/scryfall'

/** As cartas mais caras do momento, igual à tela "Preços de hoje" do app. */
export default function PricesPage() {
  const [text, setText] = useState('')
  const [query, setQuery] = useState('')
  const [state, setState] = useState({ loading: true, cards: [], error: null })
  const [open, setOpen] = useState(null)
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    const timer = setTimeout(() => setQuery(text), 600)
    return () => clearTimeout(timer)
  }, [text])

  useEffect(() => {
    let alive = true
    setState({ loading: true, cards: [], error: null })
    const q = `${query.trim() ? `${buildTextQuery(query)} ` : ''}usd>0 lang:any`
    search(q, { order: 'usd', dir: 'desc', unique: 'prints', multilingual: false })
      .then((page) => alive && setState({ loading: false, cards: page.cards, error: null }))
      .catch((e) => alive && setState({ loading: false, cards: [], error: e.message }))
    return () => {
      alive = false
    }
  }, [query, retry])

  return (
    <div>
      <h1 className="mb-1 text-2xl font-black">Preços de hoje</h1>
      <p className="mb-4 text-sm text-muted">Valores do TCGplayer em dólar, atualizados pelo Scryfall uma vez por dia.</p>
      <input
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Pesquisar carta por preço..."
        type="search"
        className="mb-4 w-full rounded-2xl border border-line bg-surface px-4 py-3 outline-none focus:border-accent"
      />
      {state.loading ? (
        <Spinner />
      ) : state.error ? (
        <ErrorBox message={state.error} onRetry={() => setRetry((r) => r + 1)} />
      ) : state.cards.length === 0 ? (
        <p className="py-12 text-center text-muted">Nenhuma carta com preço encontrada.</p>
      ) : (
        <ol className="grid gap-2 md:grid-cols-2">
          {state.cards.map((c, i) => (
            <li key={c.id}>
              <button
                type="button"
                onClick={() => setOpen(c)}
                className="flex w-full items-center gap-3 rounded-xl bg-text/5 p-2 text-left hover:bg-text/10"
              >
                <img src={imageOf(c, 'small')} alt="" loading="lazy" className="h-[70px] w-[50px] shrink-0 rounded object-cover" />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-bold">{displayName(c)}</div>
                  <div className="truncate text-xs text-muted">
                    {c.set_name} · {c.lang.toUpperCase()}
                    {c.finishes?.includes('foil') && !c.finishes.includes('nonfoil') ? ' · Foil' : ''}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-black text-emerald-400">US$ {c.prices.usd ?? c.prices.usd_foil}</div>
                  {!query && <div className="text-[10px] text-text/30">#{i + 1}</div>}
                </div>
              </button>
            </li>
          ))}
        </ol>
      )}
      {open && <CardModal card={open} onClose={() => setOpen(null)} />}
    </div>
  )
}
