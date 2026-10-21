import { describe, expect, test } from 'vitest'
import { dieShape, vec } from './geometry'

const SIDES = { d4: 4, d6: 6, d8: 8, d10: 10, d12: 12, d20: 20, d100: 100 }

describe.each(Object.keys(SIDES))('%s', (kind) => {
  const die = dieShape(kind)

  test('faces planas, viradas para fora', () => {
    expect(die.sides).toBe(SIDES[kind])
    for (const f of die.faces) {
      expect(vec.dot(f.normal, f.center)).toBeGreaterThan(0)
      for (const c of f.corners) expect(Math.abs(vec.dot(vec.sub(die.vertices[c], f.center), f.normal))).toBeLessThan(1e-6)
      // Cantos no sentido anti-horário visto de fora (o que a física pede).
      const [a, b, c] = f.corners.map((m) => die.vertices[m])
      expect(vec.dot(vec.cross(vec.sub(b, a), vec.sub(c, a)), f.normal)).toBeGreaterThan(0)
    }
  })

  test('números sem repetir', () => {
    const values = new Set(die.faces.map((f) => f.value))
    expect(values.size).toBe(die.sides)
    if (kind === 'd10') expect([...values].sort((a, b) => a - b)).toEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    if (kind === 'd100') expect([...values].sort((a, b) => a - b)).toEqual(Array.from({ length: 100 }, (_, i) => i + 1))
  })

  if (kind !== 'd4') {
    test('faces opostas somam o mesmo valor', () => {
      const sums = new Set(die.faces.map((f) => f.value + die.faces.find((g) => vec.len(vec.add(g.normal, f.normal)) < 1e-4).value))
      expect(sums.size).toBe(1)
    })
  }
})

test('D4 com um número em cada ponta', () => {
  expect(dieShape('d4').vertexValues).toEqual([1, 2, 3, 4])
})

test('D100: faces opostas somam 101 e 6/9 ganham ponto', () => {
  const die = dieShape('d100')
  const f1 = die.faces.find((f) => f.value === 1)
  const opposite = die.faces.find((g) => vec.len(vec.add(g.normal, f1.normal)) < 1e-4)
  expect(opposite.value).toBe(100)
  expect(die.faces.find((f) => f.value === 6).label).toBe('6.')
  expect(die.faces.find((f) => f.value === 69).label).toBe('69') // 69 de cabeça para baixo é 69
  expect(die.faces.find((f) => f.value === 10).label).toBe('10')
})

test('dado planar: caos no 1, viagem no 6 e o resto em branco', () => {
  const die = dieShape('planar')
  expect(die.sides).toBe(6)
  expect(die.faces.find((f) => f.value === 1).symbol).toBe('caos')
  expect(die.faces.find((f) => f.value === 6).symbol).toBe('viagem')
  expect(die.faces.filter((f) => !f.symbol).every((f) => f.label === '')).toBe(true)
})
