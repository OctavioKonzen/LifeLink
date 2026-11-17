import { describe, expect, test, vi } from 'vitest'

vi.mock('./auth', () => ({ getAuthState: () => ({}), loadFirestore: async () => ({}), onAuthChange: () => () => {}, signOut: async () => {}, deleteAccount: async () => {} }))

const { stableText } = await import('./sync')

describe('sincronização com a conta', () => {
  test('a mesma parte em outra ordem é igual (não reaplica a partida)', () => {
    expect(stableText({ lives: [40, 31], playerCount: 2, extra: { b: 1, a: 2 } })).toBe(stableText({ extra: { a: 2, b: 1 }, playerCount: 2, lives: [40, 31] }))
  })

  test('uma vida diferente muda o texto', () => {
    expect(stableText({ lives: [40, 31] })).not.toBe(stableText({ lives: [40, 30] }))
  })
})
