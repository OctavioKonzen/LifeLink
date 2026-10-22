import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import {
  R2,
  byPrint,
  card,
  imageUrl,
  many,
  names,
  plainText,
  printBySetNumber,
  resetCache,
  scryfallCard,
  search,
  toScryfall,
  topPrices,
  typePool,
  variationFor,
  versions,
} from './lifelinkCards'
import { backImageOf, displayName, imageOf, manaCost, oracleText, typeLine } from './scryfall'
import { toDeckCard } from './deckCards'

const ORACLE = 'abcd0000-0000-0000-0000-000000000000'
const EN = 'e1110000-0000-0000-0000-000000000000'
const PT = 'f2220000-0000-0000-0000-000000000000'
const WORKER = 'https://busca.example.workers.dev'

const SOL = {
  id: EN,
  o: ORACLE,
  n: 'Sol Ring',
  m: '{1}',
  cmc: 1,
  t: 'Artifact',
  x: '{T}: Add {C}{C}.',
  ci: '',
  lg: { commander: 'l', vintage: 'r', legacy: 'b' },
  gc: 1,
  pn: 'Anel Solar',
  pt: 'Artefato',
  px: '{T}: Adicione {C}{C}.',
  v: [
    { id: EN, s: 'cmm', cn: '410', r: 'uncommon', l: 'en', d: '2023-08-04', a: 'Mike Bierek', i: 1 },
    { id: PT, s: 'c21', cn: '263', r: 'uncommon', l: 'pt', d: '2021-04-23', pn: 'Anel Solar', pt: 'Artefato', px: '{T}: Adicione {C}{C}.' },
  ],
}

const DFC_ID = 'aa110000-0000-0000-0000-000000000000'
const DFC = {
  id: DFC_ID,
  o: 'dd000000-0000-0000-0000-000000000000',
  n: 'Delver of Secrets // Insectile Aberration',
  m: '{U}',
  cmc: 1,
  t: 'Creature — Human Wizard // Creature — Human Insect',
  x: 'At the beginning of your upkeep...',
  ci: 'U',
  f: [
    { n: 'Delver of Secrets', m: '{U}', t: 'Creature — Human Wizard', x: 'At the beginning of your upkeep...', pw: '1', tg: '1', c: 'U' },
    { n: 'Insectile Aberration', t: 'Creature — Human Insect', x: 'Flying', pw: '3', tg: '2', c: 'U' },
  ],
  v: [{ id: DFC_ID, s: 'isd', cn: '51', r: 'common', l: 'en', b: 1 }],
}

let files
let calls

function response(status, body) {
  return { ok: status >= 200 && status < 300, status, json: async () => body }
}

beforeEach(() => {
  resetCache()
  calls = []
  files = {
    [`c/${ORACLE}.json`]: SOL,
    [`pr/ab.json`]: { [ORACLE]: { [EN]: { usd: '1.25', usd_foil: '3.10', eur: '0.95' } } },
    [`id/e11.json`]: { [EN]: ORACLE },
    [`id/f22.json`]: { [PT]: ORACLE },
    [`set/cmm.json`]: { '410|en': EN },
    'sets.json': { cmm: 'Commander Masters', c21: 'Commander 2021' },
    'data/config.json': { search: `${WORKER}/` },
  }
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url) => {
      calls.push(url)
      if (url.startsWith(`${R2}/`)) {
        const path = url.slice(R2.length + 1)
        return path in files ? response(200, files[path]) : response(404, {})
      }
      if (url.startsWith(`${WORKER}/search`)) {
        const q = new URL(url).searchParams
        if (q.get('type') === 'Plane') {
          return response(200, {
            cards: [
              { o: 'p1', id: 'p1000000', n: 'Akoum', t: 'Plane — Zendikar' },
              { o: 'p2', id: 'p2000000', n: 'Jace Beleren', t: 'Legendary Planeswalker — Jace' },
            ],
            hasMore: false,
          })
        }
        return response(200, {
          cards: [{ o: ORACLE, id: EN, n: 'Sol Ring', pn: 'Anel Solar', t: 'Artifact', pt: 'Artefato', m: '{1}', cmc: 1, ci: '', r: 'uncommon', usd: 1.2, img: 1 }],
          hasMore: true,
        })
      }
      if (url.startsWith(`${WORKER}/names`)) return response(200, { names: [{ n: 'Sol Ring', pn: 'Anel Solar' }, { n: 'Solemn Simulacrum' }] })
      return response(500, {})
    }),
  )
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('imagens', () => {
  test('do R2 quando já foi copiada, senão do servidor de imagens da Scryfall', () => {
    expect(imageUrl(EN)).toBe(`${R2}/img/${EN}.jpg`)
    expect(imageUrl(EN, { back: true })).toBe(`${R2}/img/${EN}-b.jpg`)
    expect(imageUrl(EN, { inR2: false })).toBe(`https://cards.scryfall.io/normal/front/e/1/${EN}.jpg`)
    expect(imageUrl(EN, { inR2: false, back: true })).toBe(`https://cards.scryfall.io/normal/back/e/1/${EN}.jpg`)
  })
})

