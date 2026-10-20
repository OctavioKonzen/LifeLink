import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { startAuth } from './lib/auth'
import { startSync } from './lib/sync'

// Conta (a mesma do app). Sem a configuração do Firebase, o site funciona
// normalmente, só que sem login.
startAuth()
startSync()

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
