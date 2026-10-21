// Login com Firebase — a MESMA conta do app (lib/data/account/auth_service.dart):
// e-mail e senha ou Google. Toda conta tem um nick; quem entra com Google
// pela primeira vez escolhe o nick antes de entrar (status 'needsNick').
//   users/{uid}          → { nick, name, email, data, ... }
//   users/{uid}/decks/*  → um documento por deck

import { useSyncExternalStore } from 'react'
import { initializeApp } from 'firebase/app'
import {
  GoogleAuthProvider,
  createUserWithEmailAndPassword,
  deleteUser,
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as fbSignOut,
  updateProfile,
} from 'firebase/auth'
import { firebaseConfig, isConfigured } from './firebaseConfig'

let app = null
let auth = null
let creatingNick = null // nick de quem está criando a conta agora
let state = { status: isConfigured ? 'loading' : 'disabled', user: null }
const listeners = new Set()

function set(next) {
  state = next
  for (const l of listeners) l()
}

/** O Firestore, baixado à parte (ver firestore.js). */
export async function loadFirestore() {
  const fs = await import('./firestore')
  return { fs, db: fs.getDb(app) }
}

export function startAuth() {
  if (!isConfigured || auth) return
  app = initializeApp(firebaseConfig)
  auth = getAuth(app)
  onAuthStateChanged(auth, async (u) => {
    if (!u) {
      set({ status: 'signedOut', user: null })
      return
    }
    // Conta criada agora com e-mail: o nick veio do formulário.
    const nick = creatingNick ?? (await nickOf(u))
    if (auth.currentUser?.uid !== u.uid) return // saiu enquanto lia
    const user = { uid: u.uid, email: u.email, name: nick ?? u.displayName, photo: u.photoURL }
    if (!nick) {
      set({ status: 'needsNick', user })
      return
    }
    set({ status: 'signedIn', user })
    saveProfile(u, nick)
  })
}

export function useAuth() {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l)
      return () => listeners.delete(l)
    },
    () => state,
  )
}

export const getAuthState = () => state

export function onAuthChange(listener) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function saveProfile(u, nick) {
  return import('./firestore').then((fs) => fs.saveProfile(app, u, nick)).catch(() => {})
}

/** O nick da conta (null se ainda não escolheu). Sem internet, entra com o nome do Google. */
async function nickOf(u) {
  const fallback = u.displayName || u.email?.split('@')[0] || 'Jogador'
  try {
    const fs = await import('./firestore')
    return await Promise.race([fs.readNick(app, u.uid), new Promise((resolve) => setTimeout(() => resolve(fallback), 8000))])
  } catch {
    return fallback
  }
}

/** Valida o nick: de 3 a 20 letras, números, espaço, _ ou -. */
export function nickError(nick) {
  const n = nick.trim()
  if (n.length < 3) return 'O nick precisa ter pelo menos 3 letras.'
  if (n.length > 20) return 'O nick pode ter no máximo 20 letras.'
  if (!/^[\p{L}\p{N} _-]+$/u.test(n)) return 'Use só letras, números, espaço, _ ou -.'
  return null
}

/** Salva o nick (depois de entrar com Google) e entra no site. */
export const setNick = (nick) =>
  guard(async () => {
    const error = nickError(nick)
    if (error) throw new Error(error)
    const u = auth.currentUser
    if (!u) return
    const fs = await import('./firestore')
    await fs.claimNick(app, u.uid, nick.trim())
    await updateProfile(u, { displayName: nick.trim() })
    set({ status: 'signedIn', user: { uid: u.uid, email: u.email, name: nick.trim(), photo: u.photoURL } })
  })

