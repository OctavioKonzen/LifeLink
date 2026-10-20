// Configuração do Firebase do LifeLink (projeto lifelink-ad40f) (Console do Firebase → Configurações do
// projeto → Seus apps → app da Web). Esses valores não são segredo: vão no
// site publicado de qualquer jeito. Quem protege os dados são as regras do
// Firestore (firestore.rules). Dá para trocar por variáveis de ambiente
// VITE_FIREBASE_* no build.
//
// Sem ela, o site funcionaria normalmente, só que sem login.

const env = import.meta.env || {}

export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY || 'AIzaSyCKX2QD4iO6-KIVF8SK0ogOh8fvBfKhAIQ',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN || 'lifelink-ad40f.firebaseapp.com',
  projectId: env.VITE_FIREBASE_PROJECT_ID || 'lifelink-ad40f',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET || 'lifelink-ad40f.firebasestorage.app',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID || '807040389217',
  appId: env.VITE_FIREBASE_APP_ID || '1:807040389217:web:484dad10e34779d1c95a20',
}

export const isConfigured = Boolean(firebaseConfig.apiKey && firebaseConfig.projectId)
