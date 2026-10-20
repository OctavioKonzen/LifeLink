// Configuração do Firebase do Magic (Console do Firebase → Configurações do
// projeto → Seus apps → app da Web). Esses valores não são segredo: vão no
// site publicado de qualquer jeito. Quem protege os dados são as regras do
// Firestore (firestore.rules). Dá para trocar por variáveis de ambiente
// VITE_FIREBASE_* no build.
//
// Vazio = o site funciona normalmente, só que sem login.

const env = import.meta.env || {}

export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY || '',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN || '',
  projectId: env.VITE_FIREBASE_PROJECT_ID || '',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: env.VITE_FIREBASE_APP_ID || '',
}

export const isConfigured = Boolean(firebaseConfig.apiKey && firebaseConfig.projectId)
