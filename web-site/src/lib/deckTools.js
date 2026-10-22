// Ferramentas de deck (as mesmas do app, lib/data/services/deck_tools.dart):
// ler listas do Moxfield, Archidekt, MTG Arena e MTGO, buscar as cartas na
// Scryfall de 75 em 75, preço, legalidade por formato, nível (bracket),
// sugestões para o comandante e a mão de teste.

import { getJson, postJson, search } from './scryfall'
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
    const card = l.commander ? { ...toDeckCard(c), commander: true } : toDeckCard(c)
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

// ------------------------------------------------------- nível (bracket)

const EXTRA_TURN = /takes? an extra turn/i
const LAND_DESTRUCTION = /destroy all (nonbasic )?lands|exile all lands|sacrifices? all lands|each player sacrifices (two|three|four|five|six|seven) lands|lands don't untap|lands do not untap/i

const textOf = (c) => [c.oracle_text || '', ...(c.card_faces || []).map((f) => f?.oracle_text || '')].join('\n')

/**
 * O nível do deck no Commander (Brackets da Wizards), pelo que dá para ver
 * nas cartas da Scryfall (refreshDeck): as Game Changers, turnos extras e
 * destruição de terrenos em massa. Combos de duas cartas e a intenção do deck
 * (nível 1 e 5) ficam para a mesa conversar. O mesmo do app (DeckTools.bracket).
 */
export function bracket(cards) {
  const gc = new Set()
  const turns = new Set()
  const mld = new Set()
  for (const c of cards) {
    const name = c.printed_name || c.name
    if (c.game_changer === true) gc.add(name)
    const text = textOf(c)
    if (EXTRA_TURN.test(text)) turns.add(name)
    if (LAND_DESTRUCTION.test(text)) mld.add(name)
  }
  const level = gc.size > 3 || mld.size > 0 || turns.size > 1 ? 4 : gc.size > 0 || turns.size > 0 ? 3 : 2
  const sorted = (set) => [...set].sort()
  return { bracket: level, gameChangers: sorted(gc), extraTurns: sorted(turns), landDestruction: sorted(mld) }
}

export const BRACKET_NAMES = { 1: 'Exibição', 2: 'Básico', 3: 'Melhorado', 4: 'Otimizado', 5: 'cEDH' }

// ------------------------------------------------------------ sugestões

/**
 * O nome da página do comandante no EDHREC ("Atraxa, Praetors' Voice" →
 * "atraxa-praetors-voice"; carta de duas faces: só a da frente).
 */
export const edhrecSlug = (name) =>
  String(name)
    .split(' // ')[0]
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/[\s-]+/g, '-')

/**
 * Os nomes das cartas que o EDHREC mais recomenda para o comandante, das mais
 * usadas para as menos (sem as de skip: nomes em minúsculas já no deck).
 */
export function edhrecNames(page, skip = new Set()) {
  const lists = page?.container?.json_dict?.cardlists || []
  const score = new Map()
  for (const l of lists) {
    for (const c of l?.cardviews || []) {
      const name = String(c?.name ?? '')
      if (!name || skip.has(name.toLowerCase())) continue
      const potential = Number(c.potential_decks) || 0
      const used = Number(c.inclusion ?? c.num_decks) || 0
      const s = (potential > 0 ? used / potential : 0) + (Number(c.synergy) || 0) * 0.3
      score.set(name, Math.max(score.get(name) ?? -1, s))
    }
  }
  return [...score.keys()].sort((a, b) => score.get(b) - score.get(a))
}

/**
 * Sugestões de cartas para o comandante do deck (cartas da Scryfall, em
 * inglês): do EDHREC e, se não der (o navegador pode bloquear), as mais
 * populares nas cores dele (ordem do EDHREC na Scryfall). Volta { cards, source }.
 */
export async function suggestions(commander, deck, count = 40) {
  const skip = new Set(deck.map((c) => String(c.name).toLowerCase()))
  let names = []
  try {
    const r = await fetch(`https://json.edhrec.com/pages/commanders/${edhrecSlug(commander.name)}.json`, { signal: AbortSignal.timeout?.(15000) })
    if (r.ok) names = edhrecNames(await r.json(), skip).slice(0, count)
  } catch {
    // Sem EDHREC: vai pela Scryfall.
  }
  if (names.length) {
    const data = await postJson(`${API}/cards/collection`, { identifiers: names.slice(0, 75).map((name) => ({ name })) })
    const byName = new Map((data.data || []).map((c) => [c.name, c]))
    const cards = names.map((n) => byName.get(n)).filter(Boolean)
    if (cards.length) return { cards, source: 'EDHREC' }
  }
  const ci = commander.color_identity
  const colors = (Array.isArray(ci) ? ci.join('') : String(ci ?? '')).toLowerCase()
  const page = await search(`id<=${colors || 'c'} f:commander -t:basic`, { order: 'edhrec', multilingual: false })
  return {
    cards: page.cards.filter((c) => !skip.has(String(c.name).toLowerCase())).slice(0, count),
    source: 'Scryfall (mais populares nas cores do comandante)',
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

/**
 * A lista do deck para colar no Moxfield, Arena, Archidekt...: "1 Sol Ring",
 * com o comandante numa seção à parte. english: id da Scryfall → nome em inglês.
 */
export function exportList(cards, english = new Map()) {
  const nameOf = (c) => english.get(scryfallIdOf(c) ?? '') ?? c.name ?? ''
  const count = (commander) => {
    const out = new Map()
    for (const c of cards) if (Boolean(c.commander) === commander && nameOf(c)) out.set(nameOf(c), (out.get(nameOf(c)) || 0) + 1)
    return [...out.keys()].sort().map((n) => `${out.get(n)} ${n}`).join('\n')
  }
  const commanders = count(true)
  const rest = count(false)
  return [commanders && `Commander\n${commanders}`, rest && `Deck\n${rest}`].filter(Boolean).join('\n\n')
}

/** Os nomes em inglês das cartas (pela Scryfall); vazio sem internet. */
export async function englishNames(cards) {
  try {
    const fresh = await refreshDeck(cards)
    return new Map(cards.map((c, i) => [scryfallIdOf(c) ?? '', fresh[i]?.name]).filter(([id, n]) => id && n))
  } catch {
    return new Map()
  }
}
