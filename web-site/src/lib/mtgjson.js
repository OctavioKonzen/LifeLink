// Decks oficiais do MTGJSON, como na tela "Comunidade" do app
// (community_decks_screen.dart).

const BASE = 'https://mtgjson.com/api/v5'
const decks = new Map()

async function get(url) {
  let response
  try {
    response = await fetch(url)
  } catch {
    throw new Error('Não foi possível falar com o MTGJSON. Verifique sua internet e tente de novo.')
  }
  if (!response.ok) throw new Error(`O MTGJSON respondeu com erro ${response.status}. Tente mais tarde.`)
  return response.json()
}

/** 0 = Commander, 1 = Challenger, 2 = Avatar / Outros; null = fica de fora. */
export function deckCategory(deck) {
  const type = (deck.type || '').toLowerCase()
  const name = (deck.name || '').toLowerCase()
  if (['avatar', 'aang', 'zuko'].some((w) => name.includes(w)) || type.includes('secret lair')) return 2
  if (type.includes('commander')) return 0
  if (type.includes('challenger')) return 1
  if (type.includes('starter') || type.includes('planeswalker')) return 2
  return null
}

export async function deckList() {
  const data = await get(`${BASE}/DeckList.json`)
  const lists = [[], [], []]
  for (const deck of data.data || []) {
    const category = deckCategory(deck)
    if (category != null) lists[category].push(deck)
  }
  for (const list of lists) list.sort((a, b) => (b.releaseDate || '').localeCompare(a.releaseDate || ''))
  return lists
}

export function deck(fileName) {
  if (!decks.has(fileName)) {
    const promise = get(`${BASE}/decks/${encodeURIComponent(fileName)}.json`).then((d) => d.data)
    promise.catch(() => decks.delete(fileName))
    decks.set(fileName, promise)
  }
  return decks.get(fileName)
}

export const imageFor = (scryfallId, size = 'normal') =>
  scryfallId ? `https://cards.scryfall.io/${size}/front/${scryfallId[0]}/${scryfallId[1]}/${scryfallId}.jpg` : null

/** Todas as cartas do deck (principal, reserva, comandante...), uma por cópia agrupada. */
export function deckCards(data) {
  const cards = []
  for (const [board, value] of Object.entries(data || {})) {
    if (!Array.isArray(value)) continue
    for (const item of value) {
      if (item && typeof item === 'object' && item.name) {
        cards.push({
          board,
          name: item.name,
          count: Number(item.count) || 1,
          scryfallId: item.identifiers?.scryfallId,
          item,
        })
      }
    }
  }
  return cards
}

/** Até 3 cartas para a capa: comandantes primeiro, depois o deck principal. */
export function coverIds(data) {
  const ids = []
  for (const item of [...(data?.commander || []), ...(data?.mainBoard || [])]) {
    const id = item.identifiers?.scryfallId
    if (id && !ids.includes(id)) ids.push(id)
    if (ids.length === 3) break
  }
  return ids
}
