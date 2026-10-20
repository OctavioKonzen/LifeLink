// Login com Firebase — a MESMA conta do app (lib/data/account/auth_service.dart):
// e-mail e senha ou Google.
//   users/{uid}          → { name, email, data, ... }
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
import { getFirestore, doc, setDoc, serverTimestamp, collection, getDocs, deleteDoc } from 'firebase/firestore'
import { firebaseConfig, isConfigured } from './firebaseConfig'

let auth = null
let db = null
let state = { status: isConfigured ? 'loading' : 'disabled', user: null }
const listeners = new Set()

function set(next) {
  state = next
  for (const l of listeners) l()
}

export function getDb() {
  return db
}

export function startAuth() {
  if (!isConfigured || auth) return
  const app = initializeApp(firebaseConfig)
  auth = getAuth(app)
  db = getFirestore(app)
  onAuthStateChanged(auth, (u) => {
    if (!u) {
      set({ status: 'signedOut', user: null })
      return
    }
    set({ status: 'signedIn', user: { uid: u.uid, email: u.email, name: u.displayName, photo: u.photoURL } })
    saveProfile(u)
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

function saveProfile(u, name) {
  setDoc(
    doc(db, 'users', u.uid),
    { name: name || u.displayName || u.email?.split('@')[0] || 'Jogador', email: u.email || '', lastLogin: serverTimestamp() },
    { merge: true },
  ).catch(() => {})
}

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
    if (name.trim().length < 2) throw new Error('Escolha um nome com pelo menos 2 letras.')
    const { user } = await createUserWithEmailAndPassword(auth, email.trim(), password)
    await updateProfile(user, { displayName: name.trim() })
    saveProfile(user, name.trim())
    set({ status: 'signedIn', user: { uid: user.uid, email: user.email, name: name.trim(), photo: null } })
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
    const decks = await getDocs(collection(db, 'users', u.uid, 'decks'))
    for (const d of decks.docs) await deleteDoc(d.ref)
    await deleteDoc(doc(db, 'users', u.uid))
    await deleteUser(u)
  })
