import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import '@fontsource/roboto/900.css'
import './index.css'
import App from './App.jsx'
import { startAuth } from './lib/auth'
import { startSync } from './lib/sync'
import { startTradePublish } from './lib/online'
import { applyTheme } from './lib/theme'

// Conta (a mesma do app). Sem a configuração do Firebase, o site funciona
// normalmente, só que sem login.
applyTheme()
startAuth()
startSync()
// A lista de troca e de desejos vai para os amigos verem (online.js).
startTradePublish()

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
