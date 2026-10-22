// As cartas do próprio LifeLink, na Cloudflare (o mesmo do app,
// lib/data/services/lifelink_cards.dart): arquivos no R2 (a carta pelo código,
// preços, imagens) e a busca no Worker. Assim o site não depende da API da
// Scryfall para mostrar as cartas; quem usa estas funções volta para a
// Scryfall quando o banco não responde (erro, 404 ou nada encontrado).
//
// No R2:
//   c/{oracle}.json   a carta com todas as variações (inglês e português)
//   pr/{xx}.json      os preços do dia (xx = começo do oracle_id)
//   id/{xxx}.json     código da variação → oracle_id
//   set/{código}.json "número|idioma" → código da variação
//   sets.json         código da coleção → nome
//   data/top.json     as variações mais caras; data/config.json: o endereço da busca
//   img/{id}.jpg      imagens (e img/{id}-b.jpg, o verso)

export const R2 = 'https://pub-3077717c9bb54c58a316369e197147fa.r2.dev'
const TIMEOUT_MS = 20000

const files = new Map()
let searchUrl = null
let pricesDay = new Date().toDateString()

/** Para os testes: esquece tudo o que foi guardado. */
export function resetCache() {
  files.clear()
  pools.clear()
  searchUrl = null
  pricesDay = new Date().toDateString()
}

async function getJson(url) {
  const signal = typeof AbortSignal !== 'undefined' && AbortSignal.timeout ? AbortSignal.timeout(TIMEOUT_MS) : undefined
  const r = await fetch(url, { signal })
  if (r.status === 404) return null
  if (!r.ok) throw new Error(`LifeLink ${r.status}`)
  return r.json()
}

/** Um arquivo do R2 (guardado enquanto o site está aberto); null = não existe. */
function file(path) {
  // Os preços mudam todo dia: esquece os de ontem.
  const today = new Date().toDateString()
  if (today !== pricesDay) {
    for (const k of files.keys()) if (k.startsWith('pr/')) files.delete(k)
    pricesDay = today
  }
  if (!files.has(path)) {
    const p = getJson(`${R2}/${path}`).catch((e) => {
      files.delete(path) // sem internet: tenta de novo na próxima vez
      throw e
    })
    files.set(path, p)
  }
  return files.get(path)
}

// ------------------------------------------------------------- imagens

/**
 * A imagem da variação: do R2 quando já foi copiada, senão do servidor de
 * imagens da Scryfall (não é a API).
 */
export function imageUrl(id, { inR2 = true, back = false } = {}) {
  if (inR2) return `${R2}/img/${id}${back ? '-b' : ''}.jpg`
  return `https://cards.scryfall.io/normal/${back ? 'back' : 'front'}/${id[0]}/${id[1]}/${id}.jpg`
}

const uris = (url) => ({ small: url, normal: url, large: url, png: url })
const letters = (s) => String(s ?? '').split('').filter(Boolean)

// --------------------------------------------------------------- cartas

/** A carta inteira (todas as variações, com os preços de hoje em `$`). */
export async function card(oracle) {
  if (!oracle || oracle.length < 2) return null
  const [c, prices] = await Promise.all([file(`c/${oracle}.json`), file(`pr/${oracle.slice(0, 2)}.json`).catch(() => null)])
  if (!c) return null
  const mine = prices?.[oracle] || {}
  return { ...c, v: (c.v || []).map((v) => (mine[v.id] ? { ...v, $: mine[v.id] } : { ...v })) }
}

/** A carta e a variação de um código (o que fica salvo nos decks): { card, variation } ou null. */
export async function byPrint(id) {
  if (!id || id.length < 3) return null
  const map = await file(`id/${id.slice(0, 3)}.json`)
  const oracle = map?.[id]
  if (!oracle) return null
  const c = await card(oracle)
  if (!c || !c.v.length) return null
  return { card: c, variation: c.v.find((v) => v.id === id) || c.v[0] }
}

