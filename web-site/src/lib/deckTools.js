// Ferramentas de deck (as mesmas do app, lib/data/services/deck_tools.dart):
// ler listas do Moxfield, Archidekt, MTG Arena e MTGO, buscar as cartas na
// Scryfall de 75 em 75, preço, legalidade por formato e a mão de teste.

import { getJson, postJson } from './scryfall'
import { scryfallIdOf, toDeckCard } from './deckCards'

const API = 'https://api.scryfall.com'
const SKIP = /^(sideboard|maybeboard|considering|maybe|tokens?|banco|reservas)\b/i
const COMMANDER = /^(commander|comandante)/i
// Cabeçalho: só a palavra, com a quantidade ou dois-pontos ("Creatures (30)", "Sideboard:").
const SECTION =
  /^(commander|comandante|deck|mainboard|main|companion|sideboard|maybeboard|considering|maybe|tokens?|banco|reservas|lands?|creatures?|spells?|artifacts?|enchantments?|instants?|sorcery|sorceries|planeswalkers?|terrenos?|criaturas?)\s*(\(\d+\))?\s*:?$/i
const LINE = /^(\d+)\s*[xX]?\s+(.+?)$/
const SET_NUMBER = /\s+\(([A-Za-z0-9]{2,6})\)(?:\s+([A-Za-z0-9\-★]+))?\s*$/

