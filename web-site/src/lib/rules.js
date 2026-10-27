// O juiz de regras (o mesmo do app, lib/data/services/rules_service.dart):
// as Regras Completas de Magic (data/rules.json no R2, gerado por
// tool/build_rules.py) e a busca nelas, em português ou inglês.

import { R2 } from './lifelinkCards'

let loading = null

/** As regras (baixadas uma vez por visita). */
export function loadRules() {
  loading ??= fetch(`${R2}/data/rules.json`).then((r) => {
    if (!r.ok) throw new Error('As regras ainda não estão disponíveis. Tente mais tarde.')
    return r.json()
  })
  loading.catch(() => {
    loading = null
  })
  return loading
}

/** Minúsculas, sem acento e só letras e números (o texto e a busca no mesmo formato). */
export const norm = (s) =>
  String(s ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/'/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()

const cache = new WeakMap()

/** O que dá para calcular uma vez por arquivo de regras. */
function prepared(data) {
  let p = cache.get(data)
  if (!p) {
    p = {
      rules: data.rules.map(([, text]) => ` ${norm(text)} `),
      glossary: data.glossary.map(([term]) => norm(term)),
      pt: Object.entries(data.pt || {})
        .map(([k, v]) => [` ${norm(k)} `, norm(v)])
        .sort((a, b) => b[0].length - a[0].length),
      stop: new Set(data.stop || []),
    }
    cache.set(data, p)
  }
  return p
}

/** Os termos da pergunta: os do dicionário (em inglês) e as outras palavras. */
export function termsOf(query, data) {
  const p = prepared(data)
  let q = ` ${norm(query)} `
  const out = []
  for (const [pt, en] of p.pt) {
    if (!q.includes(pt)) continue
    if (!out.some((t) => t.term === en)) out.push({ term: en, weight: 2 })
    q = q.split(pt).join(' ')
  }
  for (const w of q.split(' ')) {
    if (w.length >= 3 && !p.stop.has(w) && !out.some((t) => t.term === w)) out.push({ term: w, weight: 1 })
  }
  return out
}

/** A regra e as letras dela (702.19 → 702.19, 702.19a, 702.19b...). */
export function family(data, id) {
  const base = id.replace(/[a-z]$/, '')
  return data.rules.filter(([r]) => r === base || (r.startsWith(base) && /^[a-z]$/.test(r.slice(base.length))))
}

/** O nome da seção da regra (702 → "Keyword Abilities"). */
export const sectionOf = (data, id) => data.sections?.[id.slice(0, 3)] ?? ''

/**
 * Busca nas regras: { terms, glossary: [[termo, texto]], rules: [[id, texto]] }.
 * Um número de regra (ex.: 702.19) mostra a regra e as letras dela.
 */
export function searchRules(data, query, limit = 30) {
  const q = String(query).trim().replace(/\.$/, '')
  if (/^\d{3}(\.\d+[a-z]?)?$/i.test(q)) {
    const id = q.toLowerCase()
    const rules = id.length === 3 ? data.rules.filter(([r]) => r.startsWith(`${id}.`)) : family(data, id)
    return { terms: [], glossary: [], rules: rules.slice(0, 80) }
  }
  const terms = termsOf(q, data)
  if (!terms.length) return { terms: [], glossary: [], rules: [] }
  const p = prepared(data)
  const has = (text, term) => text.includes(` ${term} `)

  // A regra-título de um termo (ex.: "702.19. Trample") e as letras dela sobem.
  const titles = []
  data.rules.forEach(([id], i) => {
    if (terms.some((t) => p.rules[i] === ` ${t.term} `)) titles.push(id)
  })
  const inTitle = (id) => titles.some((base) => id === base || (id.startsWith(base) && /^[a-z]$/.test(id.slice(base.length))))

  const scored = []
  data.rules.forEach(([id], i) => {
    let score = 0
    let hits = 0
    for (const t of terms) {
      if (!has(p.rules[i], t.term)) continue
      score += t.weight * (t.term.includes(' ') ? 2 : 1)
      hits++
    }
    if (!score) return
    score += hits * hits + (inTitle(id) ? 3 : 0)
    scored.push({ i, score })
  })
  scored.sort((a, b) => b.score - a.score || a.i - b.i)

  const glossary = []
  data.glossary.forEach((g, i) => {
    const term = p.glossary[i]
    let score = terms.some((t) => t.term === term) ? 20 : terms.some((t) => t.term.length >= 4 && ` ${term} `.includes(` ${t.term} `)) ? 6 : 0
    if (!score) return
    score += terms.filter((t) => has(` ${norm(g[1])} `, t.term)).length
    glossary.push({ g, score })
  })
  glossary.sort((a, b) => b.score - a.score)

  return {
    terms: terms.map((t) => t.term),
    glossary: glossary.slice(0, 4).map((x) => x.g),
    rules: scored.slice(0, limit).map(({ i }) => data.rules[i]),
  }
}