/** O código da variação pela coleção e número. */
export async function printBySetNumber(set, number, lang = 'en') {
  const map = await file(`set/${String(set).toLowerCase()}.json`)
  return map?.[`${number}|${lang}`] ?? map?.[`${number}|en`] ?? map?.[`${number}|pt`] ?? null
}

/** Código da coleção → nome ({} se não deu). */
export async function sets() {
  try {
    return (await file('sets.json')) || {}
  } catch {
    return {}
  }
}

/** A variação principal no idioma pedido (português ou inglês). */
export function variationFor(c, lang = 'pt') {
  const vs = c.v || []
  if (lang === 'pt') {
    const pt = vs.find((v) => v.l === 'pt')
    if (pt) return pt
  }
  return vs.find((v) => v.id === c.id) || vs[0] || { id: c.id }
}

// Todos os formatos da Scryfall: o que não está na carta é "not_legal".
const FORMATS = [
  'standard', 'future', 'historic', 'timeless', 'gladiator', 'pioneer', 'explorer', 'modern', 'legacy', 'pauper', 'vintage',
  'penny', 'commander', 'oathbreaker', 'standardbrawl', 'brawl', 'alchemy', 'paupercommander', 'duel', 'oldschool', 'premodern', 'predh',
]
const LEGAL = { l: 'legal', b: 'banned', r: 'restricted' }

const PRICE_KEYS = ['usd', 'usd_foil', 'usd_etched', 'eur', 'eur_foil', 'tix']

function pricesOf(raw) {
  const out = {}
  for (const k of PRICE_KEYS) out[k] = raw?.[k] != null ? String(raw[k]) : null
  return out
}

/**
 * A carta no formato da API da Scryfall, para os componentes do site
 * funcionarem sem mudar. lang 'pt' traz também o nome, tipo e texto em
 * português (printed_*), como as cartas em português da Scryfall.
 */
export function toScryfall(c, v, setNames = {}, lang = v.l) {
  const pt = lang === 'pt'
  const faces = c.f || []
  const inR2 = v.i === 1
  const front = imageUrl(v.id, { inR2 })
  const back = v.b === 1 ? imageUrl(v.id, { inR2, back: true }) : null
  const pn = pt ? v.pn ?? c.pn : null
  const ptType = pt ? v.pt ?? c.pt : null
  const px = pt ? v.px ?? c.px : null
  // Nas cartas de duas faces, o português vem junto (" // "): separa por face.
  const split = (s, sep) => (s ? s.split(sep) : [])
  const [pns, pts, pxs] = [split(pn, ' // '), split(ptType, ' // '), split(px, '\n//\n')]
  const legalities = {}
  for (const f of new Set([...FORMATS, ...Object.keys(c.lg || {})])) legalities[f] = LEGAL[c.lg?.[f]] || 'not_legal'
  const out = {
    object: 'card',
    id: v.id,
    oracle_id: c.o,
    name: c.n,
    lang: v.l || 'en',
    layout: c.lay,
    mana_cost: c.m || '',
    cmc: c.cmc ?? 0,
    type_line: c.t || faces.map((f) => f.t || '').join(' // '),
    power: c.pw ?? faces[0]?.pw,
    toughness: c.tg ?? faces[0]?.tg,
    loyalty: c.ly,
    defense: c.df,
    colors: letters(c.c),
    color_identity: letters(c.ci),
    keywords: c.kw || [],
    produced_mana: c.pmn,
    legalities,
    game_changer: c.gc === 1,
    reserved: c.rs === 1,
    edhrec_rank: c.er,
    rarity: v.r ?? c.r,
    set: v.s,
    set_name: setNames[v.s] || String(v.s ?? '').toUpperCase(),
    collector_number: v.cn,
    released_at: v.d,
    artist: v.a,
    flavor_text: v.ft,
    frame: v.fr,
    finishes: v.fn || [],
    full_art: v.fa === 1,
    promo: v.pm === 1,
    prices: pricesOf(v.$),
    rulings_uri: `https://api.scryfall.com/cards/${v.id}/rulings`,
    scryfall_uri: `https://scryfall.com/card/${v.s}/${v.cn}`,
  }
  if (!faces.length) out.oracle_text = c.x || ''
  if (pn) out.printed_name = pn
  if (ptType) out.printed_type_line = ptType
  if (px) out.printed_text = px
  if (faces.length) {
    out.card_faces = faces.map((f, k) => ({
      object: 'card_face',
      name: f.n,
      mana_cost: f.m || '',
      type_line: f.t || '',
      oracle_text: f.x || '',
      power: f.pw,
      toughness: f.tg,
      loyalty: f.ly,
      defense: f.df,
      colors: letters(f.c),
      ...(pns.length === faces.length ? { printed_name: pns[k] } : {}),
      ...(pts.length === faces.length ? { printed_type_line: pts[k] } : {}),
      ...(pxs.length === faces.length ? { printed_text: pxs[k] } : {}),
      ...(back ? { image_uris: uris(k === 0 ? front : back) } : {}),
    }))
  }
  // Com verso, a imagem fica em cada face (como na Scryfall).
  if (!back) out.image_uris = uris(front)
  return out
}

