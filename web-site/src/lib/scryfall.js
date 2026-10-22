// Acesso ao Scryfall, igual ao do app (lib/data/services/scryfall_service.dart):
// um pedido de cada vez (o Scryfall pede no máximo 10 por segundo), respostas
// guardadas por 10 minutos e mensagens de erro compreensíveis.

import { names as ownNames, scryfallCard } from './lifelinkCards'

const BASE = 'https://api.scryfall.com'
const CACHE_MS = 10 * 60 * 1000
const MIN_INTERVAL_MS = 100

const cache = new Map()
let queue = Promise.resolve()
let lastRequest = 0

export class ScryfallError extends Error {
  constructor(message, { notFound = false } = {}) {
    super(message)
    this.notFound = notFound
  }
}

/** Transforma a resposta de erro do Scryfall numa mensagem para a tela. */
export function errorFor(status, data = {}) {
  switch (status) {
    case 404:
      return new ScryfallError('Nenhuma carta encontrada.', { notFound: true })
    case 400:
      return new ScryfallError(
        data.details ? `Não entendi essa busca: ${data.details}` : 'Não entendi essa busca. Confira o que foi digitado.',
      )
    case 429:
      return new ScryfallError('Muitas buscas seguidas. Espere alguns segundos e tente de novo.')
    default:
      return new ScryfallError(`O Scryfall está com problemas agora (erro ${status}). Tente mais tarde.`)
  }
}

function waitTurn() {
  const turn = queue.then(async () => {
    const wait = MIN_INTERVAL_MS - (Date.now() - lastRequest)
    if (wait > 0) await new Promise((r) => setTimeout(r, wait))
    lastRequest = Date.now()
  })
  queue = turn.catch(() => {})
  return turn
}

export async function getJson(url, { useCache = true } = {}) {
  const hit = cache.get(url)
  if (useCache && hit && Date.now() - hit.at < CACHE_MS) return hit.data

  await waitTurn()
  let response
  try {
    response = await fetch(url, { headers: { Accept: 'application/json' } })
  } catch {
    throw new ScryfallError('Sem conexão com a internet.')
  }
  let data
  try {
    data = await response.json()
  } catch {
    throw new ScryfallError(`Resposta inválida do Scryfall (erro ${response.status}).`)
  }
  if (!response.ok) throw errorFor(response.status, data)
  cache.set(url, { at: Date.now(), data })
  return data
}

