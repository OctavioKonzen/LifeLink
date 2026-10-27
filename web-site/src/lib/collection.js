// Minha coleção e lista de desejos, no mesmo formato do app
// (collection_provider.dart): { list: [{ id, name, oracle_id, set, num, img,
// usd, eur, qty, folder, trade }] } e, nos desejos, { added (preço quando
// entrou), at }. eur (Cardmarket), folder (a pasta) e trade (para troca) só
// vão quando têm valor, como no app.

import { updateSection } from './userData'
import { postJson } from './scryfall'
import { scryfallIdOf } from './deckCards'
import { many } from './lifelinkCards'

export const MAX_CARDS = 2000

/** Carta no formato do deck (toDeckCard) → carta guardada. */
export function savedOf(card) {
  const usd = Number.parseFloat(card.usdPrice ?? card.usdFoil) || 0
  const eur = Number.parseFloat(card.eurPrice) || 0
  return {
    id: scryfallIdOf(card) ?? String(card.id ?? card.name),
    name: card.name ?? '',
    oracle_id: card.oracle_id ?? null,
    set: card.setName ?? '',
    num: card.collectorNumber ?? '',
    img: card.imageUrl ?? '',
    usd,
    ...(eur > 0 ? { eur } : {}),
  }
}

const list = (section) => section?.list || []
export const qtyOf = (collection, id) => list(collection).filter((c) => c.id === id).reduce((a, c) => a + (c.qty || 1), 0)
export const totalCards = (collection) => list(collection).reduce((a, c) => a + (c.qty || 1), 0)
export const totalUsd = (collection) => list(collection).reduce((a, c) => a + (c.usd || 0) * (c.qty || 1), 0)
export const totalEur = (collection) => list(collection).reduce((a, c) => a + (c.eur || 0) * (c.qty || 1), 0)

/** As pastas da coleção, em ordem. */
export const foldersOf = (collection) => [...new Set(list(collection).map((c) => c.folder).filter(Boolean))].sort((a, b) => a.localeCompare(b))

// Sem pasta e "não é para troca": o campo nem vai (como no app).
const withField = (c, key, value) => {
  const out = { ...c }
  if (value) out[key] = value
  else delete out[key]
  return out
}

/** Põe a carta numa pasta ('' = sem pasta). */
export function setFolder(id, folder) {
  const name = String(folder).trim()
  updateSection('collection', (s) => ({ list: list(s).map((c) => (c.id === id ? withField(c, 'folder', name) : c)) }))
}

/** Marca (ou não) a carta para troca: os amigos veem. */
export function setTrade(id, trade) {
  updateSection('collection', (s) => ({ list: list(s).map((c) => (c.id === id ? withField(c, 'trade', trade ? true : null) : c)) }))
}

/** O resumo que os amigos veem (troca e desejos), como SavedCard.toPublic no app. */
export const toPublic = (c) => ({ id: c.id ?? '', name: c.name ?? '', set: c.set ?? '', img: c.img ?? '', usd: c.usd || 0 })

/** O que vai para users/{uid}/public/trade: as cartas para troca e os desejos (até 500 de cada). */
export const publicTrade = (collection, wishlist) => ({
  trade: list(collection).filter((c) => c.trade).map(toPublic).slice(0, 500),
  wish: list(wishlist).map(toPublic).slice(0, 500),
})

/**
 * As trocas possíveis com um amigo (pelo nome da carta): o que ele tem para
 * troca e está nos meus desejos (theyHave), e o que eu tenho para troca e ele
 * quer (iHave).
 */
export function tradeMatches(collection, wishlist, theirTrade = [], theirWish = []) {
  const key = (n) => String(n ?? '').toLowerCase()
  const myWish = new Set(list(wishlist).map((c) => key(c.name)))
  const theirWishes = new Set(theirWish.map((c) => key(c.name)))
  return {
    theyHave: theirTrade.filter((c) => myWish.has(key(c.name))),
    iHave: list(collection).filter((c) => c.trade && theirWishes.has(key(c.name))).map(toPublic),
  }
}

/** Mais uma cópia (n) na coleção. */
export function addToCollection(card, n = 1) {
  const saved = savedOf(card)
  updateSection('collection', (s) => {
    const cards = list(s)
    if (cards.some((c) => c.id === saved.id)) return { list: cards.map((c) => (c.id === saved.id ? { ...c, qty: (c.qty || 1) + n } : c)) }
    if (cards.length >= MAX_CARDS) return s
    return { list: [{ ...saved, qty: n }, ...cards] }
  })
}

