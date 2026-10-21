// Formatos e numeração dos dados (D4 a D20 e D100), como nos dados de
// verdade: faces opostas somam o mesmo valor (1 oposto ao 20 no D20, 1 ao 6
// no D6...), 6 e 9 com ponto e, no D4, os números nas pontas (vale o de cima).
// Usado pelo motor 3D (engine.js) no site e, pela mesma página, no app.

const PHI = 1.618033988749895

const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k]
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
const len = (a) => Math.sqrt(dot(a, a))
const unit = (a) => mul(a, 1 / len(a))
export const vec = { add, sub, mul, dot, cross, len, unit }

const centerOf = (pts) => mul(pts.reduce(add, [0, 0, 0]), 1 / pts.length)

function rawVertices(kind) {
  switch (kind) {
    case 'd4':
      return [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]
    case 'd6':
      return [-1, 1].flatMap((x) => [-1, 1].flatMap((y) => [-1, 1].map((z) => [x, y, z])))
    case 'd8':
      return [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
    case 'd12': {
      const q = 1 / PHI
      const cube = [-1, 1].flatMap((x) => [-1, 1].flatMap((y) => [-1, 1].map((z) => [x, y, z])))
      const rest = [-q, q].flatMap((a) => [-PHI, PHI].flatMap((b) => [[0, a, b], [a, b, 0], [b, 0, a]]))
      return [...cube, ...rest]
    }
    case 'd20':
      return [-1, 1].flatMap((a) => [-PHI, PHI].flatMap((b) => [[0, a, b], [a, b, 0], [b, 0, a]]))
    case 'd10':
    case 'd100': {
      // Dois polos e dez vértices em zigue-zague; esta altura dos polos deixa
      // cada face (um "pipa") plana: h = z0·(1 + cos36°)/(1 − cos36°).
      const z0 = 0.105
      const c = Math.cos(Math.PI / 5)
      const h = (z0 * (1 + c)) / (1 - c)
      const ring = Array.from({ length: 10 }, (_, i) => [Math.cos((i * Math.PI) / 5), Math.sin((i * Math.PI) / 5), i % 2 === 0 ? z0 : -z0])
      return [[0, 0, h], [0, 0, -h], ...ring]
    }
    default:
      throw new Error(`Dado desconhecido: ${kind}`)
  }
}

/** Faces de um sólido convexo, com os cantos em volta do centro (sentido anti-horário visto de fora). */
function hullFaces(v) {
  const faces = []
  const seen = new Set()
  const n = v.length
  for (let i = 0; i < n; i++)
    for (let j = i + 1; j < n; j++)
      for (let k = j + 1; k < n; k++) {
        let normal = cross(sub(v[j], v[i]), sub(v[k], v[i]))
        if (len(normal) < 1e-9) continue
        normal = unit(normal)
        const d = dot(normal, v[i])
        let above = 0
        let below = 0
        const onPlane = []
        for (let m = 0; m < n; m++) {
          const s = dot(normal, v[m]) - d
          if (s > 1e-6) above++
          else if (s < -1e-6) below++
          else onPlane.push(m)
        }
        if (above && below) continue
        const key = onPlane.join(',')
        if (seen.has(key)) continue
        seen.add(key)
        if (above) normal = mul(normal, -1)
        const center = centerOf(onPlane.map((m) => v[m]))
        const ref = unit(sub(v[onPlane[0]], center))
        const ref2 = cross(normal, ref)
        const angle = (m) => {
          const p = sub(v[m], center)
          return Math.atan2(dot(p, ref2), dot(p, ref))
        }
        onPlane.sort((a, b) => angle(a) - angle(b))
        faces.push(onPlane)
      }
  return faces
}

const marked = (value, kind) => (value === 6 || value === 9) && !['d4', 'd6', 'd8'].includes(kind)

const cache = new Map()

/**
 * Um dado: vértices (raio 1), faces com cantos, centro, normal, "para cima" do
 * número, valor e texto. No D4 os valores ficam nos vértices (vertexValues).
 */
export function dieShape(kind) {
  if (cache.has(kind)) return cache.get(kind)
  const raw = rawVertices(kind)
  const radius = Math.max(...raw.map(len))
  const vertices = raw.map((p) => mul(p, 1 / radius))
  const corners = hullFaces(vertices)

  const centers = corners.map((c) => centerOf(c.map((m) => vertices[m])))
  const normals = corners.map((c, i) => {
    let nrm = unit(cross(sub(vertices[c[1]], vertices[c[0]]), sub(vertices[c[2]], vertices[c[0]])))
    if (dot(nrm, centers[i]) < 0) nrm = mul(nrm, -1)
    return nrm
  })

  // Numeração: pares de faces opostas recebem (menor, maior), percorrendo de
  // cima para baixo em espiral para espalhar os números.
  const first = kind === 'd10' || kind === 'd100' ? 0 : 1
  const order = corners.map((_, i) => i).sort((a, b) => {
    const dz = normals[b][2] - normals[a][2]
    if (Math.abs(dz) > 1e-6) return dz
    return Math.atan2(normals[a][1], normals[a][0]) - Math.atan2(normals[b][1], normals[b][0])
  })
  const values = Array.from({ length: corners.length }, () => null)
  let low = first
  let high = first + corners.length - 1
  for (const i of order) {
    if (values[i] !== null) continue
    const opposite = corners.findIndex((_, j) => j !== i && values[j] === null && len(add(normals[j], normals[i])) < 1e-4)
    values[i] = low++
    if (opposite >= 0) values[opposite] = high--
  }

  const faces = corners.map((c, i) => {
    const center = centers[i]
    const normal = normals[i]
    let toward
    if (kind === 'd10' || kind === 'd100') {
      // No D10 o número aponta para o polo (como no dado real).
      toward = c.map((m) => vertices[m]).find((p) => Math.abs(p[0]) < 1e-9 && Math.abs(p[1]) < 1e-9)
    } else if (kind === 'd6') {
      toward = mul(add(vertices[c[0]], vertices[c[1]]), 0.5)
    } else {
      toward = vertices[c[0]]
    }
    let up = sub(toward, center)
    up = unit(sub(up, mul(normal, dot(up, normal))))
    const value = kind === 'd100' ? values[i] * 10 : values[i]
    const label = kind === 'd100' ? `${values[i]}0` : `${values[i]}${marked(values[i], kind) ? '.' : ''}`
    return { corners: c, center, normal, up, value, label }
  })

  // D4: cada ponta tem um número (1 a 4) e vale o da ponta de cima.
  const vertexValues = kind === 'd4' ? vertices.map((_, i) => i + 1) : null

  const shape = { kind, vertices, faces, vertexValues, sides: faces.length }
  cache.set(kind, shape)
  return shape
}

export const DICE = [
  { kind: 'd4', label: 'D4', color: '#43a047' },
  { kind: 'd6', label: 'D6', color: '#1e88e5' },
  { kind: 'd8', label: 'D8', color: '#8e24aa' },
  { kind: 'd10', label: 'D10', color: '#f4511e' },
  { kind: 'd12', label: 'D12', color: '#e53935' },
  { kind: 'd20', label: 'D20', color: '#ffa000' },
  { kind: 'd100', label: 'D100', color: '#00897b' },
]
