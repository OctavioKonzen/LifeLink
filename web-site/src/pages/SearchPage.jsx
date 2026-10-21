import { useEffect, useRef, useState } from 'react'
import CardGrid from '../components/CardGrid'
import { ErrorBox, Spinner } from '../components/ui'
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
  symbolUrl,
} from '../lib/scryfall'
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
      <h4 className="mb-2 text-xs font-bold uppercase tracking-wide text-accent">{title}</h4>
      <div className="flex max-h-40 flex-wrap gap-1.5 overflow-y-auto">
        {shown.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => onToggle(t)}
            className={`rounded-full px-3 py-1 text-xs font-semibold ${selected.includes(t) ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}
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
    <div className="mb-5 space-y-4 rounded-2xl bg-surface p-4">
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-sm font-bold">Cores:</span>
        {COLORS.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => toggle('colors', c)}
            className={`rounded-full border-[3px] transition ${filters.colors.includes(c) ? 'border-accent opacity-100' : 'border-transparent opacity-40'}`}
          >
            <img src={symbolUrl(c)} alt={c} width={34} height={34} />
          </button>
        ))}
      </div>
      <input
        value={typeFilter}
        onChange={(e) => setTypeFilter(e.target.value)}
        placeholder="Filtrar tipos e raças..."
        className="w-full rounded-lg border border-line bg-card px-3 py-2 text-sm"
      />
      <Chips title="Tipos e supertipos" options={catalogs.types} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <Chips title="Raças (criaturas)" options={catalogs.creatures} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <Chips title="Artefatos e encantamentos" options={catalogs.others} selected={filters.types} onToggle={(t) => toggle('types', t)} filter={typeFilter} />
      <label className="block">
        <span className="mb-1 block text-xs font-bold uppercase tracking-wide text-accent">Edição</span>
        <select
          value={filters.set || ''}
          onChange={(e) => setFilters((f) => ({ ...f, set: e.target.value || null }))}
          className="w-full rounded-lg border border-line bg-card px-3 py-2 text-sm"
        >
          <option value="">Todas</option>
          {catalogs.sets.map((s) => (
            <option key={s.code} value={s.code}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <div className="flex gap-3">
        <button
          type="button"
          onClick={() => setFilters({ types: [], colors: [], set: null })}
          className="flex-1 rounded-full border border-text/30 py-2 text-sm font-bold hover:bg-text/10"
        >
          Limpar
        </button>
        <button type="button" onClick={onClose} className="flex-1 rounded-full bg-accent py-2 text-sm font-bold hover:brightness-110">
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

  // Busca 600 ms depois de parar de digitar (igual ao app).
  useEffect(() => {
    if (submitted.current === text) return
    submitted.current = null
    const timer = setTimeout(() => setQuery(buildQuery(text, filters)), 600)
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
    search(query)
      .then((page) => alive && setResult({ cards: page.cards.filter((c) => imageOf(c)), nextPage: page.nextPage, loading: false, error: null }))
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
        const page = await search('', { nextPage: result.nextPage })
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
    setQuery(buildQuery(exactName ? `!"${value}"` : value, filters))
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
      <div className="relative mb-4 flex gap-2">
        <div className="relative flex-1">
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setTimeout(() => setFocused(false), 150)}
            onKeyDown={(e) => e.key === 'Enter' && submit(text)}
            placeholder="Nome ou texto da carta (em português ou inglês)..."
            className="w-full rounded-2xl border border-line bg-surface px-4 py-3 pr-10 outline-none focus:border-accent"
            type="search"
            enterKeyHint="search"
          />
          {focused && dropdown.length > 0 && (
            <div className="absolute left-0 right-0 top-full z-20 mt-1 overflow-hidden rounded-2xl border border-line bg-surface shadow-2xl">
              {!typing && (
                <div className="flex items-center justify-between px-4 pt-2 text-xs font-bold text-muted">
                  BUSCAS RECENTES
                  <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => setRecent(clearRecentSearches())} className="px-2 py-1 text-accent">
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
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-text/10"
                >
                  <span className="text-muted">{typing ? '🔍' : '🕘'}</span>
                  {item}
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowFilters((s) => !s)}
          className={`rounded-2xl px-4 font-bold ${showFilters || activeFilters ? 'bg-accent' : 'bg-surface hover:bg-text/10'}`}
        >
          Filtros{activeFilters ? ` (${activeFilters})` : ''}
        </button>
      </div>

      {showFilters && <Filters filters={filters} setFilters={updateFilters} catalogs={catalogs} onClose={() => setShowFilters(false)} />}

      {!typing && !activeFilters && <p className="mb-3 text-sm text-muted">Comandantes em ordem alfabética. Digite para buscar qualquer carta.</p>}

      {result.loading ? (
        <Spinner />
      ) : result.error ? (
        <ErrorBox message={result.error} onRetry={() => setRetry((r) => r + 1)} />
      ) : result.cards.length === 0 ? (
        <p className="py-12 text-center text-muted">
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
          {result.moreError && <p className="py-6 text-center text-sm text-red-400">{result.moreError}</p>}
        </>
      )}

    </div>
  )
}
