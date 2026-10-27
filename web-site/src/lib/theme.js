// O tema (cor de fundo) do site: o mesmo do app (Configurações → Cor de fundo),
// guardado na conta em settings.bgColor. Sem conta, fica neste navegador (o
// userData guarda localmente). O padrão é a noite azul do redesign.

import { getState, updateSection, useUserData } from './userData'

// As mesmas cores do app (theme_provider.dart → availableColors).
export const THEMES = [
  { id: 'rosa', name: 'Rosa', color: '#F8BBD0', argb: 0xfff8bbd0 },
  { id: 'azul', name: 'Azul', color: '#B3E5FC', argb: 0xffb3e5fc },
  { id: 'verde', name: 'Verde', color: '#C8E6C9', argb: 0xffc8e6c9 },
  { id: 'dark', name: 'Noite', color: '#0A0D17', argb: 0xff0a0d17 },
  { id: 'light', name: 'Branco', color: '#F5F5F5', argb: 0xfff5f5f5 },
]

/** O tema de uma cor salva (o preto antigo e qualquer outra viram a noite). */
export function themeOf(argb) {
  return THEMES.find((t) => t.argb === Number(argb))?.id || 'dark'
}

export function applyTheme(id = themeOf(getState().settings?.bgColor)) {
  document.documentElement.dataset.theme = id
}

export function setTheme(id) {
  const theme = THEMES.find((t) => t.id === id) || THEMES[3]
  updateSection('settings', (s) => ({ ...s, bgColor: theme.argb }))
  applyTheme(theme.id)
}

/** O tema atual (muda junto quando o app troca a cor na mesma conta). */
export function useTheme() {
  return themeOf(useUserData((s) => s.settings?.bgColor))
}
