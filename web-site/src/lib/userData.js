// Os dados da pessoa, no mesmo formato do app (lib/data/account/user_data.dart):
//   settings: { bgColor, playerName, cardLanguage }
//   profile:  { xp, level, tier, claimedMissions, unlocked*, selected*,
//               totalMatches, statDecks, statCards, statSearches, statArts }
//   game:     { playerCount, startingLife, lives, poison, commanderDamage, playerNames }
//   matches:  { list: [partidas terminadas] } (matches.js)
//   collection, wishlist: { list: [cartas] } (collection.js)
//   decks:    { [id]: { id, name, type, cards } }
// Sem conta, ficam só neste navegador. Com conta, sync.js leva para o
// Firestore e traz o que mudou no app.

import { useSyncExternalStore } from 'react'

export const SECTION_KEYS = ['settings', 'profile', 'game', 'matches', 'collection', 'wishlist']
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
  // Dano do 2º comandante (parceiro) de cada um, contado à parte.
  partnerDamage: Array.from({ length: 6 }, () => Array(6).fill(0)),
  playerNames: playerNames || Array.from({ length: 6 }, (_, i) => `Jogador ${i + 1}`),
})

export const defaultSettings = () => ({ bgColor: 0xff1e1e24, playerName: 'Jogador 1', cardLanguage: 'pt' })

const defaults = () => ({ settings: defaultSettings(), profile: defaultProfile(), game: defaultGame(), matches: { list: [] }, collection: { list: [] }, wishlist: { list: [] }, decks: {} })

// O Firestore não aceita lista dentro de lista: na conta, o dano de
// comandante vai como cmdRows (uma linha de texto por jogador), como no app.
export function toCloud(key, value) {
  if (key !== 'game' || !value) return value
  const { commanderDamage, partnerDamage, ...rest } = value
  const rows = (m) => (m || []).map((row) => row.join(','))
  return { ...rest, cmdRows: rows(commanderDamage), cmdRows2: rows(partnerDamage) }
}

export function fromCloud(data) {
  const game = data?.game
  if (!game || !Array.isArray(game.cmdRows)) return data
  const { cmdRows, cmdRows2, ...rest } = game
  const matrix = (list) => {
    const rows = (list || []).map((r) => String(r).split(',').filter(Boolean).map((v) => Number(v) || 0))
    return Array.from({ length: 6 }, (_, i) => Array.from({ length: 6 }, (_, j) => rows[i]?.[j] ?? 0))
  }
  return { ...data, game: { ...rest, commanderDamage: matrix(cmdRows), partnerDamage: matrix(cmdRows2) } }
}

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
  if (!applyingRemote) {
    hooks.onLocalChange?.(key)
    for (const listener of localListeners) listener(key)
  }
}

// Outros interessados nas mudanças feitas aqui (a mesa online).
const localListeners = new Set()
export function onLocalChange(listener) {
  localListeners.add(listener)
  return () => localListeners.delete(listener)
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
