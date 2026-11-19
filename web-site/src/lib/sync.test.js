import { describe, expect, test, vi } from 'vitest'

vi.mock('./auth', () => ({ getAuthState: () => ({}), loadFirestore: async () => ({}), onAuthChange: () => () => {}, signOut: async () => {}, deleteAccount: async () => {} }))

const { keepLocal, stableText, unchangedSections } = await import('./sync')
const { applyRemote, getState } = await import('./userData')

// O bug do vídeo: a vida mudava sozinha no contador, porque qualquer mudança
// na conta (XP, coleção...) trazia de volta a partida guardada nela.
describe('sincronização com a conta', () => {
  test('a mesma parte em outra ordem é igual', () => {
    expect(stableText({ lives: [40, 31], playerCount: 2, extra: { b: 1, a: 2 } })).toBe(stableText({ extra: { a: 2, b: 1 }, playerCount: 2, lives: [40, 31] }))
    expect(stableText({ lives: [40, 31] })).not.toBe(stableText({ lives: [40, 30] }))
  })

  test('só o que mudou na conta é aplicado', () => {
    const seen = new Map()
    expect([...unchangedSections(seen, { game: { lives: [40, 40] }, profile: { xp: 10 } })]).toEqual([])
    expect([...unchangedSections(seen, { game: { lives: [40, 40] }, profile: { xp: 60 } })]).toEqual(['game'])
    expect([...unchangedSections(seen, { game: { lives: [35, 40] }, profile: { xp: 60 } })]).toEqual(['profile'])
  })

  test('o vídeo: a partida guardada na conta não volta por cima da atual', () => {
    const seen = new Map()
    const accountGame = { ...getState().game, playerCount: 2, lives: [75, 31, 40, 40, 40, 40] }
    const first = { game: accountGame, profile: { xp: 10 } }
    applyRemote(first, unchangedSections(seen, first))
    // A mesa online muda a partida aqui (sem passar pela conta).
    applyRemote({ game: { ...accountGame, lives: [21, 40, 40, 40, 40, 40] } })
    // Chega uma mudança de XP, com a partida antiga ainda na conta.
    const later = { game: accountGame, profile: { xp: 60 } }
    applyRemote(later, unchangedSections(seen, later))
    expect(getState().game.lives.slice(0, 2)).toEqual([21, 40])
  })

  test('outro aparelho com o contador aberto não troca a partida daqui', () => {
    const seen = new Map()
    const start = { game: { ...getState().game, playerCount: 2, lives: [40, 40, 40, 40, 40, 40] } }
    applyRemote(start, keepLocal({ unchanged: unchangedSections(seen, start), started: false }))
    applyRemote({ game: { ...getState().game, lives: [21, 40, 40, 40, 40, 40] } }) // jogou aqui
    const other = { game: { ...getState().game, playerCount: 5, lives: [75, 31, 31, 2, 6, 40] } }
    applyRemote(other, keepLocal({ unchanged: unchangedSections(seen, other), started: true }))
    expect(getState().game.playerCount).toBe(2)
    expect(getState().game.lives.slice(0, 2)).toEqual([21, 40])
  })

  test('a partida da conta vem ao entrar', () => {
    expect([...keepLocal({ started: false })]).toEqual([])
    expect([...keepLocal({ started: true })]).toEqual(['game'])
  })
})
