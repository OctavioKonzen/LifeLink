// XP e nível, com as mesmas regras do app (lib/data/providers/xp_provider.dart).

import { updateSection } from './userData'

export const xpForNextLevel = (level) => level * level * 100

export function withXp(profile, amount) {
  let { xp, level } = profile
  xp += amount
  while (xp >= xpForNextLevel(level)) level++
  return { ...profile, xp, level }
}

const bump = (stat, xpAmount, count = 1) =>
  updateSection('profile', (p) => withXp({ ...p, [stat]: (p[stat] || 0) + count }, xpAmount))

export const incrementDecksCreated = () => bump('statDecks', 100)
export const incrementCardsAdded = (amount) => bump('statCards', 5 * amount, amount)
export const incrementSearches = () => bump('statSearches', 5)
export const incrementArtsViewed = () => bump('statArts', 10)

// Mesmos nomes do app, para o banner novo que a partida desbloqueia.
export const BANNERS = [
  'Planície Central', 'Bosque Élfico', 'Cascata de Safira', 'Cripta de Sangue', 'Pico do Dragão', 'Vazio Abissal',
  'Alvorada Dourada', 'Névoa Etérea', 'Cidadela de Aço', 'Horizonte Neon', 'Aura Mítica',
]

/** Fim de partida no contador: +50 XP e, nas partidas 1, 2, 4, 8..., um banner novo. Devolve o nome dele. */
export function incrementMatches() {
  let unlocked = null
  updateSection('profile', (p) => {
    const total = (p.totalMatches || 0) + 1
    const next = withXp({ ...p, totalMatches: total }, 50)
    if ((total & (total - 1)) === 0) {
      const index = next.unlockedBanners.length
      if (index < BANNERS.length && !next.unlockedBanners.includes(String(index))) {
        next.unlockedBanners = [...next.unlockedBanners, String(index)]
        unlocked = BANNERS[index]
      }
    }
    return next
  })
  return unlocked
}
