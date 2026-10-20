// Cartas dentro dos decks, no mesmo formato que o app grava
// (card_search_screen.dart e community_deck_detail_screen.dart).

import { displayName, imageOf, manaCost, oracleText, typeLine } from './scryfall'

/** Carta da API do Scryfall → carta de deck. */
export function toDeckCard(c) {
  return {
    id: c.id,
    name: displayName(c),
    imageUrl: imageOf(c, 'normal'),
    rarity: c.rarity,
    color_identity: (c.color_identity || []).join('') || 'C',
    mana_cost: manaCost(c),
    type_line: typeLine(c),
    oracle_text: oracleText(c),
    oracle_id: c.oracle_id ?? null,
    setName: c.set_name,
    cmc: c.cmc ?? 0,
    power: c.power ?? c.card_faces?.[0]?.power ?? null,
    toughness: c.toughness ?? c.card_faces?.[0]?.toughness ?? null,
    collectorNumber: c.collector_number,
    usdPrice: c.prices?.usd ?? '0.00',
  }
}

/** Carta de um deck oficial (MTGJSON) → carta de deck. */
export function fromMtgjson(item, imageUrl) {
  return {
    id: item.identifiers?.scryfallId ?? null,
    name: item.name || 'Carta Desconhecida',
    imageUrl,
    type_line: item.type || '',
    oracle_text: item.text || '',
    rarity: item.rarity || 'common',
    mana_cost: item.manaCost || '',
    cmc: item.manaValue ?? 0,
    power: item.power ?? null,
    toughness: item.toughness ?? null,
    color_identity: (item.colorIdentity || []).join(''),
    setName: item.setCode || '',
    collectorNumber: item.number || '',
    oracle_id: item.identifiers?.oracleId ?? null,
    usdPrice: '0.00',
  }
}

/** Id do Scryfall de uma carta de deck (decks antigos só têm a imagem). */
export function scryfallIdOf(card) {
  if (card.id && /^[0-9a-f-]{36}$/.test(card.id)) return card.id
  const m = /\/([0-9a-f-]{36})\.(?:jpg|png)/.exec(card.imageUrl || '')
  return m ? m[1] : null
}