/** Várias cartas de uma vez (importar): [{ card, n }]. */
export function addManyToCollection(entries) {
  updateSection('collection', (s) => {
    const cards = [...list(s)]
    for (const { card, n } of entries) {
      const saved = savedOf(card)
      const i = cards.findIndex((c) => c.id === saved.id)
      if (i >= 0) cards[i] = { ...cards[i], qty: (cards[i].qty || 1) + n }
      else if (cards.length < MAX_CARDS) cards.unshift({ ...saved, qty: n })
    }
    return { list: cards }
  })
}

export function setQty(id, qty) {
  updateSection('collection', (s) => ({
    list: qty <= 0 ? list(s).filter((c) => c.id !== id) : list(s).map((c) => (c.id === id ? { ...c, qty } : c)),
  }))
}

export const wished = (wishlist, id) => list(wishlist).some((c) => c.id === id)

export function toggleWish(card) {
  const saved = savedOf(card)
  updateSection('wishlist', (s) =>
    wished(s, saved.id) ? { list: list(s).filter((c) => c.id !== saved.id) } : { list: [{ ...saved, added: saved.usd, at: Date.now() }, ...list(s)] },
  )
}

export const removeWish = (id) => updateSection('wishlist', (s) => ({ list: list(s).filter((c) => c.id !== id) }))

/**
 * O que falta na coleção para montar o deck (qualquer versão da carta serve;
 * terrenos básicos não contam): [{ name, need, have, usd, card }].
 */
export function missingFor(deckCards, collection) {
  const key = (oracle, name) => oracle ?? String(name).toLowerCase()
  const have = new Map()
  const bump = (k, n) => have.set(k, (have.get(k) || 0) + n)
  for (const c of list(collection)) {
    bump(key(c.oracle_id, c.name), c.qty || 1)
    if (c.oracle_id) bump(String(c.name).toLowerCase(), c.qty || 1)
  }
  const need = new Map()
  for (const c of deckCards) {
    if (/Basic|Básic/.test(c.type_line || '')) continue
    const k = key(c.oracle_id, c.name)
    need.set(k, { n: (need.get(k)?.n || 0) + 1, card: c })
  }
  const out = []
  for (const [k, { n, card }] of need) {
    const got = have.get(k) ?? have.get(String(card.name).toLowerCase()) ?? 0
    if (got < n) out.push({ name: card.name, need: n, have: got, usd: Number.parseFloat(card.usdPrice) || 0, card })
  }
  return out.sort((a, b) => a.name.localeCompare(b.name))
}

/**
 * Preços de hoje (do banco do LifeLink no R2; o que faltar, da Scryfall);
 * volta os desejos que ficaram 5% (ou mais) mais baratos.
 */
export async function refreshPrices(collection, wishlist) {
  const ids = [...new Set([...list(collection), ...list(wishlist)].map((c) => c.id))].filter((id) => /^[0-9a-f-]{36}$/.test(id))
  const prices = new Map()
  const euros = new Map()
  const read = (c) => {
    const p = Number.parseFloat(c.prices?.usd ?? c.prices?.usd_foil)
    if (!Number.isNaN(p)) prices.set(c.id, p)
    const e = Number.parseFloat(c.prices?.eur ?? c.prices?.eur_foil)
    if (!Number.isNaN(e)) euros.set(c.id, e)
  }
  let missing = ids
  try {
    const own = await many(ids)
    for (const c of own.values()) read(c)
    missing = ids.filter((id) => !own.has(id))
  } catch {
    // O R2 não respondeu: tudo pela Scryfall.
  }
  for (let start = 0; start < missing.length; start += 75) {
    const data = await postJson('https://api.scryfall.com/cards/collection', { identifiers: missing.slice(start, start + 75).map((id) => ({ id })) })
    for (const c of data.data || []) read(c)
  }
  const drops = list(wishlist).filter((c) => prices.has(c.id) && c.usd > 0 && prices.get(c.id) <= c.usd * 0.95).map((c) => ({ ...c, before: c.usd, usd: prices.get(c.id) }))
  if (prices.size) {
    // O euro (Cardmarket) também, nas duas listas.
    const withEur = (c) => (euros.has(c.id) ? withField(c, 'eur', euros.get(c.id)) : c)
    const update = (s) => ({ list: list(s).map((c) => withEur(prices.has(c.id) ? { ...c, usd: prices.get(c.id) } : c)) })
    updateSection('collection', update)
    updateSection('wishlist', update)
  }
  return drops
}
