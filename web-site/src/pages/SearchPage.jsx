import { useEffect, useRef, useState } from 'react'
import CardGrid from '../components/CardGrid'
import { ErrorBox, Modal, PageHeader, Spinner, inputClass, panel } from '../components/ui'
import { ArrowUpDown, ChevronDown, Clock, Search, SlidersHorizontal, X } from 'lucide-react'
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
import { useUserData } from '../lib/userData'

// As opções dos filtros, iguais às do app (card_filters_sheet.dart).
const COLOR_OPTIONS = [
  ['W', 'Branco', '#F3E9C6', '#4A3F1F'],
  ['U', 'Azul', '#2F7FD0'],
  ['B', 'Preto', '#4A4045'],
  ['R', 'Vermelho', '#D9412E'],
  ['G', 'Verde', '#2E8B57'],
  ['C', 'Incolor', '#A9A7A2', '#2B2B2B'],
]
const TYPE_OPTIONS = [
  ['Creature', 'Criatura', '#7AC74C'],
  ['Instant', 'Instantânea', '#6390F0'],
  ['Sorcery', 'Feitiço', '#EE8130'],
  ['Enchantment', 'Encantamento', '#A98FF3'],
  ['Artifact', 'Artefato', '#8E9AAF'],
  ['Land', 'Terreno', '#C9A55A'],
  ['Planeswalker', 'Planeswalker', '#F95587'],
  ['Battle', 'Batalha', '#C22E28'],
  ['Legendary', 'Lendária', '#B6A136'],
]
const COLOR_ORDER = ['W', 'U', 'B', 'R', 'G', 'C']

// A ordem dos resultados, igual ao app: [nome, ordem, direção].
export const ORDERS = [
  ['Nome (A-Z)', 'name', null],
  ['Mais caras', 'usd', 'desc'],
  ['Mais baratas', 'usd', 'asc'],
  ['Custo de mana', 'cmc', 'asc'],
  ['Mais novas', 'released', 'desc'],
]

export const noFilters = () => ({ colors: [], types: [], race: null, subtype: null, set: null, setName: null })
export const filterCount = (f) => f.colors.length + f.types.length + (f.race ? 1 : 0) + (f.subtype ? 1 : 0) + (f.set ? 1 : 0)

/** A busca da Scryfall (a reserva), igual ao app: um dos tipos E a raça E o subtipo E as cores E a coleção. */
export function buildQuery(text, f = noFilters()) {
  let q = text.trim() ? buildTextQuery(text) : 'is:commander'
  const parts = [
    f.types.length === 1 ? `t:"${f.types[0]}"` : f.types.length ? `(${f.types.map((t) => `t:"${t}"`).join(' or ')})` : '',
    f.race ? `t:"${f.race}"` : '',
    f.subtype ? `t:"${f.subtype}"` : '',
    f.colors.length ? `id<=${COLOR_ORDER.filter((c) => f.colors.includes(c)).join('')}` : '',
    f.set ? `set:${f.set}` : '',
  ].filter(Boolean)
  if (parts.length) q += ` ${parts.join(' ')}`
  return q
}

/**
 * A mesma busca do app no banco do LifeLink (a busca da Cloudflare), ou null
 * quando ela fica com a Scryfall (quem digita a sintaxe dela: t:, o:...).
 */
export function ownQuery(text, f = noFilters(), order = ORDERS[0], lang = 'pt') {
  let t = text.trim()
  const exact = /^!"(.*)"$/.exec(t)
  if (exact) t = exact[1]
  if (!plainText(t)) return null
  const userOrder = order[1] !== ORDERS[0][1]
  const empty = !t && !filterCount(f)
  return {
    // Só a coleção escolhida: todas as cartas dela na ordem dos números.
    setOnly: !t && !!f.set && !f.types.length && !f.colors.length && !f.race && !f.subtype && !userOrder,
    text: t,
    nameOnly: !!exact,
    // Os tipos, a raça e o subtipo juntos; sem nada, os comandantes mais jogados.
    types: [...f.types, ...(f.race ? [f.race] : []), ...(f.subtype ? [f.subtype] : []), ...(empty ? ['Legendary Creature'] : [])],
    set: f.set || '',
    colors: f.colors.length ? f.colors.join('') : undefined,
    // Com texto: por relevância; sem texto: as mais jogadas; ou a ordem escolhida.
    order: userOrder ? order[1] : t ? undefined : 'popular',
    desc: order[2] === 'desc',
    lang,
  }
}

