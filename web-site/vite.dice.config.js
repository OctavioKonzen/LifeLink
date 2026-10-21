import { defineConfig } from 'vite'

// Gera a mesa de dados 3D para o app: um script só (sem módulos, para abrir
// de dentro do APK), em ../assets/dice/dice.js. Rodar: npm run build:dice
export default defineConfig({
  build: {
    outDir: '../assets/dice',
    emptyOutDir: false,
    copyPublicDir: false,
    lib: {
      entry: 'src/dice3d/standalone.js',
      name: 'LifeLinkDiceBundle',
      formats: ['iife'],
      fileName: () => 'dice.js',
    },
  },
})
