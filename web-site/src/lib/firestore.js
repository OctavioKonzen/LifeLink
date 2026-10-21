// O Firestore (o banco de dados da conta) é a maior parte do Firebase: fica
// neste arquivo separado, baixado só depois que a tela já apareceu.

import { collection, deleteDoc, doc, getDocs, getFirestore, onSnapshot, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore'

export { collection, doc, onSnapshot, serverTimestamp, setDoc, writeBatch }

let db = null

export function getDb(app) {
  db ??= getFirestore(app)
  return db
}

export function saveProfile(app, u, name) {
  return setDoc(
    doc(getDb(app), 'users', u.uid),
    { name: name || u.displayName || u.email?.split('@')[0] || 'Jogador', email: u.email || '', lastLogin: serverTimestamp() },
    { merge: true },
  )
}

/** Apaga os decks e o perfil da conta. */
export async function deleteUserData(app, uid) {
  const db = getDb(app)
  const decks = await getDocs(collection(db, 'users', uid, 'decks'))
  for (const d of decks.docs) await deleteDoc(d.ref)
  await deleteDoc(doc(db, 'users', uid))
}