/** A carta pelo código, já no formato da Scryfall (ou null). */
export async function scryfallCard(id, lang) {
  const found = await byPrint(id)
  if (!found) return null
  return toScryfall(found.card, found.variation, await sets(), lang ?? found.variation.l)
}

/** Várias cartas pelo código: Map id → carta da Scryfall (as que não estão no banco ficam de fora). */
export async function many(ids, lang = 'pt') {
  const out = new Map()
  const list = [...new Set(ids)].filter(Boolean)
  const names = await sets()
  for (let start = 0; start < list.length; start += 20) {
    const found = await Promise.all(list.slice(start, start + 20).map((id) => byPrint(id).catch(() => null)))
    for (const f of found) if (f) out.set(f.variation.id, toScryfall(f.card, f.variation, names, lang))
  }
  return out
}

/** As outras versões da carta num idioma (inglês ou português), mais novas primeiro. */
export async function versions(oracle, lang = 'pt') {
  const c = await card(oracle)
  if (!c) return []
  const names = await sets()
  return c.v
    .filter((v) => v.l === lang)
    .sort((a, b) => String(b.d ?? '').localeCompare(String(a.d ?? '')))
    .map((v) => toScryfall(c, v, names, lang))
}

/** As variações mais caras (inglês e português), no formato da Scryfall. */
export async function topPrices() {
  // Sem guardar: muda todo dia.
  const rows = await getJson(`${R2}/data/top.json`)
  if (!Array.isArray(rows)) throw new Error('LifeLink: sem a lista de preços')
  return rows.map((t) => ({
    id: t.id,
    oracle_id: t.o,
    name: t.n,
    ...(t.pn ? { printed_name: t.pn } : {}),
    lang: t.l || 'en',
    set: t.s,
    set_name: t.sn || String(t.s ?? '').toUpperCase(),
    collector_number: t.cn,
    rarity: t.r,
    mana_cost: t.m || '',
    type_line: t.t || '',
    color_identity: letters(t.ci),
    prices: pricesOf(t.$),
    image_uris: uris(imageUrl(t.id, { inR2: t.i === 1 })),
    _lifelink: 'summary',
  }))
}

// ---------------------------------------------------------------- busca

async function searchBase() {
  if (searchUrl) return searchUrl
  const config = await file('data/config.json')
  if (!config?.search) throw new Error('A busca ainda não está no ar')
  searchUrl = String(config.search).replace(/\/+$/, '')
  return searchUrl
}

async function ask(path, params) {
  const base = await searchBase()
  const query = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') query.set(k, String(v))
  const signal = typeof AbortSignal !== 'undefined' && AbortSignal.timeout ? AbortSignal.timeout(TIMEOUT_MS) : undefined
  const r = await fetch(`${base}/${path}?${query}`, { signal })
  const body = await r.json()
  if (!r.ok) throw new Error(body?.error || `Busca ${r.status}`)
  return body
}

