// Sincroniza os dados com a conta (users/{uid} no Firestore) em tempo real e
// nos dois sentidos — a mesma lógica do app (lib/data/account/account_sync.dart):
//   • mudanças da conta (app / outro navegador) chegam na hora;
//   • mudanças feitas aqui gravam só a parte alterada (e só o deck alterado);
//   • ao entrar numa conta, os decks feitos sem conta entram nela, e o perfil
//     que tiver mais XP fica;
//   • ao sair, os dados da conta saem do navegador.

import { deleteAccount as deleteAuthAccount, getAuthState, loadFirestore, onAuthChange, signOut } from './auth'
import { SECTION_KEYS, applyRemote, applyRemoteDecks, clearAll, fromCloud, getState, hooks, toCloud } from './userData'

let uid = null
let session = 0 // muda a cada troca de conta: listen() antigo desiste
let stops = []
let timer = null
let ready = false
let decksReady = false
const dirty = new Set()
// O que a conta tem de cada parte (o último que chegou ou que foi gravado
// daqui), em texto. Uma parte igual a essa não é aplicada de novo: senão,
// qualquer mudança na conta (XP, coleção...) trazia de volta a partida
// guardada, por cima da que está acontecendo (os números pulavam).
const seen = new Map()

/** O valor em texto, com os campos em ordem (o Firestore pode mudar a ordem). */
export function stableText(value) {
  const sorted = (v) =>
    Array.isArray(v) ? v.map(sorted) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sorted(v[k])])) : v
  return JSON.stringify(sorted(value) ?? null)
}

/** Na mesa online a partida vem só da mesa (online.js liga isto). */
export const syncHooks = { gameFromTable: () => false }
const dirtyDecks = new Set()
const deletedDecks = new Set()

function stop() {
  session++
  for (const s of stops) s()
  stops = []
  clearTimeout(timer)
  timer = null
  dirty.clear()
  dirtyDecks.clear()
  seen.clear()
  deletedDecks.clear()
  ready = decksReady = false
}

/** Os dados da conta já chegaram (depois de entrar)? */
export const syncReady = () => uid != null && ready

function scheduleSave() {
  clearTimeout(timer)
  timer = setTimeout(flush, 600)
}

/** No primeiro contato com a conta, fica o perfil com mais XP. */
function keepBestProfile(remote) {
  const localXp = getState().profile?.xp || 0
  const remoteXp = remote.profile && typeof remote.profile === 'object' ? remote.profile.xp || 0 : -1
  if (localXp > remoteXp) dirty.add('profile')
}

async function listen(id) {
  const mine = session
  const { fs, db } = await loadFirestore()
  if (mine !== session) return // saiu (ou trocou de conta) enquanto baixava
  const { collection, doc, onSnapshot } = fs
  const userRef = doc(db, 'users', id)
  stops.push(
    onSnapshot(
      userRef,
      { includeMetadataChanges: false },
      (snap) => {
        // Ignora o "eco" das gravações feitas aqui.
        if (snap.metadata.hasPendingWrites || uid !== id) return
        if (snap.metadata.fromCache && !snap.exists()) return
        const raw = snap.data()?.data
        const remote = fromCloud(raw)
        if (remote && typeof remote === 'object') {
          if (!ready) keepBestProfile(remote)
          // O que foi mudado aqui e ainda não foi gravado tem preferência; o
          // que não mudou na conta fica como está; e na mesa online a
          // partida vem só da mesa.
          const skip = new Set(dirty)
          for (const [k, v] of Object.entries(raw || {})) {
            const text = stableText(v)
            if (seen.get(k) === text) skip.add(k)
            seen.set(k, text)
          }
          if (syncHooks.gameFromTable()) skip.add('game')
          applyRemote(remote, skip)
          for (const k of SECTION_KEYS) if (!(k in remote)) dirty.add(k)
        } else {
          // Conta nova: o que já estava no navegador vai para ela.
          for (const k of SECTION_KEYS) dirty.add(k)
        }
        ready = true
        if (dirty.size) scheduleSave()
      },
      () => {},
    ),
  )
  stops.push(
    onSnapshot(
      collection(userRef, 'decks'),
      (snap) => {
        if (snap.metadata.hasPendingWrites || uid !== id) return
        const remote = {}
        for (const d of snap.docs) remote[d.id] = d.data()
        if (!decksReady) {
          // Primeira vez: decks deste navegador que a conta não tem entram nela.
          for (const deckId of Object.keys(getState().decks)) if (!(deckId in remote)) dirtyDecks.add(deckId)
          decksReady = true
        }
        applyRemoteDecks(remote, new Set([...dirtyDecks, ...deletedDecks]))
        if (dirtyDecks.size || deletedDecks.size) scheduleSave()
      },
      () => {},
    ),
  )
}

export async function flush() {
  clearTimeout(timer)
  timer = null
  if (!uid) return
  const { fs, db } = await loadFirestore()
  const { doc, serverTimestamp, setDoc, writeBatch } = fs
  const userRef = doc(db, 'users', uid)
  if (ready && dirty.size) {
    const keys = [...dirty]
    dirty.clear()
    const state = getState()
    const data = Object.fromEntries(keys.map((k) => [k, toCloud(k, state[k])]))
    try {
      await setDoc(userRef, { data, updatedAt: serverTimestamp() }, { merge: true })
      for (const [k, v] of Object.entries(data)) seen.set(k, stableText(v))
    } catch {
      for (const k of keys) dirty.add(k) // tenta de novo na próxima mudança
    }
  }
  if (decksReady && (dirtyDecks.size || deletedDecks.size)) {
    const saving = [...dirtyDecks]
    const deleting = [...deletedDecks]
    dirtyDecks.clear()
    deletedDecks.clear()
    const decks = getState().decks
    const batch = writeBatch(db)
    for (const id of saving) if (decks[id]) batch.set(doc(userRef, 'decks', id), decks[id])
    for (const id of deleting) batch.delete(doc(userRef, 'decks', id))
    try {
      await batch.commit()
    } catch {
      for (const id of saving) dirtyDecks.add(id)
      for (const id of deleting) deletedDecks.add(id)
    }
  }
}

function onAuth() {
  const { status, user } = getAuthState()
  const next = status === 'signedIn' ? user.uid : null
  if (next === uid) return
  const wasSignedIn = uid != null
  stop()
  uid = next
  if (uid) listen(uid)
  else if (wasSignedIn) clearAll()
}

export function startSync() {
  hooks.onLocalChange = (key) => {
    if (!uid) return
    dirty.add(key)
    if (ready) scheduleSave()
  }
  hooks.onDeckChange = (id, deleted) => {
    if (!uid) return
    if (deleted) {
      dirtyDecks.delete(id)
      deletedDecks.add(id)
    } else {
      deletedDecks.delete(id)
      dirtyDecks.add(id)
    }
    if (decksReady) scheduleSave()
  }
  onAuthChange(onAuth)
  onAuth()
}

/** Sai da conta, salvando antes o que faltava. */
export async function logout() {
  await flush()
  await signOut()
}

/** Exclui a conta e os dados dela. */
export async function deleteAccount() {
  stop() // para não gravar de volta enquanto apaga
  try {
    await deleteAuthAccount()
  } catch (e) {
    uid = null
    onAuth() // não excluiu: volta a sincronizar
    throw e
  }
  clearAll()
}
