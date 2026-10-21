// A mesa online e os amigos com o mesmo código do site (web-site/src/lib/onlineCore.js)
// contra as regras do banco, no simulador do Firebase.
import { initializeTestEnvironment } from '@firebase/rules-unit-testing'
import * as fs from 'firebase/firestore'
import { readFileSync } from 'fs'
import { acceptFriend, addFriend, createTable, decksOf, findTable, inviteFriend, isAccepted, pushChanges, unflattenGame } from '../../web-site/src/lib/onlineCore.js'

const env = await initializeTestEnvironment({ projectId: 'lifelink-online', firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 } })
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore()
  await fs.setDoc(fs.doc(db, 'nicks/ana'), { uid: 'ana', nick: 'Ana' })
  await fs.setDoc(fs.doc(db, 'nicks/beto'), { uid: 'beto', nick: 'Beto' })
  await fs.setDoc(fs.doc(db, 'users/beto/decks/1'), { name: 'Krenko', type: 'Commander', cards: [] })
})
const ana = { uid: 'ana', nick: 'Ana' }
const beto = { uid: 'beto', nick: 'Beto' }
const dbA = env.authenticatedContext('ana').firestore()
const dbB = env.authenticatedContext('beto').firestore()

let failed = 0
const check = (name, ok) => {
  console.log(ok ? 'OK   ' : 'ERRO ', name)
  if (!ok) failed++
}
const step = async (name, fn) => {
  try {
    check(name, (await fn()) !== false)
  } catch (e) {
    check(`${name} → ${e.code || e.message}`, false)
  }
}

await step('online 1. Ana pede amizade pelo nick', async () => (await addFriend(fs, dbA, ana, 'beto')).includes('Pedido'))
await step('online 2. ainda não aceito', async () => !(await isAccepted(fs, dbA, ana, 'beto')))
await step('online 3. Beto aceita', () => acceptFriend(fs, dbB, beto, { uid: 'ana', nick: 'Ana' }))
await step('online 4. Ana vê que foi aceito', () => isAccepted(fs, dbA, ana, 'beto'))
await step('online 5. Ana vê os decks do Beto', async () => (await decksOf(fs, dbA, 'beto'))[0].name === 'Krenko')
const game = { playerCount: 2, startingLife: 40, lives: [40, 40, 40, 40, 40, 40], cmdRows: Array(6).fill('0,0,0,0,0,0'), plane: null }
let code
await step('online 6. Ana cria a mesa', async () => {
  code = (await createTable(fs, dbA, ana, game)).code
  return code.length === 6
})
await step('online 7. Ana convida o Beto', () => inviteFriend(fs, dbA, ana, beto, code))
await step('online 8. Beto acha a mesa e tira vida', async () => {
  await findTable(fs, dbB, code.toLowerCase())
  await pushChanges(fs, dbB, code, { 'p0.lives': 33 })
})
await step('online 9. Ana vê a vida nova', async () => unflattenGame((await findTable(fs, dbA, code)).data).lives[0] === 33)
await env.cleanup()
process.exit(failed ? 1 : 0)