function useCatalogs() {
  const [data, setData] = useState({ races: [], subtypes: [], sets: [] })
  useEffect(() => {
    Promise.all([catalog('creature-types'), catalog('artifact-types'), catalog('enchantment-types'), loadSets()]).then(([creatures, art, ench, sets]) =>
      setData({
        races: creatures || [],
        subtypes: [...(art || []), ...(ench || [])].sort(),
        sets: sets || [],
      }),
    )
  }, [])
  return data
}

/** Grade de 3 colunas com botões coloridos (cores e tipos), como no app. */
function Grid({ options, selected, onToggle }) {
  return (
    <div className="grid grid-cols-3 gap-2.5">
      {options.map(([value, label, color, ink = '#fff']) => {
        const on = selected.includes(value)
        const dim = selected.length > 0 && !on
        return (
          <button
            key={value}
            type="button"
            onClick={() => onToggle(value)}
            aria-pressed={on}
            style={{ background: color, color: ink }}
            className={`h-12 cursor-pointer truncate rounded-2xl px-2 text-sm font-bold transition ${dim ? 'opacity-35' : ''} ${on ? 'ring-2 ring-inset ring-white' : ''}`}
          >
            {label}
          </button>
        )
      })}
    </div>
  )
}

/** Botão em pílula que abre uma lista com busca (coleção, raça, subtipo), como no app. */
function PickList({ label, value, gradient, items, onPick }) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const shown = q ? items.filter((i) => i.label.toLowerCase().includes(q.toLowerCase())) : items
  return (
    <div>
      <div
        className="inline-flex max-w-full items-center gap-2 rounded-full py-2.5 pl-5 pr-3 text-base font-bold text-white shadow-md"
        style={{ background: value ? `linear-gradient(90deg, ${gradient[0]}, ${gradient[1]})` : 'linear-gradient(90deg, #455A64, #37474F)' }}
      >
        <button type="button" onClick={() => setOpen((o) => !o)} className="cursor-pointer truncate">
          {value || label}
        </button>
        {value ? (
          <button type="button" aria-label="Tirar" onClick={() => onPick(null)} className="grid cursor-pointer place-items-center">
            <X className="size-5" aria-hidden="true" />
          </button>
        ) : (
          <button type="button" aria-label="Abrir" onClick={() => setOpen((o) => !o)} className="grid cursor-pointer place-items-center">
            <ChevronDown className="size-5" aria-hidden="true" />
          </button>
        )}
      </div>
      {open && (
        <div className="mt-3 rounded-xl border border-line bg-bg p-2">
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={`Procurar ${label.toLowerCase().replace(/^tod[ao]s? (as |os )?/, '')}`} className={inputClass} />
          <div className="mt-2 max-h-60 overflow-y-auto">
            {shown.length === 0 && <p className="py-4 text-center text-sm text-muted">Nada encontrado.</p>}
            {shown.map((i) => (
              <button
                key={i.value}
                type="button"
                onClick={() => {
                  onPick(i)
                  setOpen(false)
                  setQ('')
                }}
                className="block w-full cursor-pointer rounded-lg px-3 py-2 text-left text-sm hover:bg-card"
              >
                {i.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

/** O painel de filtros do app: coleção, cores, tipo, raça e subtipo, e "Ver cartas". */
function Filters({ initial, catalogs, onApply, onClose }) {
  const [f, setF] = useState(initial)
  const toggle = (key, value) => setF((old) => ({ ...old, [key]: old[key].includes(value) ? old[key].filter((v) => v !== value) : [...old[key], value] }))
  const count = filterCount(f)
  const label = (text) => <h4 className="mb-2.5 mt-6 text-[15px] font-semibold text-muted">{text}</h4>
  return (
    <Modal onClose={onClose}>
      <div className="flex items-center gap-3 pr-10">
        <h3 className="flex-1 text-3xl font-bold">Filtros</h3>
        {count > 0 && (
          <button type="button" onClick={() => setF(noFilters())} className="cursor-pointer text-sm font-semibold text-accent">
            Limpar
          </button>
        )}
      </div>
      {label('Coleção')}
      <PickList
        label="Todas as coleções"
        value={f.setName}
        gradient={['#26A69A', '#42A5F5']}
        items={catalogs.sets.map((s) => ({ value: s.code, label: s.name }))}
        onPick={(i) => setF((old) => ({ ...old, set: i?.value ?? null, setName: i?.label ?? null }))}
      />
      {label('Cores')}
      <Grid options={COLOR_OPTIONS} selected={f.colors} onToggle={(c) => toggle('colors', c)} />
      {label('Tipo')}
      <Grid options={TYPE_OPTIONS} selected={f.types} onToggle={(t) => toggle('types', t)} />
      {label('Raça (criaturas)')}
      <PickList
        label="Todas as raças"
        value={f.race}
        gradient={['#66BB6A', '#26A69A']}
        items={catalogs.races.map((r) => ({ value: r, label: r }))}
        onPick={(i) => setF((old) => ({ ...old, race: i?.value ?? null }))}
      />
      {label('Subtipo (equipamentos, auras...)')}
      <PickList
        label="Todos os subtipos"
        value={f.subtype}
        gradient={['#AB47BC', '#7E57C2']}
        items={catalogs.subtypes.map((r) => ({ value: r, label: r }))}
        onPick={(i) => setF((old) => ({ ...old, subtype: i?.value ?? null }))}
      />
      <button type="button" onClick={() => onApply(f)} className="mt-8 h-14 w-full cursor-pointer rounded-xl bg-[#0288D1] text-[17px] font-semibold text-white hover:brightness-110">
        {count === 0 ? 'Ver todas as cartas' : `Ver cartas (${count} ${count === 1 ? 'filtro' : 'filtros'})`}
      </button>
    </Modal>
  )
}

export default function SearchPage() {
  const [text, setText] = useState('')
  const lang = useUserData((s) => s.settings?.cardLanguage) || 'pt'
  const [query, setQuery] = useState(() => buildQuery(''))
  const [filters, setFilters] = useState(noFilters)
  const [order, setOrder] = useState(ORDERS[0])
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
  const asked = useRef(ownQuery('', noFilters(), ORDERS[0], lang))
  const ask = (value, f, o = order) => {
    asked.current = ownQuery(value, f, o, lang)
    // A ordem e o idioma também mudam a busca (refaz mesmo com o texto igual).
    setQuery(`${buildQuery(value, f)}\u0000${o[1]}:${o[2] || ''}:${lang}`)
  }

  // Busca 600 ms depois de parar de digitar (igual ao app).
  useEffect(() => {
    if (submitted.current === text) return
    submitted.current = null
    const timer = setTimeout(() => ask(text, filters, order), 600)
    return () => clearTimeout(timer)
  }, [text, filters, order, lang])

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
    const [scryfallQuery, orderKey] = query.split('\u0000')
    const [orderName, orderDir] = (orderKey || 'name:').split(':')
    // Igual ao app: no banco do LifeLink; a Scryfall só se ele não responder.
    const load = async () => {
      if (own) {
        try {
          if (own.setOnly) {
            const cards = await setCards(own.set, own.lang)
            if (cards.length) return { cards, nextPage: null, source: 'lifelink' }
          }
          const page = await ownSearch({ ...own, page: 0 })
          return { cards: page.cards, nextPage: page.hasMore ? { own, page: 1 } : null, source: 'lifelink' }
        } catch {
          // Vai pela Scryfall.
        }
      }
      const page = await search(scryfallQuery, { order: orderName, dir: orderDir || undefined })
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

  // Filtro ou ordem nova sempre refaz a busca, mesmo depois de um submit().
  const updateFilters = (f) => {
    submitted.current = null
    setFilters(f)
    setShowFilters(false)
  }
  const updateOrder = (o) => {
    submitted.current = null
    setOrder(o)
  }

  const openCard = () => {
    if (text.trim()) setRecent(addRecentSearch(text))
  }

  const typing = text.trim().length > 0
  const dropdown = typing ? suggestions : recent
  const activeFilters = filterCount(filters)

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
        <div className="flex items-center gap-2">
          {/* A ordem dos resultados, como no app. */}
          <label className="relative flex-1 sm:flex-none">
            <span className="sr-only">Ordenar</span>
            <ArrowUpDown className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
            <select
              value={order[0]}
              onChange={(e) => updateOrder(ORDERS.find((o) => o[0] === e.target.value))}
              className="h-10 w-full cursor-pointer appearance-none rounded-xl bg-card pl-9 pr-8 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
            >
              {ORDERS.map((o) => (
                <option key={o[0]}>{o[0]}</option>
              ))}
            </select>
            <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
          </label>
          <button
            type="button"
            onClick={() => setShowFilters(true)}
            className={`h-10 cursor-pointer gap-2 rounded-xl px-3 text-sm font-medium inline-flex items-center ${activeFilters ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`}
          >
            <SlidersHorizontal className="size-4" aria-hidden="true" />
            Filtros
            {activeFilters > 0 && <span>({activeFilters})</span>}
          </button>
        </div>
      </div>

      {showFilters && <Filters initial={filters} catalogs={catalogs} onApply={updateFilters} onClose={() => setShowFilters(false)} />}

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
