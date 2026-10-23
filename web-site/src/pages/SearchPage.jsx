import { useEffect, useRef, useState } from 'react'
import CardGrid from '../components/CardGrid'
import { ErrorBox, PageHeader, Spinner, btnOutline, btnPrimary, inputClass, panel } from '../components/ui'
import { ManaPip } from '../components/Mana'
import { Clock, Search, SlidersHorizontal } from 'lucide-react'
import {
  addRecentSearch,
  autocomplete,
  buildTextQuery,
  catalog,
  clearRecentSearches,
  imageOf,
  recentSearches,
  search,
  sets as loadSets,
} from '../lib/scryfall'
import { plainText, search as ownSearch, setCards } from '../lib/lifelinkCards'
import { incrementSearches } from '../lib/xp'

const COLORS = ['W', 'U', 'B', 'R', 'G', 'C']

// Listas de reserva, iguais às do app, enquanto os catálogos não chegam.
const BASE_TYPES = ['Artifact', 'Battle', 'Creature', 'Enchantment', 'Instant', 'Land', 'Planeswalker', 'Sorcery', 'Basic', 'Legendary', 'Snow']

/** A mesma busca do app (card_search_screen.dart). */
export function buildQuery(text, { types = [], colors = [], set = null } = {}) {
  let q = text.trim() ? buildTextQuery(text) : 'is:commander'
  if (types.length) q += ` (${types.map((t) => `t:"${t}"`).join(' or ')})`
  if (colors.length) q += ` id<=${colors.join('')}`
  if (set) q += ` set:${set}`
  return q
}

/**
 * A mesma busca no banco do LifeLink (a busca da Cloudflare), ou null quando
 * ela fica com a Scryfall: sintaxe da Scryfall (t:, o:, usd>...) ou mais de
 * um tipo marcado (a Scryfall junta os tipos com "ou").
 */
export function ownQuery(text, { types = [], colors = [], set = null } = {}) {
  let t = text.trim()
  const exact = /^!"(.*)"$/.exec(t)
  if (exact) t = exact[1]
  if (!plainText(t) || types.length > 1) return null
  const empty = !t && !types.length && !colors.length && !set
  return {
    // Só a coleção escolhida: todas as cartas dela na ordem dos números.
    setOnly: !t && !types.length && !colors.length && !!set,
    text: t,
    nameOnly: !!exact,
    // Sem texto: os comandantes mais jogados (como o "is:commander").
    types: empty ? ['Legendary Creature'] : types,
    set: set || '',
    colors: colors.length ? colors.join('') : undefined,
    // Com texto: por relevância (o padrão da busca); sem texto: as mais jogadas.
    order: t ? undefined : 'popular',
  }
}

function useCatalogs() {
  const [data, setData] = useState({ types: BASE_TYPES, creatures: [], others: [], sets: [] })
  useEffect(() => {
    Promise.all([
      catalog('supertypes'),
      catalog('card-types'),
      catalog('creature-types'),
      catalog('artifact-types'),
      catalog('enchantment-types'),
      loadSets(),
    ]).then(([sup, card, creatures, art, ench, sets]) =>
      setData({
        types: sup && card ? [...sup, ...card] : BASE_TYPES,
        creatures: creatures || [],
        others: [...(art || []), ...(ench || [])],
        sets: sets || [],
      }),
    )
  }, [])
  return data
}

function Chips({ title, options, selected, onToggle, filter = '' }) {
  const shown = filter ? options.filter((o) => o.toLowerCase().includes(filter.toLowerCase())) : options
  if (!shown.length) return null
  return (
    <div>
      <h4 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">{title}</h4>
      <div className="flex max-h-40 flex-wrap gap-1.5 overflow-y-auto">
        {shown.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => onToggle(t)}
            className={`cursor-pointer rounded-lg px-3 py-1.5 text-xs font-medium ${selected.includes(t) ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`}
          >
            {t}
          </button>
        ))}
      </div>
    </div>
  )
}

