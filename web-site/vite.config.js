import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Publicado em https://octaviokonzen.github.io/Magic/
export default defineConfig({
  base: '/Magic/',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
  },
})
