// Testa as regras do banco (firestore.rules) no simulador do Firebase, com o
// mesmo fluxo do app e do site: escolher o nick, nick com dono, trocar o
// nick e gravar os dados da conta.
//   cd tool/rules-test && npm install && npm test

import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing'
import { doc, getDoc, setDoc, runTransaction, updateDoc } from 'firebase/firestore'
import fs from 'fs'

const env = await initializeTestEnvironment({ projectId: 'lifelink-test', firestore: { rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 } })

async function claim(db, uid, nick) {
  const nickRef = doc(db, 'nicks', nick.trim().toLowerCase())
  await runTransaction(db, async (tx) => {
    const owner = await tx.get(nickRef)
    if (owner.exists() && owner.data().uid !== uid) throw new Error('TAKEN')
    if (!owner.exists()) tx.set(nickRef, { uid, nick })
    tx.set(doc(db, 'users', uid), { nick, name: nick }, { merge: true })
  })
}
let failed = 0
const run = async (name, p) => {
  try {
    await p
    console.log('OK   ', name)
  } catch (e) {
    failed++
    console.log('ERRO ', name, '→', e.code || e.message)
  }
}

const a = env.authenticatedContext('alice').firestore()
const b = env.authenticatedContext('bob').firestore()
const anon = env.unauthenticatedContext().firestore()

await run('1. nick livre, conta nova (sem perfil)', claim(a, 'alice', 'Octaviok1'))
await run('2. qualquer um vê se o nick está livre', getDoc(doc(anon, 'nicks', 'octaviok1')))
await run('3. outra pessoa NÃO pega o mesmo nick (deve dar erro)', claim(b, 'bob', 'OCTAVIOK1').then(() => { throw new Error('PEGOU!') }, (e) => { if (e.message === 'TAKEN' || e.code === 'permission-denied') return; throw e }))
await run('4. perfil já existia sem nick', setDoc(doc(b, 'users', 'bob'), { name: 'x', email: 'b@b' }).then(() => claim(b, 'bob', 'Bob_2')))
await run('5. trocar o nick é recusado (deve dar erro)', assertFails(updateDoc(doc(a, 'users', 'alice'), { nick: 'outro' })))
await run('6. sync grava dados sem mexer no nick', assertSucceeds(setDoc(doc(a, 'users', 'alice'), { data: { game: {} } }, { merge: true })))
await run('7. registrar um segundo nick é recusado (deve dar erro)', assertFails(setDoc(doc(a, 'nicks', 'segundo'), { uid: 'alice', nick: 'segundo' })))
await env.cleanup()
process.exit(failed ? 1 : 0)
