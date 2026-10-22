// O serviço de busca de cartas do LifeLink (Cloudflare Worker + D1).
//   GET /search?q=&name=&type=&set=&colors=&order=&dir=&page=&lang=
//   GET /names?q=          sugestões de nome enquanto digita
//   GET /health
// O resto (carta inteira, variações, preços, imagens) o app busca direto nos
// arquivos do R2. As respostas ficam guardadas por 1 hora (os dados mudam
// uma vez por dia).
import { PAGE, buildNames, buildSearch } from './search.js'

const HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
}

const json = (body, status = 200, cache = 3600) =>
  new Response(JSON.stringify(body), { status, headers: { ...HEADERS, 'Cache-Control': `public, max-age=${cache}` } })

async function handle(url, env) {
  if (url.pathname === '/health') {
    const row = await env.DB.prepare('SELECT COUNT(*) AS cards FROM cards').first()
    return json({ ok: true, cards: row?.cards ?? 0 }, 200, 60)
  }
  if (url.pathname === '/names') {
    const query = buildNames(url.searchParams.get('q'))
    if (!query) return json({ names: [] })
    const { results } = await env.DB.prepare(query.sql).bind(...query.args).all()
    return json({ names: results })
  }
  if (url.pathname === '/search') {
    const { sql, args } = buildSearch(url.searchParams)
    const { results } = await env.DB.prepare(sql).bind(...args).all()
    return json({ cards: results.slice(0, PAGE), hasMore: results.length > PAGE })
  }
  return json({ error: 'não encontrado' }, 404, 60)
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: HEADERS })
    if (request.method !== 'GET') return json({ error: 'só GET' }, 405, 0)
    const cache = caches.default
    const hit = await cache.match(request)
    if (hit) return hit
    const url = new URL(request.url)
    let response
    try {
      response = await handle(url, env)
    } catch (e) {
      // Ex.: busca com caracteres que o FTS não aceita, ou limite do dia.
      return json({ error: String(e?.message || e) }, 400, 0)
    }
    if (response.status === 200) ctx.waitUntil(cache.put(request, response.clone()))
    return response
  },
}
