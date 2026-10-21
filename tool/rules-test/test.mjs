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

// Amigos e mesa online.
const c = env.authenticatedContext('carol').firestore()
const deckOf = (db, uid) => getDoc(doc(db, 'users', uid, 'decks', '1'))
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users/bob/decks/1'), { name: 'Deck do Bob', cards: [] }))
await run('8. sem amizade, não vê os decks do outro (deve dar erro)', assertFails(deckOf(a, 'bob')))
await run('9. pedir amizade: o amigo na minha lista e o pedido na dele', assertSucceeds(Promise.all([
  setDoc(doc(a, 'users/alice/friends/bob'), { uid: 'bob', nick: 'Bob_2' }),
  setDoc(doc(a, 'users/bob/requests/alice'), { uid: 'alice', nick: 'Octaviok1' }),
])))
await run('10. pedido em nome de outro é recusado (deve dar erro)', assertFails(setDoc(doc(c, 'users/bob/requests/alice'), { uid: 'alice', nick: 'x' })))
await run('11. ainda sem aceitar: alice não vê os decks do bob (deve dar erro)', assertFails(deckOf(a, 'bob')))
await run('12. bob vê o pedido e aceita', assertSucceeds(getDoc(doc(b, 'users/bob/requests/alice')).then(() => setDoc(doc(b, 'users/bob/friends/alice'), { uid: 'alice', nick: 'Octaviok1' }))))
await run('13. amigos veem os decks um do outro', assertSucceeds(deckOf(a, 'bob')))
await run('14. alice sabe que o bob aceitou (lê a própria entrada na lista dele)', assertSucceeds(getDoc(doc(a, 'users/bob/friends/alice'))))
await run('15. quem não é amigo não vê a lista de amigos (deve dar erro)', assertFails(getDoc(doc(c, 'users/bob/friends/alice'))))
await run('16. amigo convida para a mesa', assertSucceeds(setDoc(doc(b, 'users/alice/invites/ABC123'), { fromUid: 'bob', fromNick: 'Bob_2', code: 'ABC123' })))
await run('17. quem não é amigo não convida (deve dar erro)', assertFails(setDoc(doc(c, 'users/alice/invites/XYZ789'), { fromUid: 'carol', code: 'XYZ789' })))
await run('18. criar mesa online em nome próprio', assertSucceeds(setDoc(doc(a, 'tables/ABC123'), { owner: 'alice', g: { playerCount: 2 }, p0: { lives: 40 } })))
await run('19. outro na mesa muda a vida', assertSucceeds(updateDoc(doc(c, 'tables/ABC123'), { 'p0.lives': 35 })))
await run('20. trocar o dono da mesa é recusado (deve dar erro)', assertFails(updateDoc(doc(c, 'tables/ABC123'), { owner: 'carol' })))
await run('21. sem login não vê a mesa (deve dar erro)', assertFails(getDoc(doc(anon, 'tables/ABC123'))))
await env.cleanup()
process.exit(failed ? 1 : 0)
