import { describe, expect, test } from 'vitest'
import { dieShape, vec } from './geometry'

const SIDES = { d4: 4, d6: 6, d8: 8, d10: 10, d12: 12, d20: 20, d100: 10 }

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
    if (kind === 'd100') expect([...values].sort((a, b) => a - b)).toEqual([0, 10, 20, 30, 40, 50, 60, 70, 80, 90])
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