describe('cartas do R2', () => {
  test('junta os preços de hoje nas variações', async () => {
    const c = await card(ORACLE)
    expect(c.v[0].$).toEqual({ usd: '1.25', usd_foil: '3.10', eur: '0.95' })
    expect(c.v[1].$).toBeUndefined()
  })

  test('sem o arquivo de preços, a carta vem mesmo assim', async () => {
    delete files['pr/ab.json']
    const c = await card(ORACLE)
    expect(c.n).toBe('Sol Ring')
    expect(c.v[0].$).toBeUndefined()
  })

  test('guarda os arquivos já baixados', async () => {
    await card(ORACLE)
    await card(ORACLE)
    expect(calls.filter((u) => u.endsWith(`c/${ORACLE}.json`))).toHaveLength(1)
  })

  test('pelo código da variação, e pela coleção e número', async () => {
    const found = await byPrint(PT)
    expect(found.card.o).toBe(ORACLE)
    expect(found.variation.l).toBe('pt')
    expect(await printBySetNumber('CMM', '410')).toBe(EN)
    expect(await printBySetNumber('cmm', '999')).toBeNull()
  })

  test('404: null (quem chama vai para a Scryfall)', async () => {
    expect(await byPrint('99990000-0000-0000-0000-000000000000')).toBeNull()
    expect(await card('ffff0000-0000-0000-0000-000000000000')).toBeNull()
    expect(await printBySetNumber('xyz', '1')).toBeNull()
    expect(await scryfallCard('99990000-0000-0000-0000-000000000000')).toBeNull()
  })

  test('erro do servidor: lança (e tenta de novo na próxima vez)', async () => {
    fetch.mockImplementationOnce(async () => response(503, {}))
    await expect(byPrint(EN)).rejects.toThrow('503')
    expect((await byPrint(EN)).variation.id).toBe(EN)
  })

  test('variação principal no idioma pedido', () => {
    expect(variationFor(SOL, 'pt').id).toBe(PT)
    expect(variationFor(SOL, 'en').id).toBe(EN)
    expect(variationFor({ ...SOL, v: [SOL.v[0]] }, 'pt').id).toBe(EN)
  })

  test('outras versões por idioma', async () => {
    const pt = await versions(ORACLE, 'pt')
    expect(pt.map((c) => c.id)).toEqual([PT])
    expect(pt[0].printed_name).toBe('Anel Solar')
    expect((await versions(ORACLE, 'en'))[0].set_name).toBe('Commander Masters')
  })

  test('várias de uma vez: as que não estão no banco ficam de fora', async () => {
    const out = await many([EN, PT, '99990000-0000-0000-0000-000000000000'])
    expect([...out.keys()].sort()).toEqual([EN, PT].sort())
    expect(out.get(EN).prices.usd).toBe('1.25')
  })
})

describe('formato da Scryfall', () => {
  test('a carta funciona com os componentes do site', async () => {
    const c = await scryfallCard(EN)
    expect(c).toMatchObject({
      id: EN,
      oracle_id: ORACLE,
      name: 'Sol Ring',
      lang: 'en',
      mana_cost: '{1}',
      cmc: 1,
      type_line: 'Artifact',
      oracle_text: '{T}: Add {C}{C}.',
      color_identity: [],
      rarity: 'uncommon',
      set: 'cmm',
      set_name: 'Commander Masters',
      collector_number: '410',
      artist: 'Mike Bierek',
      game_changer: true,
      released_at: '2023-08-04',
      scryfall_uri: 'https://scryfall.com/card/cmm/410',
      rulings_uri: `https://api.scryfall.com/cards/${EN}/rulings`,
    })
    expect(c.prices).toMatchObject({ usd: '1.25', usd_foil: '3.10', eur: '0.95', eur_foil: null, tix: null })
    expect(c.legalities).toMatchObject({ commander: 'legal', vintage: 'restricted', legacy: 'banned', modern: 'not_legal', standard: 'not_legal' })
    expect(c.image_uris).toEqual({ small: `${R2}/img/${EN}.jpg`, normal: `${R2}/img/${EN}.jpg`, large: `${R2}/img/${EN}.jpg`, png: `${R2}/img/${EN}.jpg` })
    expect(c.printed_name).toBeUndefined()
    expect(displayName(c)).toBe('Sol Ring')
    expect(toDeckCard(c)).toMatchObject({ id: EN, name: 'Sol Ring', imageUrl: `${R2}/img/${EN}.jpg`, color_identity: 'C', usdPrice: '1.25', setName: 'Commander Masters' })
  })

  test('em português: printed_name, tipo e texto impressos', () => {
    const c = toScryfall(SOL, SOL.v[1], {})
    expect(c.lang).toBe('pt')
    expect(displayName(c)).toBe('Anel Solar')
    expect(typeLine(c)).toBe('Artefato')
    expect(oracleText(c)).toBe('{T}: Adicione {C}{C}.')
    expect(c.oracle_text).toBe('{T}: Add {C}{C}.')
    expect(c.set_name).toBe('C21')
    // Imagem que ainda não está no R2: servidor de imagens da Scryfall.
    expect(imageOf(c)).toBe(`https://cards.scryfall.io/normal/front/f/2/${PT}.jpg`)
  })

  test('duas faces: imagem em cada face e o verso', () => {
    const c = toScryfall(DFC, DFC.v[0], {})
    expect(c.image_uris).toBeUndefined()
    expect(imageOf(c)).toBe(`https://cards.scryfall.io/normal/front/a/a/${DFC_ID}.jpg`)
    expect(backImageOf(c)).toBe(`https://cards.scryfall.io/normal/back/a/a/${DFC_ID}.jpg`)
    expect(c.card_faces.map((f) => f.name)).toEqual(['Delver of Secrets', 'Insectile Aberration'])
    expect(manaCost(c)).toBe('{U}')
    expect(oracleText(c)).toContain('Flying')
    expect(toDeckCard(c)).toMatchObject({ power: '1', toughness: '1', color_identity: 'U' })
  })
})

