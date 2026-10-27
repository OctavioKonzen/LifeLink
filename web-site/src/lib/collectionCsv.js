// Importar e exportar a coleção (o mesmo do app, lib/data/services/collection_csv.dart):
// lê o CSV do Moxfield, ManaBox, Archidekt e Deckbox (ou uma lista de texto,
// "1 Sol Ring (CMM) 410") e gera o CSV no formato do Moxfield, que esses
// sites e apps também importam.

import { fetchDeckList, parseDeckList } from './deckTools'
import { addManyToCollection } from './collection'
import { scryfallIdOf } from './deckCards'
import { many } from './lifelinkCards'
import { postJson } from './scryfall'

/** O texto CSV → linhas (com aspas, vírgula, ponto e vírgula ou tab). */
export function parseCsv(text) {
  const first = String(text).split(/\r?\n/).find((l) => l.trim()) ?? ''
  const sep = [',', ';', '\t'].sort((a, b) => first.split(b).length - first.split(a).length)[0]
  const rows = []
  let row = []
  let cell = ''
  let quoted = false
  const s = String(text).replace(/^﻿/, '')
  for (let i = 0; i < s.length; i++) {
    const ch = s[i]
    if (quoted) {
      if (ch === '"' && s[i + 1] === '"') {
        cell += '"'
        i++
      } else if (ch === '"') quoted = false
      else cell += ch
    } else if (ch === '"') quoted = true
    else if (ch === sep) {
      row.push(cell)
      cell = ''
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && s[i + 1] === '\n') i++
      row.push(cell)
      if (row.some((c) => c.trim())) rows.push(row)
      row = []
      cell = ''
    } else cell += ch
  }
  row.push(cell)
  if (row.some((c) => c.trim())) rows.push(row)
  return rows
}

// Os nomes das colunas em cada site (em minúsculas).
const COLUMNS = {
  qty: ['count', 'quantity', 'qty', 'amount', 'quantidade', 'qtd'],
  name: ['name', 'card name', 'card', 'nome'],
  set: ['edition', 'set code', 'set', 'edition code', 'set_code', 'edicao', 'coleção', 'colecao'],
  number: ['collector number', 'card number', 'number', 'collector_number', 'cn', 'numero', 'número'],
}

/**
 * O que foi colado (ou o arquivo) → [{ qty, name, set, number }]. Com o
 * cabeçalho de um CSV conhecido lê as colunas; sem ele, lê como lista de texto.
 */
export function parseCollection(text) {
  const rows = parseCsv(text)
  const header = (rows[0] || []).map((h) => h.trim().toLowerCase())
  const col = (key) => header.findIndex((h) => COLUMNS[key].includes(h))
  const name = col('name')
  if (rows.length < 2 || name < 0) return parseDeckList(text).map(({ qty, name, set, number }) => ({ qty, name, set, number }))
  const qty = col('qty')
  const set = col('set')
  const number = col('number')
  const out = []
  for (const r of rows.slice(1)) {
    const n = (r[name] || '').trim()
    if (!n) continue
    const q = qty >= 0 ? Number.parseInt(r[qty], 10) : 1
    // A coleção pelo código (ex.: "cmm"); o nome da coleção (Deckbox) não serve.
    const code = set >= 0 ? (r[set] || '').trim() : ''
    out.push({
      qty: Number.isFinite(q) && q > 0 ? Math.min(q, 999) : 1,
      name: n,
      set: /^[A-Za-z0-9]{2,6}$/.test(code) ? code.toLowerCase() : null,
      number: number >= 0 && (r[number] || '').trim() ? r[number].trim() : null,
    })
  }
  return out
}

const quote = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`

/**
 * As cartas da coleção → o CSV do Moxfield. rows: [{ qty, trade, name (em
 * inglês), set (código), number }].
 */
export function collectionCsv(rows) {
  const header = ['Count', 'Tradelist Count', 'Name', 'Edition', 'Condition', 'Language', 'Foil', 'Tags', 'Last Modified', 'Collector Number', 'Alter', 'Proxy', 'Purchase Price']
  const lines = rows.map((r) => [r.qty, r.trade ? r.qty : 0, r.name, r.set || '', 'Near Mint', 'English', '', '', '', r.number || '', 'False', 'False', ''].map(quote).join(','))
  return [header.map(quote).join(','), ...lines].join('\n')
}

/** Uma lista de texto da coleção ("1 Sol Ring (CMM) 410"). */
export const collectionList = (rows) => rows.map((r) => `${r.qty} ${r.name}${r.set ? ` (${r.set.toUpperCase()})${r.number ? ` ${r.number}` : ''}` : ''}`).join('\n')

/**
 * Importa para a coleção: busca as cartas (banco do LifeLink e Scryfall) e
 * soma as quantidades. Volta { added (cópias), cards (diferentes), missing (nomes) }.
 */
export async function importCollection(text) {
  const lines = parseCollection(text)
  if (!lines.length) return { added: 0, cards: 0, missing: [] }
  const { cards, missing } = await fetchDeckList(lines)
  const byId = new Map()
  for (const c of cards) {
    const id = scryfallIdOf(c) ?? c.name
    const e = byId.get(id)
    if (e) e.n++
    else byId.set(id, { card: c, n: 1 })
  }
  addManyToCollection([...byId.values()])
  return { added: cards.length, cards: byId.size, missing }
}

/** A coleção → [{ qty, trade, name, set, number }] com o nome em inglês e o código da coleção. */
export async function exportRows(collection) {
  const saved = collection?.list || []
  const ids = saved.map((c) => c.id).filter((id) => /^[0-9a-f-]{36}$/.test(id))
  const found = new Map()
  try {
    for (const [id, c] of await many(ids, 'en')) found.set(id, c)
  } catch {
    // Vai pela Scryfall.
  }
  const rest = ids.filter((id) => !found.has(id))
  for (let start = 0; start < rest.length; start += 75) {
    try {
      const data = await postJson('https://api.scryfall.com/cards/collection', { identifiers: rest.slice(start, start + 75).map((id) => ({ id })) })
      for (const c of data.data || []) found.set(c.id, c)
    } catch {
      break
    }
  }
  return saved.map((c) => {
    const f = found.get(c.id)
    return { qty: c.qty || 1, trade: Boolean(c.trade), name: f?.name || c.name, set: f?.set || '', number: f?.collector_number || c.num || '' }
  })
}
