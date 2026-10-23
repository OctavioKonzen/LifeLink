import { useEffect, useState } from 'react'
import CardDetails from '../components/CardDetails'
import ExpandingGrid from '../components/ExpandingGrid'
import { ErrorBox, PageHeader, Spinner, panel } from '../components/ui'
import { ManaText } from '../components/Mana'
import { Search, Trophy } from 'lucide-react'
import { buildTextQuery, displayName, imageOf, manaCost, search } from '../lib/scryfall'
import { plainText, search as ownSearch, topPrices } from '../lib/lifelinkCards'

/** As cartas mais caras do momento, igual à tela "Preços de hoje" do app. */
export default function PricesPage() {
  const [text, setText] = useState('')
  const [query, setQuery] = useState('')
  const [state, setState] = useState({ loading: true, cards: [], error: null })
  const [retry, setRetry] = useState(0)

  useEffect(() => {
    const timer = setTimeout(() => setQuery(text), 600)
    return () => clearTimeout(timer)
  }, [text])

  useEffect(() => {
    let alive = true
    setState({ loading: true, cards: [], error: null })
    const text = query.trim()
    // Do banco do LifeLink: sem busca, as 600 versões mais caras (R2); com
    // busca, as cartas mais caras com aquele nome ou texto (Cloudflare). Se
    // ele não responder, da Scryfall.
    const load = async () => {
      if (plainText(text)) {
        try {
          const cards = text ? (await ownSearch({ text, order: 'usd', desc: true })).cards.filter((c) => c.prices.usd) : await topPrices()
          if (cards.length) return cards
        } catch {
          // Vai pela Scryfall.
        }
      }
      const q = `${text ? `${buildTextQuery(query)} ` : ''}usd>0 lang:any`
      return (await search(q, { order: 'usd', dir: 'desc', unique: 'prints', multilingual: false })).cards
    }
    load()
      .then((cards) => alive && setState({ loading: false, cards, error: null }))
      .catch((e) => alive && setState({ loading: false, cards: [], error: e.message }))
    return () => {
      alive = false
    }
  }, [query, retry])

  const priceOf = (c) => c.prices.usd ?? c.prices.usd_foil ?? c.prices.usd_etched
  const foilOnly = (c) => c.prices.usd == null
  const podium = !query && state.cards.length >= 2 ? state.cards.slice(0, 2) : []

  return (
    <div>
      <PageHeader title="Preços de hoje" description="As cartas mais caras do dia, em dólar (TCGplayer), atualizadas uma vez por dia." />
      <label className={`${panel} relative mb-6 block p-3`}>
        <span className="sr-only">Pesquisar carta por preço</span>
        <Search className="pointer-events-none absolute left-6.5 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Pesquisar carta por preço..."
          type="search"
          className="h-11 w-full rounded-xl bg-bg pl-10 pr-3 text-sm placeholder:text-muted/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
        />
      </label>

      {podium.length > 0 && !state.loading && (
        <div className="mb-8 grid gap-4 md:grid-cols-2">
          {podium.map((c, i) => (
            <div key={c.id} className={`${panel} relative flex items-center gap-5 overflow-hidden p-5`}>
              <img src={imageOf(c, 'normal')} alt="" className="h-28 w-20 shrink-0 rounded-lg object-cover shadow-lg shadow-black/40" />
              <div className="flex min-w-0 flex-col gap-1">
                <span className="flex items-center gap-1.5 text-xs font-medium uppercase tracking-widest text-muted">
                  <Trophy className={`size-3.5 ${i === 0 ? 'text-accent' : ''}`} aria-hidden="true" /> {i === 0 ? 'A mais cara de hoje' : 'Em segundo'}
                </span>
                <span className="truncate text-lg font-semibold">{displayName(c)}</span>
                <span className="truncate text-sm text-muted">{c.set_name}</span>
                <span className="text-xl font-semibold text-success">
                  US$ {priceOf(c)}
                  {foilOnly(c) && <span className="ml-1 text-sm text-muted">foil</span>}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      {state.loading ? (
        <Spinner />
      ) : state.error ? (
        <ErrorBox message={state.error} onRetry={() => setRetry((r) => r + 1)} />
      ) : state.cards.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-line py-16 text-center text-muted">Nenhuma carta com preço encontrada.</p>
      ) : (
        <div className={`${panel} overflow-hidden`}>
          <div className="flex items-center gap-3 border-b border-line px-5 py-3 text-sm text-muted">
            <span className="flex-1">Carta</span>
            <span className="hidden w-28 sm:block">Custo</span>
            <span className="w-32 text-right">Preço</span>
            {!query && <span className="hidden w-10 text-right sm:block">#</span>}
          </div>
          <ExpandingGrid
            items={state.cards}
            keyOf={(c) => c.id}
            minWidth={100000}
            gap={0}
            renderItem={(c, i, open, selected) => (
              <button
                type="button"
                onClick={open}
                className={`flex w-full cursor-pointer items-center gap-3 border-b border-line/60 px-5 py-3 text-left text-sm ${selected ? 'bg-card' : 'hover:bg-card/50'}`}
              >
                <img src={imageOf(c, 'small')} alt="" loading="lazy" className="h-12 w-9 shrink-0 rounded-md object-cover" />
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium">{displayName(c)}</span>
                  <span className="block truncate text-xs text-muted">
                    {c.set_name} · {c.lang.toUpperCase()}
                    {c.finishes?.includes('foil') && !c.finishes.includes('nonfoil') ? ' · Foil' : ''}
                  </span>
                </span>
                <span className="hidden w-28 sm:block">
                  <ManaText text={manaCost(c)} size={14} />
                </span>
                <span className="w-32 whitespace-nowrap text-right font-semibold text-success">
                  US$ {priceOf(c)}
                  {foilOnly(c) && <span className="block text-[10px] font-normal text-muted">foil</span>}
                </span>
                {!query && <span className="hidden w-10 text-right text-xs text-muted sm:block">{i + 1}</span>}
              </button>
            )}
            renderPanel={(c, { close, previous, next }) => (
              <div className="p-3">
                <CardDetails card={c} onClose={close} onPrevious={previous} onNext={next} />
              </div>
            )}
          />
        </div>
      )}
    </div>
  )
}