describe('busca e preços', () => {
  test('busca no Worker (endereço do data/config.json)', async () => {
    const r = await search({ text: 'sol ring', types: ['Artifact'], colors: 'WU', page: 2 })
    const url = new URL(calls.find((u) => u.startsWith(WORKER)))
    expect(url.pathname).toBe('/search')
    expect(Object.fromEntries(url.searchParams)).toEqual({ q: 'sol ring', type: 'Artifact', colors: 'WU', page: '2', lang: 'pt' })
    expect(r.hasMore).toBe(true)
    expect(r.cards[0]).toMatchObject({ id: EN, name: 'Sol Ring', printed_name: 'Anel Solar', printed_type_line: 'Artefato', color_identity: [], _lifelink: 'summary' })
    expect(r.cards[0].prices.usd).toBe('1.20')
    expect(imageOf(r.cards[0])).toBe(`${R2}/img/${EN}.jpg`)
  })

  test('ordem e direção vão quando pedidas', async () => {
    await search({ text: 'bolt', order: 'usd', desc: true, nameOnly: true, lang: 'en' })
    const url = new URL(calls.find((u) => u.startsWith(WORKER)))
    expect(url.searchParams.get('order')).toBe('usd')
    expect(url.searchParams.get('dir')).toBe('desc')
    expect(url.searchParams.get('name')).toBe('1')
    expect(url.searchParams.get('lang')).toBe('en')
  })

  test('sugestões de nome em português ou inglês', async () => {
    expect(await names('sol')).toEqual(['Anel Solar', 'Solemn Simulacrum'])
    expect(await names('sol', 'en')).toEqual(['Sol Ring', 'Solemn Simulacrum'])
  })

  test('sem o config da busca (ainda não no ar): lança', async () => {
    delete files['data/config.json']
    await expect(search({ text: 'x' })).rejects.toThrow()
    await expect(names('x')).rejects.toThrow()
  })

  test('as mais caras do data/top.json', async () => {
    files['data/top.json'] = [{ id: EN, o: ORACLE, n: 'Sol Ring', pn: 'Anel Solar', l: 'pt', s: 'cmm', sn: 'Commander Masters', cn: '410', r: 'uncommon', t: 'Artifact', ci: 'W', i: 1, $: { usd: 999.5 } }]
    const [c] = await topPrices()
    expect(c).toMatchObject({ id: EN, printed_name: 'Anel Solar', lang: 'pt', set_name: 'Commander Masters', color_identity: ['W'] })
    expect(c.prices.usd).toBe('999.5')
    expect(imageOf(c, 'small')).toBe(`${R2}/img/${EN}.jpg`)
  })

  test('sem o data/top.json: lança (a tela usa a Scryfall)', async () => {
    await expect(topPrices()).rejects.toThrow()
  })

  test('planos: "plane" não traz planeswalker', async () => {
    const pool = await typePool(['Plane'])
    expect(pool.map((c) => c.name)).toEqual(['Akoum'])
  })

  test('sintaxe da Scryfall fica com a Scryfall', () => {
    expect(plainText('raio')).toBe(true)
    expect(plainText('t:dragon')).toBe(false)
    expect(plainText('usd>10')).toBe(false)
  })
})
