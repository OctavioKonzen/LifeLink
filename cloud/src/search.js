// A busca em si (sem nada do Worker), para dar para testar com `node --test`.

const COLUMNS = 'c.o, c.id, c.n, c.pn, c.t, c.pt, c.m, c.cmc, c.ci, c.r, c.usd, c.img'
export const PAGE = 60

// Ordem: nome, valor de mana, preço, mais novas ou mais usadas (EDHREC).
const ORDERS = {
  name: (pt) => (pt ? 'COALESCE(c.pn, c.n)' : 'c.n'),
  cmc: () => 'c.cmc',
  usd: () => 'c.usd',
  released: () => 'c.d',
  popular: () => 'c.er',
}

/** Palavras digitadas → consulta do FTS5 (cada palavra é começo de palavra). */
export function ftsTerms(text, columns) {
  const words = String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .slice(0, 8)
  if (!words.length) return ''
  const terms = words.map((w) => `"${w}"*`).join(' ')
  return columns ? `{${columns}} : (${terms})` : `(${terms})`
}

/**
 * Os parâmetros da busca → { sql, args }.
 * q: texto (nome, tipo ou texto da carta, em inglês ou português)
 * name=1: só no nome; type: tipo (ex.: Creature) ou raça; set: coleção;
 * colors: identidade dentro dessas cores (ex.: WU); order, dir, page, lang.
 */
export function buildSearch(params) {
  // URLSearchParams (no Worker) ou objeto comum (nos testes); cuidado: "set"
  // também é um método do URLSearchParams.
  const get = (k) => (typeof params.get === 'function' ? params.get(k) : params[k]) ?? ''
  const pt = get('lang') !== 'en'
  const match = []
  const q = ftsTerms(get('q'), get('name') === '1' ? 'n pn' : '')
  if (q) match.push(q)
  for (const type of String(get('type')).split(',').filter(Boolean)) {
    const t = ftsTerms(type, 't pt')
    if (t) match.push(t)
  }
  const set = String(get('set')).toLowerCase().replace(/[^a-z0-9]/g, '')
  if (set) match.push(`{ss} : "${set}"`)

  const where = []
  const args = []
  if (match.length) {
    where.push('cards_fts MATCH ?')
    args.push(match.join(' AND '))
  }
  // Identidade de cor dentro das escolhidas (como o id<= da Scryfall).
  const colors = String(get('colors')).toUpperCase().replace(/[^WUBRG]/g, '')
  if (get('colors')) {
    where.push(colors ? `c.ci NOT GLOB '*[^${colors}]*'` : "c.ci = ''")
  }

  // Com texto e sem ordem escolhida: relevância (nome igual ao digitado,
  // depois o nome com as palavras, depois o texto), e as mais usadas antes.
  const typed = String(get('q')).trim().toLowerCase()
  const order = ORDERS[get('order')] ? get('order') : q ? 'relevance' : 'popular'
  if (order === 'relevance') {
    args.push(typed, typed)
    const page = Math.max(0, Math.min(50, parseInt(get('page'), 10) || 0))
    const sql =
      `SELECT ${COLUMNS} FROM cards_fts JOIN cards c ON c.k = cards_fts.rowid WHERE ${where.join(' AND ')}` +
      ` ORDER BY (lower(c.n) = ? OR lower(c.pn) = ?) DESC, bm25(cards_fts, 10, 10, 2, 2, 1, 1, 0) + COALESCE(c.er, 99999) / 20000.0` +
      ` LIMIT ${PAGE + 1} OFFSET ${page * PAGE}`
    return { sql, args }
  }
  const dir = get('dir') === 'desc' ? 'DESC' : 'ASC'
  const nulls = order === 'usd' || order === 'popular' ? `${ORDERS[order](pt)} IS NULL, ` : ''
  const page = Math.max(0, Math.min(50, parseInt(get('page'), 10) || 0))
  const from = match.length ? 'cards_fts JOIN cards c ON c.k = cards_fts.rowid' : 'cards c'
  const sql =
    `SELECT ${COLUMNS} FROM ${from}` +
    (where.length ? ` WHERE ${where.join(' AND ')}` : '') +
    ` ORDER BY ${nulls}${ORDERS[order](pt)} ${dir}, c.n LIMIT ${PAGE + 1} OFFSET ${page * PAGE}`
  return { sql, args }
}

/** Sugestões de nome enquanto digita (inglês e português). */
export function buildNames(text) {
  const q = ftsTerms(text, 'n pn')
  if (!q) return null
  return {
    sql: 'SELECT c.n, c.pn FROM cards_fts JOIN cards c ON c.k = cards_fts.rowid WHERE cards_fts MATCH ? ORDER BY c.er IS NULL, c.er LIMIT 10',
    args: [q],
  }
}