function Filters({ filters, setFilters, catalogs, onClose }) {
  const [typeFilter, setTypeFilter] = useState('')
  const toggle = (key, value) =>
    setFilters((f) => ({ ...f, [key]: f[key].includes(value) ? f[key].filter((v) => v !== value) : [...f[key], value] }))
  return (
    <div className={`${panel} page-in mb-6 space-y-5 p-5`}>
      <input value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)} placeholder="Filtrar tipos e raças..." className={inputClass} />
      <Chips title="Tipos e supertipos" options={catalogs.types} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <Chips title="Raças (criaturas)" options={catalogs.creatures} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <Chips title="Artefatos e encantamentos" options={catalogs.others} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <label className="block">
        <span className="mb-2 block text-xs font-medium uppercase tracking-widest text-muted">Edição</span>
        <select value={filters.set || ''} onChange={(e) => setFilters((f) => ({ ...f, set: e.target.value || null }))} className={inputClass}>
          <option value="">Todas</option>
          {catalogs.sets.map((s) => (
            <option key={s.code} value={s.code}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <div className="flex gap-3">
        <button type="button" onClick={() => setFilters({ types: [], colors: [], set: null })} className={`${btnOutline} flex-1`}>
          Limpar
        </button>
        <button type="button" onClick={onClose} className={`${btnPrimary} flex-1`}>
          Fechar
        </button>
      </div>
    </div>
  )
}

export default function SearchPage() {
  const [text, setText] = useState('')
  const [query, setQuery] = useState(() => buildQuery(''))
  const [filters, setFilters] = useState({ types: [], colors: [], set: null })
  const [showFilters, setShowFilters] = useState(false)
  const [result, setResult] = useState({ cards: [], nextPage: null, loading: true, error: null })
  const [suggestions, setSuggestions] = useState([])
  const [recent, setRecent] = useState(recentSearches)
  const [focused, setFocused] = useState(false)
  const [retry, setRetry] = useState(0)
  const catalogs = useCatalogs()
  const sentinel = useRef(null)
  const loadingMore = useRef(false)
  const submitted = useRef(null) // busca já feita por submit(): o atraso não refaz
  // O que foi pedido na última busca (para a busca no banco do LifeLink).
  const asked = useRef(ownQuery(''))
  const ask = (value, f) => {
    asked.current = ownQuery(value, f)
    setQuery(buildQuery(value, f))
  }

  // Busca 600 ms depois de parar de digitar (igual ao app).
  useEffect(() => {
    if (submitted.current === text) return
    submitted.current = null
    const timer = setTimeout(() => ask(text, filters), 600)
    return () => clearTimeout(timer)
  }, [text, filters])

  // Sugestões de nomes 200 ms depois de parar de digitar.
  useEffect(() => {
    if (text.trim().length < 2) {
      setSuggestions([])
      return
    }
    let alive = true
    const timer = setTimeout(() => autocomplete(text).then((names) => alive && setSuggestions(names.slice(0, 8))), 200)
    return () => {
      alive = false
      clearTimeout(timer)
    }
  }, [text])

  // Cada busca feita conta para as missões (igual ao app).
  const firstQuery = useRef(query)
  useEffect(() => {
    if (query !== firstQuery.current) incrementSearches()
  }, [query])

  useEffect(() => {
    let alive = true
    setResult({ cards: [], nextPage: null, loading: true, error: null })
    const own = asked.current
    // Primeiro no banco do LifeLink; se ele não responder (ou não achar nada), na Scryfall.
    const load = async () => {
      if (own) {
        try {
          if (own.setOnly) {
            const cards = await setCards(own.set)
            if (cards.length) return { cards, nextPage: null, source: 'lifelink' }
          }
          const page = await ownSearch({ ...own, page: 0 })
          if (page.cards.length) return { cards: page.cards, nextPage: page.hasMore ? { own, page: 1 } : null, source: 'lifelink' }
        } catch {
          // Vai pela Scryfall.
        }
      }
      const page = await search(query)
      return { cards: page.cards.filter((c) => imageOf(c)), nextPage: page.nextPage, source: 'scryfall' }
    }
    load()
      .then((page) => alive && setResult({ ...page, loading: false, error: null }))
      .catch((e) => alive && setResult({ cards: [], nextPage: null, loading: false, error: e.message }))
    return () => {
      alive = false
    }
  }, [query, retry])

  // Carrega a próxima página ao chegar perto do fim.
  useEffect(() => {
    const el = sentinel.current
    if (!el || !result.nextPage) return
    const observer = new IntersectionObserver(async ([entry]) => {
      if (!entry.isIntersecting || loadingMore.current) return
      loadingMore.current = true
      try {
        const more = result.nextPage
        if (typeof more === 'object') {
          // Próxima página da busca do LifeLink.
          const page = await ownSearch({ ...more.own, page: more.page })
          setResult((r) => ({ ...r, cards: [...r.cards, ...page.cards], nextPage: page.hasMore ? { own: more.own, page: more.page + 1 } : null }))
          return
        }
        const page = await search('', { nextPage: more })
        setResult((r) => ({ ...r, cards: [...r.cards, ...page.cards.filter((c) => imageOf(c))], nextPage: page.nextPage }))
      } catch (e) {
        setResult((r) => ({ ...r, nextPage: null, moreError: e.message }))
      } finally {
        loadingMore.current = false
      }
    }, { rootMargin: '600px' })
    observer.observe(el)
    return () => observer.disconnect()
  }, [result.nextPage])

  // Busca escolhida de propósito (Enter, sugestão ou recente): vai para as recentes.
  const submit = (value, exactName = false) => {
    submitted.current = value
    setText(value)
    setSuggestions([])
    setFocused(false)
    document.activeElement?.blur()
    setRecent(addRecentSearch(value))
    ask(exactName ? `!"${value}"` : value, filters)
  }

  // Filtro novo sempre refaz a busca, mesmo depois de um submit().
  const updateFilters = (update) => {
    submitted.current = null
    setFilters(update)
  }

  const openCard = () => {
    if (text.trim()) setRecent(addRecentSearch(text))
  }

  const typing = text.trim().length > 0
  const dropdown = typing ? suggestions : recent
  const activeFilters = filters.types.length + filters.colors.length + (filters.set ? 1 : 0)

  return (
    <div>
      <PageHeader title="Cartas" description="Busque qualquer carta, em português ou inglês, e veja detalhes, versões e preço." />
      <div className={`${panel} relative mb-6 flex flex-col gap-3 p-3 sm:flex-row sm:items-center`}>
        <label className="relative flex-1">
          <span className="sr-only">Buscar cartas</span>
          <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setTimeout(() => setFocused(false), 150)}
            onKeyDown={(e) => e.key === 'Enter' && submit(text)}
            placeholder="Nome ou texto da carta, ex: Raio"
            className="h-11 w-full rounded-xl bg-bg pl-10 pr-3 text-sm placeholder:text-muted/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
            type="search"
            enterKeyHint="search"
          />
          {focused && dropdown.length > 0 && (
            <div className="absolute left-0 right-0 top-full z-20 mt-2 overflow-hidden rounded-xl border border-line bg-surface shadow-2xl">
              {!typing && (
                <div className="flex items-center justify-between px-4 pt-2 text-xs font-medium uppercase tracking-widest text-muted">
                  Buscas recentes
                  <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => setRecent(clearRecentSearches())} className="cursor-pointer px-2 py-1 normal-case tracking-normal text-accent">
                    Limpar
                  </button>
                </div>
              )}
              {dropdown.map((item) => (
                <button
                  key={item}
                  type="button"
                  onMouseDown={(e) => e.preventDefault()}
                  onClick={() => submit(item, typing)}
                  className="flex w-full cursor-pointer items-center gap-3 px-4 py-2.5 text-left text-sm hover:bg-card"
                >
                  {typing ? <Search className="size-4 text-muted" aria-hidden="true" /> : <Clock className="size-4 text-muted" aria-hidden="true" />}
                  {item}
                </button>
              ))}
            </div>
          )}
        </label>
        <div className="flex items-center gap-1.5">
          <div className="flex items-center gap-1" role="group" aria-label="Filtrar por cor">
            {COLORS.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => updateFilters((f) => ({ ...f, colors: f.colors.includes(c) ? f.colors.filter((v) => v !== c) : [...f.colors, c] }))}
                aria-pressed={filters.colors.includes(c)}
                className={`grid size-10 cursor-pointer place-items-center rounded-xl border transition ${
                  filters.colors.includes(c) ? 'border-accent bg-card' : 'border-transparent opacity-60 hover:opacity-100'
                }`}
              >
                <ManaPip color={c} size="md" />
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={() => setShowFilters((s) => !s)}
            aria-expanded={showFilters}
            className={`ml-auto h-10 cursor-pointer gap-2 rounded-xl px-3 text-sm font-medium inline-flex items-center ${showFilters || filters.types.length || filters.set ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`}
          >
            <SlidersHorizontal className="size-4" aria-hidden="true" />
            <span className="hidden sm:inline">Filtros</span>
            {filters.types.length + (filters.set ? 1 : 0) > 0 && <span>({filters.types.length + (filters.set ? 1 : 0)})</span>}
          </button>
        </div>
      </div>

      {showFilters && <Filters filters={filters} setFilters={updateFilters} catalogs={catalogs} onClose={() => setShowFilters(false)} />}

      {!typing && !activeFilters && (
        <p className="mb-4 text-sm text-muted">
          {result.source === 'lifelink' ? 'Os comandantes mais jogados.' : 'Comandantes em ordem alfabética.'} Digite para buscar qualquer carta.
        </p>
      )}

      {result.loading ? (
        <Spinner />
      ) : result.error ? (
        <ErrorBox message={result.error} onRetry={() => setRetry((r) => r + 1)} />
      ) : result.cards.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-line py-16 text-center text-muted">
          Nenhuma carta encontrada.
          <br />
          Tente outro nome, em português ou inglês, ou uma palavra do texto da carta em inglês.
        </p>
      ) : (
        <>
          <CardGrid cards={result.cards} onOpen={openCard} />
          {result.nextPage && (
            <div ref={sentinel}>
              <Spinner />
            </div>
          )}
          {result.moreError && <p className="py-6 text-center text-sm text-danger">{result.moreError}</p>}
        </>
      )}

    </div>
  )
}
