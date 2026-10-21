import { beforeEach, describe, expect, test } from 'vitest'
import { claimMission, claimSection, missionsFor, tierReward } from './missions'
import { clearAll, getState, updateSection } from './userData'

beforeEach(() => clearAll())

describe('missões (as mesmas regras do app)', () => {
  test('recompensas: foto, contorno a cada 2 e título a cada 10', () => {
    expect(tierReward(1).type).toBe('avatar')
    expect(tierReward(2)).toMatchObject({ type: 'border', name: 'Madeira Rústica' })
    expect(tierReward(10)).toMatchObject({ type: 'title', value: 'Novato do Mesão' })
  })

  test('a seção nova conta só o que foi feito nela', () => {
    updateSection('profile', (p) => ({ ...p, statSearches: 40 }))
    expect(missionsFor(getState().profile, 0)[3]).toMatchObject({ current: 40, target: 30 })
    claimMission(3, 100)
    expect(getState().profile.xp).toBe(100)
    claimMission(3, 100) // de novo não vale
    expect(getState().profile.xp).toBe(100)
    claimSection()
    const p = getState().profile
    expect(p.tier).toBe(2)
    expect(p.unlockedAvatars.length).toBe(1)
    expect(missionsFor(p, 0)[3]).toMatchObject({ current: 0, target: 45 })
  })
})
