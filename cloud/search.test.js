import { test } from 'node:test'
import assert from 'node:assert/strict'
import { buildNames, buildSearch, ftsTerms } from './src/search.js'

test('palavras viram começo de palavra, sem acento', () => {
  assert.equal(ftsTerms('Anel Solár'), '("anel"* "solar"*)')
  assert.equal(ftsTerms('  '), '')
  assert.equal(ftsTerms('a"b OR c', 'n pn'), '{n pn} : ("a"* "b"* "or"* "c"*)')
})

test('busca com texto, tipo, coleção e cores', () => {
  const { sql, args } = buildSearch(new URLSearchParams('q=anel&type=Artifact&set=CMM&colors=WU&order=usd&dir=desc&page=2'))
  assert.equal(args[0], '("anel"*) AND {t pt} : ("artifact"*) AND {ss} : "cmm"')
  assert.match(sql, /cards_fts MATCH \?/)
  assert.match(sql, /c\.ci NOT GLOB '\*\[\^WU\]\*'/)
  assert.match(sql, /ORDER BY c\.usd IS NULL, c\.usd DESC/)
  assert.match(sql, /LIMIT 61 OFFSET 120/)
})

test('sem coleção na URL não vira filtro (set é método do URLSearchParams)', () => {
  const { args } = buildSearch(new URLSearchParams('q=anel'))
  assert.equal(args[0], '("anel"*)')
})

test('sem texto: as mais usadas, sem FTS', () => {
  const { sql, args } = buildSearch({ colors: 'G' })
  assert.deepEqual(args, [])
  assert.match(sql, /FROM cards c WHERE/)
  assert.match(sql, /ORDER BY c\.er IS NULL, c\.er ASC/)
})

test('com texto e sem ordem: relevância (nome igual primeiro)', () => {
  const { sql, args } = buildSearch({ q: 'Lightning Bolt' })
  assert.match(sql, /bm25\(cards_fts/)
  assert.deepEqual(args.slice(1), ['lightning bolt', 'lightning bolt'])
})

test('incolor e nome em português primeiro', () => {
  const { sql } = buildSearch({ q: 'anel', colors: 'C', name: '1', order: 'name' })
  assert.match(sql, /c\.ci = ''/)
  assert.match(sql, /COALESCE\(c\.pn, c\.n\)/)
  assert.equal(buildNames(''), null)
})
