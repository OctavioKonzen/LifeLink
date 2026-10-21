// O Firestore (o banco de dados da conta) é a maior parte do Firebase: fica
// neste arquivo separado, baixado só depois que a tela já apareceu.

import { collection, deleteDoc, doc, getDoc, getDocs, getFirestore, onSnapshot, runTransaction, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore'

export { collection, deleteDoc, doc, getDoc, getDocs, onSnapshot, serverTimestamp, setDoc, updateDoc, writeBatch }

let db = null

export function getDb(app) {
  db ??= getFirestore(app)
  return db
}

/** Atualiza o perfil a cada entrada (o nick em si só muda em claimNick). */
export function saveProfile(app, u, nick) {
  return setDoc(doc(getDb(app), 'users', u.uid), { name: nick, email: u.email || '', lastLogin: serverTimestamp() }, { merge: true })
}

// Cada nick é de uma pessoa só (sem diferença de maiúscula e minúscula):
// nicks/{nick em minúsculas} = { uid, nick }. As regras (firestore.rules)
// garantem que ninguém pega o nick de outro nem troca o seu.
export const NICK_TAKEN = 'Esse nick já é de outra pessoa. Escolha outro.'
export const nickKey = (nick) => nick.trim().toLowerCase()

export async function isNickFree(app, nick) {
  return !(await getDoc(doc(getDb(app), 'nicks', nickKey(nick)))).exists()
}

/** Registra o nick em nome desta pessoa e no perfil, juntos (transação). */
export async function claimNick(app, uid, nick) {
  const db = getDb(app)
  const nickRef = doc(db, 'nicks', nickKey(nick))
  try {
    await runTransaction(db, async (tx) => {
      const owner = await tx.get(nickRef)
      if (owner.exists() && owner.data().uid !== uid) throw new Error(NICK_TAKEN)
      if (!owner.exists()) tx.set(nickRef, { uid, nick })
      tx.set(doc(db, 'users', uid), { nick, name: nick }, { merge: true })
    })
  } catch (e) {
    if (e.code !== 'permission-denied') throw e
    // Recusado: ou o nick tem dono (as regras não deixam pegar), ou as regras
    // do banco não estão publicadas. Só diz "nick ocupado" se for.
    const owner = await getDoc(nickRef).then((d) => d.data()?.uid, () => null)
    if (owner && owner !== uid) throw new Error(NICK_TAKEN)
    throw new Error('O servidor recusou salvar o nick. As regras do banco (firestore.rules) precisam ser publicadas no Firebase.')
  }
}

/** Troca o nick: registra o novo e libera o antigo na mesma transação (um nick por pessoa). */
export async function changeNick(app, uid, nick) {
  const db = getDb(app)
  const newRef = doc(db, 'nicks', nickKey(nick))
  const userRef = doc(db, 'users', uid)
  try {
    await runTransaction(db, async (tx) => {
      const current = (await tx.get(userRef)).data()?.nick
      const owner = await tx.get(newRef)
      if (owner.exists() && owner.data().uid !== uid) throw new Error(NICK_TAKEN)
      tx.set(newRef, { uid, nick })
      if (typeof current === 'string' && nickKey(current) !== nickKey(nick)) tx.delete(doc(db, 'nicks', nickKey(current)))
      tx.set(userRef, { nick, name: nick }, { merge: true })
    })
  } catch (e) {
    if (e.code !== 'permission-denied') throw e
    const owner = await getDoc(newRef).then((d) => d.data()?.uid, () => null)
    if (owner && owner !== uid) throw new Error(NICK_TAKEN)
    throw new Error('O servidor recusou a troca. As regras do banco (firestore.rules) precisam ser publicadas de novo no Firebase.')
  }
}

/** O nick salvo na conta; null se ainda não escolheu. */
export async function readNick(app, uid) {
  const nick = (await getDoc(doc(getDb(app), 'users', uid))).data()?.nick
  return typeof nick === 'string' && nick.trim() ? nick : null
}

/** Apaga os decks e o perfil da conta. */
export async function deleteUserData(app, uid) {
  const db = getDb(app)
  // O nick fica livre para outra pessoa.
  const nick = (await getDoc(doc(db, 'users', uid))).data()?.nick
  if (typeof nick === 'string') await deleteDoc(doc(db, 'nicks', nickKey(nick)))
  const decks = await getDocs(collection(db, 'users', uid, 'decks'))
  for (const d of decks.docs) await deleteDoc(d.ref)
  await deleteDoc(doc(db, 'users', uid))
}
