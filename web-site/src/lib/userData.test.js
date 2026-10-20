import { beforeEach, describe, expect, test } from 'vitest'
import { applyRemote, applyRemoteDecks, clearAll, deckList, deleteDeck, getState, hooks, saveDeck, updateSection } from './userData'
import { incrementCardsAdded, incrementMatches, withXp, xpForNextLevel } from './xp'
import { scryfallIdOf } from './deckCards'

beforeEach(() => {
  clearAll()
  hooks.onLocalChange = null
  hooks.onDeckChange = null
})

describe('XP igual ao app', () => {
  test('sobe de nível ao passar de nível² × 100', () => {
    expect(xpForNextLevel(1)).toBe(100)
    expect(withXp({ xp: 90, level: 1 }, 20)).toEqual({ xp: 110, level: 2 })
    expect(withXp({ xp: 0, level: 1 }, 1000).level).toBe(4) // 100, 400, 900
  })

  test('cartas adicionadas dão 5 XP cada', () => {
    incrementCardsAdded(3)
    expect(getState().profile.statCards).toBe(3)
    expect(getState().profile.xp).toBe(15)
  })

  test('partidas 1, 2 e 4 desbloqueiam banners; a 3 não', () => {
    expect(incrementMatches()).toBe('Bosque Élfico')
    expect(incrementMatches()).toBe('Cascata de Safira')
    expect(incrementMatches()).toBeNull()
    expect(incrementMatches()).toBe('Cripta de Sangue')
    expect(getState().profile.unlockedBanners).toEqual(['0', '1', '2', '3'])
    expect(getState().profile.xp).toBe(200)
  })
})

describe('sincronização', () => {
  test('mudança local avisa a conta; a que vem da conta não volta para ela', () => {
    const changed = []
    hooks.onLocalChange = (k) => changed.push(k)
    updateSection('settings', (s) => ({ ...s, cardLanguage: 'en' }))
    applyRemote({ settings: { cardLanguage: 'pt' }, profile: { xp: 500, level: 3 } })
    expect(changed).toEqual(['settings'])
    expect(getState().settings.cardLanguage).toBe('pt')
    expect(getState().profile.level).toBe(3)
    expect(getState().profile.unlockedBorders).toEqual(['0']) // campos que faltam ficam no padrão
  })

  test('não sobrescreve a parte mudada aqui e ainda não gravada', () => {
    updateSection('settings', (s) => ({ ...s, cardLanguage: 'en' }))
    applyRemote({ settings: { cardLanguage: 'pt' } }, new Set(['settings']))
    expect(getState().settings.cardLanguage).toBe('en')
  })

  test('decks da conta trocam os locais, menos os mudados aqui', () => {
    const events = []
    hooks.onDeckChange = (id, deleted) => events.push([id, deleted])
    saveDeck({ id: '1', name: 'Local', type: 'Normal', cards: [] })
    saveDeck({ id: '2', name: 'Novo aqui', type: 'Normal', cards: [] })
    deleteDeck('1')
    expect(events).toEqual([['1', false], ['2', false], ['1', true]])
    applyRemoteDecks({ 1: { name: 'Na conta', cards: [] }, 3: { name: 'Do app', cards: [] } }, new Set(['1', '2']))
    expect(deckList(getState().decks).map((d) => d.name)).toEqual(['Novo aqui', 'Do app'])
  })
})

test('id do Scryfall da carta de deck, mesmo nos decks antigos', () => {
  const id = '6da045f8-6278-4c84-9d39-025adf0789c1'
  expect(scryfallIdOf({ id })).toBe(id)
  expect(scryfallIdOf({ imageUrl: `https://cards.scryfall.io/normal/front/6/d/${id}.jpg?123` })).toBe(id)
  expect(scryfallIdOf({ name: 'x' })).toBeNull()
})
