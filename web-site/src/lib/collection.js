// Minha coleção e lista de desejos, no mesmo formato do app
// (collection_provider.dart): { list: [{ id, name, oracle_id, set, num, img,
// usd, qty }] } e, nos desejos, { added (preço quando entrou), at }.

import { updateSection } from './userData'
import { postJson } from './scryfall'
import { scryfallIdOf } from './deckCards'

export const MAX_CARDS = 2000

/** Carta no formato do deck (toDeckCard) → carta guardada. */
export function savedOf(card) {
  const usd = Number.parseFloat(card.usdPrice ?? card.usdFoil) || 0
  return {
    id: scryfallIdOf(card) ?? String(card.id ?? card.name),
    name: card.name ?? '',
    oracle_id: card.oracle_id ?? null,
    set: card.setName ?? '',
    num: card.collectorNumber ?? '',
    img: card.imageUrl ?? '',
    usd,
  }
}

const list = (section) => section?.list || []
export const qtyOf = (collection, id) => list(collection).filter((c) => c.id === id).reduce((a, c) => a + (c.qty || 1), 0)
export const totalCards = (collection) => list(collection).reduce((a, c) => a + (c.qty || 1), 0)
export const totalUsd = (collection) => list(collection).reduce((a, c) => a + (c.usd || 0) * (c.qty || 1), 0)

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

/** Preços de hoje na Scryfall; volta os desejos que ficaram 5% (ou mais) mais baratos. */
export async function refreshPrices(collection, wishlist) {
  const ids = [...new Set([...list(collection), ...list(wishlist)].map((c) => c.id))].filter((id) => /^[0-9a-f-]{36}$/.test(id))
  const prices = new Map()
  for (let start = 0; start < ids.length; start += 75) {
    const data = await postJson('https://api.scryfall.com/cards/collection', { identifiers: ids.slice(start, start + 75).map((id) => ({ id })) })
    for (const c of data.data || []) {
      const p = Number.parseFloat(c.prices?.usd ?? c.prices?.usd_foil)
      if (!Number.isNaN(p)) prices.set(c.id, p)
    }
  }
  const drops = list(wishlist).filter((c) => prices.has(c.id) && c.usd > 0 && prices.get(c.id) <= c.usd * 0.95).map((c) => ({ ...c, before: c.usd, usd: prices.get(c.id) }))
  if (prices.size) {
    const update = (s) => ({ list: list(s).map((c) => (prices.has(c.id) ? { ...c, usd: prices.get(c.id) } : c)) })
    updateSection('collection', update)
    updateSection('wishlist', update)
  }
  return drops
}
