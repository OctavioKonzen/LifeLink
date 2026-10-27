// O link para compartilhar um deck (o mesmo do app, lib/data/services/deck_share.dart):
// o deck vai dentro do link, sem servidor. { n: nome, t: tipo, l: a lista no
// formato do Moxfield } → JSON → deflate (raw) → base64 de URL.
// Ex.: https://octaviokonzen.github.io/LifeLink/#/d/<código>

export const SITE = 'https://octaviokonzen.github.io/LifeLink/'

const toB64url = (bytes) => {
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

const fromB64url = (s) => {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
  const bin = atob(b64 + '==='.slice((b64.length + 3) % 4))
  return Uint8Array.from(bin, (c) => c.charCodeAt(0))
}

async function through(bytes, stream) {
  const out = new Response(new Blob([bytes]).stream().pipeThrough(stream))
  return new Uint8Array(await out.arrayBuffer())
}

/** O deck → o código do link. */
export async function encodeDeck({ name, type, list }) {
  const json = new TextEncoder().encode(JSON.stringify({ n: name, t: type, l: list }))
  return toB64url(await through(json, new CompressionStream('deflate-raw')))
}

/** O código do link → { name, type, list }. */
export async function decodeDeck(code) {
  const json = await through(fromB64url(code), new DecompressionStream('deflate-raw'))
  const d = JSON.parse(new TextDecoder().decode(json))
  return { name: String(d.n || 'Deck compartilhado'), type: String(d.t || 'Commander'), list: String(d.l || '') }
}

export const deckLink = (code) => `${SITE}#/d/${code}`

/** O código de um link de deck colado (ou null). */
export const codeFromLink = (text) => /#\/d\/([A-Za-z0-9_-]+)/.exec(String(text))?.[1] ?? null
