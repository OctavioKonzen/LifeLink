// A mesa online e os amigos no site (o formato e as operações ficam em
// onlineCore.js; aqui o estado da tela e a ligação com a partida).

import { useSyncExternalStore } from 'react'
import { getAuthState, loadFirestore } from './auth'
import { defaultGame, fromCloud, getState, onLocalChange, toCloud, updateSection } from './userData'
import * as core from './onlineCore'

let state = { code: null, isOwner: false, error: null }
const listeners = new Set()
const set = (next) => {
  state = { ...state, ...next }
  for (const l of listeners) l()
}
export function useOnlineTable() {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l)
      return () => listeners.delete(l)
    },
    () => state,
  )
}

const me = () => {
  const { status, user } = getAuthState()
  if (status !== 'signedIn' || !user) throw new Error('Entre na conta para usar a mesa online e os amigos.')
  return { uid: user.uid, nick: user.name || '' }
}

// Sem internet, o Firestore espera para sempre: aqui desiste em 15 s.
const net = (promise) =>
  Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error('Sem conexão com a internet. Tente de novo.')), 15000))])

let stops = []
let last = {}
let applying = false
let timer = null

function attach(fs, db, code, flat) {
  last = flat
  stops.push(
    fs.onSnapshot(
      fs.doc(db, 'tables', code),
      (snap) => {
        if (snap.metadata.hasPendingWrites) return
        if (!snap.exists()) {
          leaveTable(`A mesa ${code} foi fechada.`)
          return
        }
        const game = core.unflattenGame(snap.data())
        last = core.flattenGame(game)
        applying = true
        try {
          updateSection('game', () => ({ ...defaultGame(), ...fromCloud({ game }).game }))
        } finally {
          applying = false
        }
      },
      () => leaveTable('Sem acesso à mesa (as regras do banco estão publicadas?).'),
    ),
  )
  stops.push(
    onLocalChange((key) => {
      if (key !== 'game' || applying) return
      clearTimeout(timer)
      timer = setTimeout(() => {
        const flat = core.flattenGame(toCloud('game', getState().game))
        const changes = core.changedFields(last, flat)
        if (!Object.keys(changes).length) return
        last = flat
        core.pushChanges(fs, db, code, changes).catch(() => {})
      }, 150)
    }),
  )
}

export async function createTable() {
  const user = me()
  await leaveTable()
  const { fs, db } = await loadFirestore()
  const { code, flat } = await net(core.createTable(fs, db, user, toCloud('game', getState().game)))
  set({ code, isOwner: true, error: null })
  attach(fs, db, code, flat)
  return code
}

export async function joinTable(rawCode) {
  const user = me()
  await leaveTable()
  const { fs, db } = await loadFirestore()
  const { code, data } = await net(core.findTable(fs, db, rawCode))
  set({ code, isOwner: data.owner === user.uid, error: null })
  attach(fs, db, code, {})
}

/** Sai da mesa (o dono fecha a mesa para todos). */
export async function leaveTable(reason = null) {
  const { code, isOwner } = state
  for (const s of stops) s()
  stops = []
  clearTimeout(timer)
  set({ code: null, isOwner: false, error: reason })
  if (code && isOwner && !reason) {
    const { fs, db } = await loadFirestore()
    await fs.deleteDoc(fs.doc(db, 'tables', code)).catch(() => {})
  }
}

// ---------------------------------------------------------------- amigos

async function withDb(fn) {
  const user = me()
  const { fs, db } = await loadFirestore()
  return net(fn(fs, db, user))
}

export const addFriend = (nick) => withDb((fs, db, user) => core.addFriend(fs, db, user, nick))
export const acceptFriend = (r) => withDb((fs, db, user) => core.acceptFriend(fs, db, user, r))
export const declineFriend = (r) => withDb((fs, db, user) => core.declineFriend(fs, db, user, r))
export const removeFriend = (f) => withDb((fs, db, user) => core.removeFriend(fs, db, user, f))
export const friendDecks = (f) => withDb((fs, db) => core.decksOf(fs, db, f.uid))
export const inviteFriend = (f, code) => withDb((fs, db, user) => core.inviteFriend(fs, db, user, f, code))
export const dismissInvite = (code) => withDb((fs, db, user) => core.dismissInvite(fs, db, user, code))

/** Acompanha uma lista (friends, requests ou invites) do usuário; volta a função para parar. */
export function watchList(name, onChange, onError) {
  let stop = () => {}
  let alive = true
  withDb((fs, db, user) => {
    if (!alive) return
    stop = fs.onSnapshot(
      fs.collection(db, 'users', user.uid, name),
      async (snap) => {
        let list = snap.docs.map((d) => ({ ...d.data(), uid: d.data().uid ?? d.id, id: d.id }))
        if (name === 'friends') list = await Promise.all(list.map(async (f) => ({ ...f, accepted: await core.isAccepted(fs, db, user, f.uid) })))
        if (alive) onChange(list.sort((a, b) => String(a.nick ?? a.fromNick).localeCompare(String(b.nick ?? b.fromNick))))
      },
      (e) => onError?.(e),
    )
  }).catch((e) => onError?.(e))
  return () => {
    alive = false
    stop()
  }
}

export function messageOf(e) {
  const text = e?.message || String(e)
  if (e?.code === 'permission-denied' || text.includes('permission')) return 'O servidor recusou. As regras do banco (firestore.rules) precisam ser publicadas de novo no Firebase.'
  return text
}