/** Lê a lista colada: [{ qty, name, set, number, commander }]. O banco e o "talvez" ficam de fora. */
export function parseDeckList(text) {
  const out = []
  let skipping = false
  let commander = false
  for (const raw of String(text).split(/\r?\n/)) {
    let line = raw.trim()
    if (!line) continue
    if (line.startsWith('//') || line.startsWith('#')) {
      const title = line.replace(/^(\/\/|#)+\s*/, '')
      skipping = SKIP.test(title)
      commander = COMMANDER.test(title)
      continue
    }
    if (/^SB:\s*/i.test(line)) continue // banco do MTGO
    if (SECTION.test(line)) {
      const title = line.replace(/[:(].*$/, '').trim()
      skipping = SKIP.test(title)
      commander = COMMANDER.test(title)
      continue
    }
    if (skipping) continue
    // Marcadores do Archidekt/Moxfield: [Ramp], ^Tag^, *F* (foil), *CMDR*.
    const isCommander = commander || line.includes('*CMDR*') || line.includes('[Commander')
    line = line
      .replace(/\[[^\]]*\]/g, '')
      .replace(/\^[^^]*\^/g, '')
      .replace(/\*[A-Za-z]+\*/g, '')
      .trim()
    let qty = 1
    let name = line
    const m = LINE.exec(line)
    if (m) {
      qty = Number(m[1])
      name = m[2]
    }
    let set = null
    let number = null
    const s = SET_NUMBER.exec(name)
    if (s) {
      set = s[1].toLowerCase()
      number = s[2] ?? null
      name = name.slice(0, s.index)
    }
    name = name.trim()
    if (!name || qty <= 0) continue
    out.push({ qty: Math.min(qty, 250), name, set, number, commander: isCommander })
  }
  return out
}

/** Busca as cartas da lista: { cards (uma por cópia, no formato dos decks), missing }. */
export async function fetchDeckList(lines) {
  const found = new Map()
  const missing = []
  for (let start = 0; start < lines.length; start += 75) {
    const chunk = lines.slice(start, start + 75)
    const ids = chunk.map((l) => (l.set && l.number ? { set: l.set, collector_number: l.number } : { name: l.name }))
    const data = await postJson(`${API}/cards/collection`, { identifiers: ids })
    const notFound = data.not_found || []
    const cards = data.data || []
    let k = 0
    for (let i = 0; i < chunk.length; i++) {
      const asked = ids[i]
      if (notFound.some((n) => n.name === asked.name && n.set === asked.set && n.collector_number === asked.collector_number)) {
        // Com edição errada, tenta só pelo nome; com nome errado, a Scryfall tenta adivinhar.
        try {
          found.set(start + i, await getJson(`${API}/cards/named?fuzzy=${encodeURIComponent(chunk[i].name)}`))
        } catch {
          missing.push(chunk[i].name)
        }
        continue
      }
      if (k < cards.length) found.set(start + i, cards[k++])
    }
  }
  const out = []
  lines.forEach((l, i) => {
    const c = found.get(i)
    if (!c) return
    const card = toDeckCard(c)
    for (let q = 0; q < l.qty; q++) out.push(card)
  })
  return { cards: out, missing }
}

/** As cartas do deck atualizadas na Scryfall (preço e legalidade de hoje), uma por cópia. */
export async function refreshDeck(cards) {
  const unique = new Map()
  for (const c of cards) {
    const id = scryfallIdOf(c)
    unique.set(id ?? `name:${c.name}`, id ? { id } : { name: c.name })
  }
  const keys = [...unique.keys()]
  const table = new Map()
  for (let start = 0; start < keys.length; start += 75) {
    const data = await postJson(`${API}/cards/collection`, { identifiers: keys.slice(start, start + 75).map((k) => unique.get(k)) })
    for (const card of data.data || []) {
      table.set(card.id, card)
      table.set(`name:${card.name}`, card)
      if (card.printed_name) table.set(`name:${card.printed_name}`, card)
    }
  }
  return cards.map((c) => table.get(scryfallIdOf(c) ?? '') || table.get(`name:${c.name}`) || c)
}

export const FORMATS = { commander: 'Commander', standard: 'Standard', pioneer: 'Pioneer', modern: 'Modern', legacy: 'Legacy', vintage: 'Vintage', pauper: 'Pauper' }

const anyNumber = (c) => {
  const type = c.type_line || ''
  return type.includes('Basic Land') || type.includes('Terreno Básico') || (c.oracle_text || '').includes('A deck can have any number of cards named')
}

/** Os problemas do deck num formato (vazio = legal). cards: atualizadas, uma por cópia. */
export function deckProblems(format, cards) {
  const out = []
  const counts = new Map()
  const byName = new Map()
  for (const c of cards) {
    counts.set(c.name, (counts.get(c.name) || 0) + 1)
    byName.set(c.name, c)
  }
  for (const [name, c] of byName) {
    const status = c.legalities?.[format]
    if (status === 'banned') out.push(`${name}: banida`)
    if (status === 'not_legal') out.push(`${name}: não é legal`)
    if (status === 'restricted' && counts.get(name) > 1) out.push(`${name}: restrita (só 1 cópia)`)
  }
  if (format === 'commander') {
    if (cards.length !== 100) out.unshift(`O deck tem ${cards.length} cartas (Commander pede 100, com o comandante).`)
    for (const [name, n] of counts) if (n > 1 && !anyNumber(byName.get(name))) out.push(`${name}: ${n} cópias (Commander é 1 de cada)`)
  } else {
    if (cards.length < 60) out.unshift(`O deck tem ${cards.length} cartas (o mínimo é 60).`)
    for (const [name, n] of counts) if (n > 4 && !anyNumber(byName.get(name))) out.push(`${name}: ${n} cópias (o máximo é 4)`)
  }
  return out
}

export const priceOf = (c) => Number.parseFloat(c.prices?.usd ?? c.prices?.usd_foil ?? c.usdPrice) || 0

/** Quanto vale 1 dólar em reais hoje (null se não deu para saber). */
export async function dollarInReais() {
  try {
    const r = await fetch('https://economia.awesomeapi.com.br/json/last/USD-BRL')
    const data = await r.json()
    return Number.parseFloat(data.USDBRL?.bid) || null
  } catch {
    return null
  }
}

/** Embaralha (Fisher-Yates). */
export function shuffled(list, random = Math.random) {
  const out = [...list]
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1))
    ;[out[i], out[j]] = [out[j], out[i]]
  }
  return out
}