/** Troca o nick (com conta): o novo precisa estar livre; o antigo fica livre para outros. */
export const changeNick = (nick) =>
  guard(async () => {
    const error = nickError(nick)
    if (error) throw new Error(error)
    const u = auth.currentUser
    if (!u) throw new Error('Entre na conta para trocar o nick.')
    const fs = await import('./firestore')
    await fs.changeNick(app, u.uid, nick.trim())
    await updateProfile(u, { displayName: nick.trim() })
    set({ status: 'signedIn', user: { ...state.user, name: nick.trim() } })
  })

const MESSAGES = {
  'auth/invalid-email': 'E-mail inválido.',
  'auth/user-disabled': 'Esta conta foi desativada.',
  'auth/user-not-found': 'E-mail ou senha incorretos.',
  'auth/wrong-password': 'E-mail ou senha incorretos.',
  'auth/invalid-credential': 'E-mail ou senha incorretos.',
  'auth/email-already-in-use': 'Já existe uma conta com este e-mail. Use "Entrar".',
  'auth/weak-password': 'A senha precisa ter pelo menos 6 caracteres.',
  'auth/too-many-requests': 'Muitas tentativas. Espere um pouco e tente de novo.',
  'auth/network-request-failed': 'Sem conexão com a internet.',
  'auth/popup-closed-by-user': 'O login com Google foi cancelado.',
  'auth/cancelled-popup-request': 'O login com Google foi cancelado.',
  'auth/popup-blocked': 'O navegador bloqueou a janela do Google. Permita pop-ups para este site.',
  'auth/unauthorized-domain': 'Este endereço do site ainda não foi autorizado no Firebase (Authentication → Configurações → Domínios autorizados).',
  'auth/requires-recent-login': 'Por segurança, saia e entre de novo na conta antes de excluir.',
  'auth/account-exists-with-different-credential': 'Este e-mail já tem conta com outra forma de login (e-mail e senha ou Google).',
}

async function guard(action) {
  try {
    return await action()
  } catch (e) {
    throw new Error(MESSAGES[e.code] || e.message || 'Não foi possível concluir.')
  }
}

export const signIn = (email, password) => guard(() => signInWithEmailAndPassword(auth, email.trim(), password))

export const signUp = (name, email, password) =>
  guard(async () => {
    const error = nickError(name)
    if (error) throw new Error(error)
    const nick = name.trim()
    const fs = await import('./firestore')
    // Confere antes de criar a conta, para não criar com um nick repetido.
    if (!(await fs.isNickFree(app, nick))) throw new Error(fs.NICK_TAKEN)
    creatingNick = nick
    try {
      const { user } = await createUserWithEmailAndPassword(auth, email.trim(), password)
      try {
        await fs.claimNick(app, user.uid, nick)
      } catch {
        // Alguém pegou o nick nesse meio tempo: a conta já existe, então pede
        // outro nick (como no login com Google).
        creatingNick = null
        set({ status: 'needsNick', user: { uid: user.uid, email: user.email, name: null, photo: user.photoURL } })
        throw new Error(fs.NICK_TAKEN)
      }
      await updateProfile(user, { displayName: nick })
    } finally {
      creatingNick = null
    }
  })

export const signInWithGoogle = () =>
  guard(() => {
    const provider = new GoogleAuthProvider()
    provider.setCustomParameters({ prompt: 'select_account' })
    return signInWithPopup(auth, provider)
  })

export const resetPassword = (email) => guard(() => sendPasswordResetEmail(auth, email.trim()))

export const signOut = () => fbSignOut(auth)

/** Apaga os decks, o perfil e a conta. */
export const deleteAccount = () =>
  guard(async () => {
    const u = auth.currentUser
    if (!u) return
    // O Firebase só exclui a conta logo depois de entrar: confere antes de
    // apagar os dados, para não ficar com a conta sem dados.
    const last = Date.parse(u.metadata.lastSignInTime || '')
    if (!last || Date.now() - last > 4 * 60 * 1000) throw new Error(MESSAGES['auth/requires-recent-login'])
    const fs = await import('./firestore')
    await fs.deleteUserData(app, u.uid)
    await deleteUser(u)
  })
