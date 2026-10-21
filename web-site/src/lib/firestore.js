// O Firestore (o banco de dados da conta) é a maior parte do Firebase: fica
// neste arquivo separado, baixado só depois que a tela já apareceu.

import { collection, deleteDoc, doc, getDoc, getDocs, getFirestore, onSnapshot, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore'

export { collection, doc, onSnapshot, serverTimestamp, setDoc, writeBatch }

let db = null

export function getDb(app) {
  db ??= getFirestore(app)
  return db
}

export function saveProfile(app, u, nick) {
  return setDoc(doc(getDb(app), 'users', u.uid), { nick, name: nick, email: u.email || '', lastLogin: serverTimestamp() }, { merge: true })
}

/** O nick salvo na conta; null se ainda não escolheu. */
export async function readNick(app, uid) {
  const nick = (await getDoc(doc(getDb(app), 'users', uid))).data()?.nick
  return typeof nick === 'string' && nick.trim() ? nick : null
}

/** Apaga os decks e o perfil da conta. */
export async function deleteUserData(app, uid) {
  const db = getDb(app)
  const decks = await getDocs(collection(db, 'users', uid, 'decks'))
  for (const d of decks.docs) await deleteDoc(d.ref)
  await deleteDoc(doc(db, 'users', uid))
}