/** POST (ex.: /cards/collection, até 75 cartas por pedido). */
export async function postJson(url, body) {
  await waitTurn()
  let response
  try {
    response = await fetch(url, { method: 'POST', headers: { Accept: 'application/json', 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
  } catch {
    throw new ScryfallError('Sem conexão com a internet.')
  }
  let data
  try {
    data = await response.json()
  } catch {
    throw new ScryfallError(`Resposta inválida do Scryfall (erro ${response.status}).`)
  }
  if (!response.ok) throw errorFor(response.status, data)
  return data
}

/**
 * Pesquisa cartas. Com multilingual, o nome também é procurado nos outros
 * idiomas (ex.: "Raio" encontra "Lightning Bolt").
 */
export async function search(query, { order = 'name', dir, unique, multilingual = true, nextPage } = {}) {
  const params = new URLSearchParams({ q: query, order })
  if (dir) params.set('dir', dir)
  if (unique) params.set('unique', unique)
  if (multilingual) params.set('include_multilingual', 'true')
  const url = nextPage || `${BASE}/cards/search?${params}`
  try {
    const data = await getJson(url)
    return { cards: data.data || [], hasMore: !!data.has_more, nextPage: data.has_more ? data.next_page : null }
  } catch (e) {
    if (e.notFound) return { cards: [], hasMore: false, nextPage: null }
    throw e
  }
}

/** Sugestões de nomes enquanto a pessoa digita. */
export async function autocomplete(text) {
  const q = text.trim()
  if (q.length < 2) return []
  // Nomes do banco do LifeLink (português e inglês); sem ele, da Scryfall.
  try {
    const list = await ownNames(q)
    if (list.length) return list
  } catch {
    // O banco do LifeLink não respondeu: vai pela Scryfall.
  }
  try {
    const params = new URLSearchParams({ q, include_multilingual: 'true' })
    const data = await getJson(`${BASE}/cards/autocomplete?${params}`)
    return data.data || []
  } catch {
    return []
  }
}

/** A carta pelo código: do banco do LifeLink (R2); sem ele, da Scryfall. */
export async function cardById(id) {
  try {
    const own = await scryfallCard(id)
    if (own) return own
  } catch {
    // O R2 não respondeu: vai pela Scryfall.
  }
  return getJson(`${BASE}/cards/${encodeURIComponent(id)}`)
}

/**
 * Monta a busca a partir do que foi digitado: procura no nome e também no
 * texto da carta. Quem escreve a sintaxe do Scryfall (t:, o:, c:...) tem a
 * busca usada como está.
 */
export function buildTextQuery(text) {
  const t = text.trim()
  if (!t) return ''
  if (/[:<>=!"()]/.test(t) || /\b(or|and)\b/i.test(t)) return t
  const words = t.split(/\s+/).filter(Boolean)
  const quote = (w) => (/^[\p{L}\p{N}_-]+$/u.test(w) ? w : `"${w.replaceAll('"', '')}"`)
  return `((${words.join(' ')}) or (${words.map((w) => `o:${quote(w)}`).join(' ')}))`
}

// ------------------------------------------------- filtros guardados (7 dias)

const CATALOG_MS = 7 * 24 * 60 * 60 * 1000

function storageGet(key) {
  try {
    return JSON.parse(localStorage.getItem(key))
  } catch {
    return null
  }
}

function storageSet(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Navegação privada ou armazenamento cheio: segue sem guardar.
  }
}

async function cachedList(key, path, pick = (data) => data.data || []) {
  const saved = storageGet(`scryfall_${key}`)
  if (saved && Date.now() - saved.at < CATALOG_MS) return saved.list
  try {
    const list = pick(await getJson(`${BASE}${path}`))
    storageSet(`scryfall_${key}`, { at: Date.now(), list })
    return list
  } catch {
    return saved?.list ?? null
  }
}

export const catalog = (name) => cachedList(`catalog_${name}`, `/catalog/${name}`)

export const sets = () =>
  cachedList('sets', '/sets', (data) => (data.data || []).map((s) => ({ code: s.code, name: s.name })))

// ------------------------------------------------------- buscas recentes

const RECENT_KEY = 'recent_card_searches'
const RECENT_MAX = 10

export function recentSearches() {
  return storageGet(RECENT_KEY) || []
}

export function addRecentSearch(text) {
  const t = text.trim()
  const list = recentSearches()
  if (!t) return list
  const next = [t, ...list.filter((s) => s.toLowerCase() !== t.toLowerCase())].slice(0, RECENT_MAX)
  storageSet(RECENT_KEY, next)
  return next
}

export function clearRecentSearches() {
  storageSet(RECENT_KEY, [])
  return []
}

// ---------------------------------------------------------------- imagens

const SIZED = /(cards\.scryfall\.io\/)(small|normal|large|png|border_crop|art_crop)(\/[^?]*?)\.(jpg|png)/

/**
 * Troca o tamanho de um endereço de imagem do Scryfall:
 * small (146×204), normal (488×680), large (672×936), png (745×1040).
 */
export function sized(url, size) {
  if (!url) return url
  return url.replace(SIZED, (_, host, _old, path) => `${host}${size}${path}.${size === 'png' ? 'png' : 'jpg'}`)
}

/** Imagem de uma carta da API (frente, nas cartas de duas faces). */
export function imageOf(card, size = 'normal') {
  const uris = card.image_uris || card.card_faces?.[0]?.image_uris
  return uris?.[size] || null
}

/** Verso da carta, quando ela tem dois lados com imagem. */
export function backImageOf(card, size = 'normal') {
  return card.image_uris ? null : card.card_faces?.[1]?.image_uris?.[size] || null
}

export const CARD_BACK = 'https://upload.wikimedia.org/wikipedia/en/a/aa/Magic_the_gathering-card_back.jpg'

// ------------------------------------------------------------ campos úteis

export const displayName = (c) => c.printed_name || c.name
export const typeLine = (c) => c.printed_type_line || c.type_line || c.card_faces?.map((f) => f.type_line).join(' // ') || ''
export const manaCost = (c) => c.mana_cost || c.card_faces?.map((f) => f.mana_cost).filter(Boolean).join(' // ') || ''

export function oracleText(c) {
  if (c.printed_text || c.oracle_text) return c.printed_text || c.oracle_text
  return (c.card_faces || []).map((f) => f.printed_text || f.oracle_text || '').filter(Boolean).join('\n\n//\n\n')
}

/** Arquivo do símbolo de mana: {2/W} -> 2W.svg */
export const symbolUrl = (symbol) => `https://svgs.scryfall.io/card-symbols/${symbol.replaceAll('/', '')}.svg`

export const RARITY_COLORS = {
  common: '#9e9e9e',
  uncommon: '#b0b0b0',
  rare: '#c1a058',
  mythic: '#d45e18',
  special: '#a855f7',
  bonus: '#a855f7',
}
