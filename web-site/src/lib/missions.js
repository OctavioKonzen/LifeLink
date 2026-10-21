// Missões e cosméticos, com as mesmas regras do app
// (arena_missions_screen.dart e xp_provider.dart): 5 missões por seção, que
// contam só o que foi feito desde o começo da seção (profile.tierStart);
// completar a seção dá uma foto, um contorno ou um título.

import { updateSection } from './userData'
import { withXp } from './xp'

export const BANNERS = [
  ['Planície Central', '#4B4B4B', '#1A1A1A'], ['Bosque Élfico', '#2D5A27', '#0F200B'], ['Cascata de Safira', '#1E4D6B', '#0A1A24'],
  ['Cripta de Sangue', '#6B1E1E', '#240A0A'], ['Pico do Dragão', '#B35F1A', '#3D2009'], ['Vazio Abissal', '#4A1A6B', '#180824'],
  ['Alvorada Dourada', '#B3971A', '#3D3409'], ['Névoa Etérea', '#1A6B62', '#082421'], ['Cidadela de Aço', '#5A6B7A', '#1E2429'],
  ['Horizonte Neon', '#6B1A4D', '#24081A'], ['Aura Mítica', '#B31A1A', '#3D0909'],
].map(([name, a, b], i) => ({ id: String(i), name, colors: [a, b] }))

export const BORDERS = [
  ['Padrão', '#BDBDBD', '#616161'], ['Madeira Rústica', '#8D6E63', '#4E342E'], ['Prata Arcana', '#E0E0E0', '#FFFFFF', '#9E9E9E'],
  ['Ouro de Ravnica', '#FFC107', '#FFEB3B', '#FFA000'], ['Mítico Sangrento', '#FF5722', '#F44336', '#FFAB40'],
  ['Mana Fluente', '#FFFFFF', '#2196F3', '#222222', '#F44336', '#4CAF50'], ['Gelo Eterno', '#18FFFF', '#03A9F4', '#FFFFFF'],
  ['Fogo Caótico', '#FF5252', '#FF9800', '#FFFF00'], ['Corrupção Phyrexiana', '#69F0AE', '#222222', '#1B5E20'],
  ['Vazio Cósmico', '#673AB7', '#000000', '#E040FB'], ['Neon Kamigawa', '#FF4081', '#18FFFF', '#FFFF00'],
  ['Eternidade Divina', '#FFEB3B', '#FFFFFF', '#FFD740'],
].map(([name, ...colors], i) => ({ id: String(i), name, colors }))

export const TITLES = [
  'Novato do Mesão', 'Mago de Batalha', 'Colecionador de Relíquias', 'Estrategista Astuto', 'Andarilho dos Planos', 'Mestre das Fichas',
  'Senhor dos Zumbis', 'Conjurador de Feitiços', 'Comandante Lendário', 'Arquiteto de Decks', 'Arauto da Destruição', 'Guardião da Luz',
  'Manipulador do Tempo', 'Forjador de Artefatos', 'Voz dos Pretores', 'Campeão de Ravnica', 'Ilusionista Nato', 'Domador de Dragões',
  'Sobrevivente do Apocalipse', 'Deus do Magic',
]

const TOP_CARDS = [
  'Sol Ring', 'Black Lotus', 'Jace, the Mind Sculptor', 'Liliana of the Veil', 'Elesh Norn, Grand Cenobite', "Atraxa, Praetors' Voice",
  'Nicol Bolas, the Ravager', 'Chandra, Torch of Defiance', 'Teferi, Hero of Dominaria', 'Ulamog, the Ceaseless Hunger', 'Karn Liberated',
  'Muldrotha, the Gravetide', "Yuriko, the Tiger's Shadow", 'Edgar Markov', 'Rhystic Study', 'Smothering Tithe', 'Cyclonic Rift',
  'Doubling Season', 'Ghalta, Primal Hunger', 'Avacyn, Angel of Hope',
]

export const artCropByName = (name) => `https://api.scryfall.com/cards/named?exact=${encodeURIComponent(name)}&format=image&version=art_crop`

