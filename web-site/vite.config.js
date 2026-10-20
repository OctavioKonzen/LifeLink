import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Publicado no GitHub Pages (https://octaviokonzen.github.io/<repositório>/).
// Caminho relativo: o site funciona com qualquer nome de repositório (as
// páginas usam o HashRouter, então só os arquivos dependem do caminho).
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
  },
})