/** Uma linha da busca do Worker → resumo no formato da Scryfall (a ficha completa vem do R2). */
export function fromSearchRow(r, lang = 'pt') {
  const pt = lang === 'pt'
  return {
    id: r.id,
    oracle_id: r.o,
    name: r.n,
    ...(pt && r.pn ? { printed_name: r.pn } : {}),
    lang: 'en',
    type_line: r.t || '',
    ...(pt && r.pt ? { printed_type_line: r.pt } : {}),
    mana_cost: r.m || '',
    cmc: r.cmc ?? 0,
    color_identity: letters(r.ci),
    rarity: r.r,
    prices: { ...pricesOf(null), usd: r.usd == null ? null : Number(r.usd).toFixed(2) },
    image_uris: uris(imageUrl(r.id, { inR2: r.img === 1 })),
    _lifelink: 'summary',
  }
}

/**
 * As cartas de uma coleção na ordem dos números (1, 2, 3...), uma por número,
 * em português quando existe (resumos no formato da Scryfall).
 */
export async function setCards(set, lang = 'pt') {
  const r = await fetch(`${R2}/s/${String(set).toLowerCase()}.json`)
  if (r.status === 404) return []
  if (!r.ok) throw new Error(`R2 ${r.status}`)
  const rows = await r.json()
  const pick = new Map()
  for (const row of rows) {
    const old = pick.get(row[1])
    if (!old || (row[2] === lang && old[2] !== lang)) pick.set(row[1], row)
  }
  const seen = new Set()
  const out = []
  for (const row of rows) {
    if (seen.has(row[1])) continue
    seen.add(row[1])
    const [id, cn, l, rarity, inR2, oracle, name, pn] = pick.get(row[1])
    out.push({
      id,
      oracle_id: oracle,
      name,
      ...(pn ? { printed_name: pn } : {}),
      lang: l,
      set: String(set).toLowerCase(),
      collector_number: cn,
      rarity,
      image_uris: uris(imageUrl(id, { inR2: inR2 === 1 })),
      prices: pricesOf(null),
      _lifelink: 'summary',
    })
  }
  return out
}

/**
 * Busca (nome, tipo ou texto, em português ou inglês), com filtros.
 * order: relevance (padrão com texto), name, cmc, usd, released, popular.
 * Volta { cards (resumos no formato da Scryfall), hasMore }.
 */
export async function search({ text = '', nameOnly = false, types = [], set = '', colors, order, desc = false, page = 0, lang = 'pt' } = {}) {
  const body = await ask('search', {
    q: text,
    name: nameOnly ? '1' : '',
    type: types.join(','),
    set: set || '',
    colors,
    order: order || '',
    dir: desc ? 'desc' : '',
    page,
    lang,
  })
  return { cards: (body.cards || []).map((r) => fromSearchRow(r, lang)), hasMore: body.hasMore === true }
}

/** Sugestões de nome enquanto digita. */
export async function names(text, lang = 'pt') {
  const body = await ask('names', { q: text })
  return (body.names || []).map((r) => (lang === 'pt' && r.pn) || r.n).filter(Boolean)
}

const pools = new Map()

/**
 * Todas as cartas de um tipo (planos, fenômenos, esquemas), em resumos,
 * guardadas enquanto o site está aberto.
 */
export async function typePool(types) {
  const key = types.join(',')
  if (pools.has(key)) return pools.get(key)
  const out = []
  for (const type of types) {
    // "plane" também acha "planeswalker": fica só o tipo certo (antes do "—").
    const exact = new RegExp(`(^|\\s)${type}(\\s|$)`)
    for (let page = 0; page < 12; page++) {
      const r = await search({ types: [type], order: 'name', page, lang: 'en' })
      out.push(...r.cards.filter((c) => exact.test(c.type_line.split('—')[0].trim())))
      if (!r.hasMore) break
    }
  }
  if (out.length) pools.set(key, out)
  return out
}

/** Uma busca sem a sintaxe da Scryfall (t:, o:, usd>...) pode ir para o banco do LifeLink. */
export const plainText = (text) => !/[:<>=]/.test(String(text ?? ''))