/** A recompensa de completar a seção (a mesma conta do app). */
export function tierReward(tier) {
  const titleTier = tier % 10 === 0
  const borderTier = !titleTier && tier % 2 === 0
  if (titleTier) {
    const title = TITLES[tier / 10 - 1]
    if (title) return { type: 'title', value: title, name: title }
  } else if (borderTier) {
    const border = BORDERS[Math.floor(tier / 2) - Math.floor(tier / 10)]
    if (border) return { type: 'border', value: border.id, name: border.name, colors: border.colors }
  }
  const card = TOP_CARDS[(tier - 1) % TOP_CARDS.length]
  return { type: 'avatar', value: artCropByName(card), name: card, imageUrl: artCropByName(card) }
}

const ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
const STATS = { decks: 'statDecks', cards: 'statCards', searches: 'statSearches', arts: 'statArts' }

const startOf = (p) => p.tierStart || (p.tier > 1 ? Object.fromEntries(Object.entries(STATS).map(([k, s]) => [k, p[s] || 0])) : { decks: 0, cards: 0, searches: 0, arts: 0 })
const since = (p, stat) => Math.max(0, (p[STATS[stat]] || 0) - (startOf(p)[stat] || 0))

/** As 5 missões da seção atual. deckCount: quantos decks a pessoa tem. */
export function missionsFor(profile, deckCount) {
  const tier = profile.tier || 1
  const mult = 1 + 0.5 * (tier - 1)
  const title = (titles) => {
    if (tier <= titles.length) return titles[tier - 1]
    const n = tier - titles.length + 1
    return `${titles.at(-1)} ${ROMAN[n] ?? n}`
  }
  return [
    { title: title(['Construtor Aprendiz', 'Mestre Forjador']), desc: 'Crie decks novos nesta seção.', icon: '🛠', target: Math.ceil(3 * mult), current: since(profile, 'decks'), xp: 100 * tier },
    { title: title(['O Colecionador', 'Acumulador']), desc: 'Adicione cartas aos decks nesta seção.', icon: '📚', target: Math.ceil(60 * mult), current: since(profile, 'cards'), xp: 150 * tier },
    { title: title(['Arquimago', 'Lenda']), desc: 'Tenha decks na biblioteca.', icon: '✨', target: 4 + tier, current: deckCount, xp: 200 * tier },
    { title: title(['Explorador', 'Viajante']), desc: 'Pesquise cartas nesta seção.', icon: '🧭', target: Math.ceil(30 * mult), current: since(profile, 'searches'), xp: 100 * tier },
    { title: title(['Estrategista', 'Erudito']), desc: 'Veja outras artes de cartas nesta seção.', icon: '🎨', target: Math.ceil(15 * mult), current: since(profile, 'arts'), xp: 150 * tier },
  ]
}

const claimed = (p) => Array.from({ length: 5 }, (_, i) => p.claimedMissions?.[i] ?? '0')

export function claimMission(index, xp) {
  updateSection('profile', (p) => {
    const list = claimed(p)
    if (list[index] === '1') return p
    list[index] = '1'
    return withXp({ ...p, claimedMissions: list }, xp)
  })
}

/** Resgata a recompensa da seção e vai para a próxima (zerando as missões). */
export function claimSection() {
  updateSection('profile', (p) => {
    const tier = p.tier || 1
    const reward = tierReward(tier)
    const next = { ...p }
    if (reward.type === 'avatar' && !(p.unlockedAvatars || []).includes(reward.value)) next.unlockedAvatars = [...(p.unlockedAvatars || []), reward.value]
    if (reward.type === 'border' && !(p.unlockedBorders || []).includes(reward.value)) next.unlockedBorders = [...(p.unlockedBorders || []), reward.value]
    if (reward.type === 'title' && !(p.unlockedTitles || []).includes(reward.value)) {
      next.unlockedTitles = [...(p.unlockedTitles || []), reward.value]
      if (!p.selectedTitle) next.selectedTitle = reward.value
    }
    next.tier = tier + 1
    next.claimedMissions = ['0', '0', '0', '0', '0']
    next.tierStart = Object.fromEntries(Object.entries(STATS).map(([k, s]) => [k, p[s] || 0]))
    return next
  })
}

export const isClaimed = (profile, i) => claimed(profile)[i] === '1'

export const select = (field, value) => updateSection('profile', (p) => ({ ...p, [field]: value }))
