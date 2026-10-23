// Tema claro/escuro do site, guardado neste navegador (o escuro é o padrão).

import { useSyncExternalStore } from 'react'

const KEY = 'lifelink_theme'
const listeners = new Set()

function read() {
  try {
    const saved = localStorage.getItem(KEY)
    if (saved === 'light' || saved === 'dark') return saved
  } catch {
    // Armazenamento bloqueado: segue o aparelho.
  }
  return 'dark' // o redesign é escuro; o claro fica no botão
}

let theme = typeof window === 'undefined' ? 'dark' : read()

export function applyTheme() {
  document.documentElement.dataset.theme = theme
}

export function setTheme(next) {
  theme = next
  try {
    localStorage.setItem(KEY, next)
  } catch {
    // Só não fica salvo.
  }
  applyTheme()
  for (const l of listeners) l()
}

export function useTheme() {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l)
      return () => listeners.delete(l)
    },
    () => theme,
  )
}
