// Os dados da pessoa, no mesmo formato do app (lib/data/account/user_data.dart):
//   settings: { bgColor, playerName, cardLanguage }
//   profile:  { xp, level, tier, claimedMissions, unlocked*, selected*,
//               totalMatches, statDecks, statCards, statSearches, statArts }
//   game:     { playerCount, startingLife, lives, poison, commanderDamage, playerNames }
//   decks:    { [id]: { id, name, type, cards } }
// Sem conta, ficam só neste navegador. Com conta, sync.js leva para o
// Firestore e traz o que mudou no app.

import { useSyncExternalStore } from 'react'

export const SECTION_KEYS = ['settings', 'profile', 'game']
const STORAGE_KEY = 'magic_user_data_v1'

export const defaultProfile = () => ({
  xp: 0,
  level: 1,
  tier: 1,
  claimedMissions: ['0', '0', '0', '0', '0'],
  unlockedAvatars: [],
  unlockedBorders: ['0'],
  unlockedTitles: [],
  unlockedBanners: ['0'],
  selectedAvatar: '',
  selectedBorder: '0',
  selectedTitle: '',
  selectedBanner: '0',
  totalMatches: 0,
  statDecks: 0,
  statCards: 0,
  statSearches: 0,
  statArts: 0,
})

export const defaultGame = (startingLife = 40, playerCount = 2, playerNames) => ({
  playerCount,
  startingLife,
  lives: Array(6).fill(startingLife),
  poison: Array(6).fill(0),
  energy: Array(6).fill(0),
  experience: Array(6).fill(0),
  tax: Array(6).fill(0),
  treasure: Array(6).fill(0),
  storm: Array(6).fill(0),
  blessing: Array(6).fill(0),
  monarch: -1,
  initiative: -1,
  // Turnos: de quem é a vez (-1 = sem contar), quem começou, a rodada, quando
  // a vez começou (ms) e o tempo de cada um. Planechase/Archenemy: a carta virada.
  turnPlayer: -1,
  turnFirst: 0,
  turnRound: 1,
  turnStartedAt: 0,
  turnTotals: Array(6).fill(0),
  plane: null,
  scheme: null,
  commanderDamage: Array.from({ length: 6 }, () => Array(6).fill(0)),
  playerNames: playerNames || Array.from({ length: 6 }, (_, i) => `Player ${i + 1}`),
})

export const defaultSettings = () => ({ bgColor: 0xff1e1e24, playerName: 'Player 1', cardLanguage: 'pt' })

const defaults = () => ({ settings: defaultSettings(), profile: defaultProfile(), game: defaultGame(), decks: {} })

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY))
    if (saved && typeof saved === 'object') return { ...defaults(), ...saved }
  } catch {
    // Sem dados salvos ou armazenamento bloqueado.
  }
  return defaults()
}

let state = load()
const listeners = new Set()
let applyingRemote = false

/** Avisado quando algo muda aqui (sync.js grava na conta). */
export const hooks = {
  onLocalChange: null, // (key) => void
  onDeckChange: null, // (id, deleted) => void
}

function persist() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  } catch {
    // Navegação privada: só não fica salvo.
  }
  for (const l of listeners) l()
}

export const getState = () => state

export function subscribe(listener) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function useUserData(select = (s) => s) {
  return select(useSyncExternalStore(subscribe, getState))
}

/** Muda uma parte (settings, profile ou game). */
export function updateSection(key, update) {
  const value = typeof update === 'function' ? update(state[key]) : update
  state = { ...state, [key]: value }
  persist()
  if (!applyingRemote) hooks.onLocalChange?.(key)
}

export function saveDeck(deck) {
  state = { ...state, decks: { ...state.decks, [deck.id]: deck } }
  persist()
  if (!applyingRemote) hooks.onDeckChange?.(deck.id, false)
}

export function deleteDeck(id) {
  const decks = { ...state.decks }
  delete decks[id]
  state = { ...state, decks }
  persist()
  if (!applyingRemote) hooks.onDeckChange?.(id, true)
}

/** Decks em ordem de criação (o id é a hora em que foi criado, como no app). */
export const deckList = (decks) => Object.values(decks).sort((a, b) => String(a.id).localeCompare(String(b.id)))

// --------------------------------------------------------- vindo da conta

export function applyRemote(data, except = new Set()) {
  applyingRemote = true
  try {
    const next = { ...state }
    for (const key of SECTION_KEYS) {
      if (except.has(key) || !(key in data)) continue
      const fallback = defaults()[key]
      next[key] = data[key] && typeof data[key] === 'object' ? { ...fallback, ...data[key] } : fallback
    }
    state = next
    persist()
  } finally {
    applyingRemote = false
  }
}

/** Troca os decks pelos da conta, mantendo os de keep (mudados aqui e ainda não gravados). */
export function applyRemoteDecks(remote, keep = new Set()) {
  const decks = {}
  for (const [id, deck] of Object.entries(remote)) if (!keep.has(id)) decks[id] = { ...deck, id }
  for (const id of keep) if (state.decks[id]) decks[id] = state.decks[id]
  state = { ...state, decks }
  persist()
}

/** Saiu da conta: os dados dela não ficam no navegador. */
export function clearAll() {
  state = defaults()
  persist()
}
