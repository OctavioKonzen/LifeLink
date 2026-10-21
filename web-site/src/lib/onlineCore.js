// Mesa online e amigos (o mesmo do app, lib/data/account/online.dart). Aqui
// fica a parte que não depende da tela: o formato da mesa e as operações no
// Firestore (recebem as funções do Firestore em fs, para o teste das regras
// usar o mesmo código).
//
// Mesa: tables/{código} = { owner, ownerNick, g: {...}, p0..p5: {...} }. Cada
// jogador fica no seu pedaço (p0 = vida, veneno, nome... do jogador 1) e cada
// mudança grava só os campos que mudaram ("p1.lives"): dois celulares mexendo
// em jogadores diferentes ao mesmo tempo não se atrapalham.
// Amigos: users/{eu}/friends/{amigo} = { uid, nick }; o pedido vai em
// users/{amigo}/requests/{eu}; convites em users/{amigo}/invites/{código}.

export const PER_PLAYER = [
  'lives', 'poison', 'energy', 'experience', 'tax', 'treasure', 'storm', 'blessing',
  'colors', 'colors2', 'playerNames', 'playerDecks', 'turnTotals', 'cmdRows',
]

/** A partida (formato da conta, com cmdRows) → campos da mesa ("g.playerCount", "p0.lives"). */
export function flattenGame(game) {
  const out = {}
  for (const [key, value] of Object.entries(game)) {
    if (value === undefined) continue
    if (PER_PLAYER.includes(key) && Array.isArray(value)) for (let i = 0; i < 6; i++) out[`p${i}.${key}`] = value[i] ?? null
    else out[`g.${key}`] = value
  }
  return out
}

/** O documento da mesa → a partida no formato da conta. */
export function unflattenGame(doc) {
  const out = { ...doc.g }
  for (const key of PER_PLAYER) {
    const list = Array.from({ length: 6 }, (_, i) => doc[`p${i}`]?.[key] ?? null)
    if (list.some((v) => v !== null)) out[key] = list
  }
  return out
}

export const changedFields = (before, after) =>
  Object.fromEntries(Object.entries(after).filter(([k, v]) => JSON.stringify(before[k]) !== JSON.stringify(v)))

/** Campos achatados → o documento (mapas g, p0..p5). */
export function nestFields(flat) {
  const out = {}
  for (const [key, value] of Object.entries(flat)) {
    const dot = key.indexOf('.')
    ;(out[key.slice(0, dot)] ??= {})[key.slice(dot + 1)] = value
  }
  return out
}

/** Código da mesa: 6 letras e números fáceis de ler (sem 0/O, 1/I). */
export function newTableCode(random = Math.random) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  return Array.from({ length: 6 }, () => chars[Math.floor(random() * chars.length)]).join('')
}

export const normCode = (code) => String(code).toUpperCase().replace(/[^A-Z0-9]/g, '')

// ------------------------------------------------------------------ mesa

export async function createTable(fs, db, me, game) {
  let code
  let ref
  do {
    code = newTableCode()
    ref = fs.doc(db, 'tables', code)
  } while ((await fs.getDoc(ref)).exists())
  const flat = flattenGame(game)
  await fs.setDoc(ref, { owner: me.uid, ownerNick: me.nick || '', createdAt: fs.serverTimestamp(), updatedAt: fs.serverTimestamp(), ...nestFields(flat) })
  return { code, flat }
}

export async function findTable(fs, db, rawCode) {
  const code = normCode(rawCode)
  if (code.length !== 6) throw new Error('O código tem 6 letras e números.')
  const snap = await fs.getDoc(fs.doc(db, 'tables', code))
  if (!snap.exists()) throw new Error(`Não achei a mesa ${code}. Confira o código.`)
  return { code, data: snap.data() }
}

export function pushChanges(fs, db, code, changes) {
  return fs.updateDoc(fs.doc(db, 'tables', code), { ...changes, updatedAt: fs.serverTimestamp() })
}

// ---------------------------------------------------------------- amigos

const col = (fs, db, uid, name) => fs.collection(db, 'users', uid, name)

/** Pede amizade pelo nick. Se a pessoa já tinha pedido, vira amizade. Volta a mensagem. */
export async function addFriend(fs, db, me, nick) {
  const key = String(nick).trim().toLowerCase()
  if (!key) throw new Error('Digite o nick do amigo.')
  const owner = (await fs.getDoc(fs.doc(db, 'nicks', key))).data()
  if (!owner?.uid) throw new Error(`Ninguém tem o nick "${nick}".`)
  if (owner.uid === me.uid) throw new Error('Esse é o seu nick.')
  const realNick = owner.nick || nick
  await fs.setDoc(fs.doc(col(fs, db, me.uid, 'friends'), owner.uid), { uid: owner.uid, nick: realNick, at: fs.serverTimestamp() })
  const theirs = fs.doc(col(fs, db, me.uid, 'requests'), owner.uid)
  if ((await fs.getDoc(theirs)).exists()) {
    await fs.deleteDoc(theirs)
    return `Agora você e ${realNick} são amigos!`
  }
  await fs.setDoc(fs.doc(col(fs, db, owner.uid, 'requests'), me.uid), { uid: me.uid, nick: me.nick || '', at: fs.serverTimestamp() })
  return `Pedido enviado para ${realNick}.`
}

export async function acceptFriend(fs, db, me, request) {
  await fs.setDoc(fs.doc(col(fs, db, me.uid, 'friends'), request.uid), { uid: request.uid, nick: request.nick, at: fs.serverTimestamp() })
  await fs.deleteDoc(fs.doc(col(fs, db, me.uid, 'requests'), request.uid))
}

export const declineFriend = (fs, db, me, request) => fs.deleteDoc(fs.doc(col(fs, db, me.uid, 'requests'), request.uid))
export const removeFriend = (fs, db, me, friend) => fs.deleteDoc(fs.doc(col(fs, db, me.uid, 'friends'), friend.uid))

/** O outro já aceitou? (ele me tem na lista dele) */
export async function isAccepted(fs, db, me, friendUid) {
  try {
    return (await fs.getDoc(fs.doc(col(fs, db, friendUid, 'friends'), me.uid))).exists()
  } catch {
    return false
  }
}

export async function decksOf(fs, db, friendUid) {
  const snap = await fs.getDocs(col(fs, db, friendUid, 'decks'))
  return snap.docs.map((d) => ({ ...d.data(), id: d.id })).sort((a, b) => String(a.name).localeCompare(String(b.name)))
}

export const inviteFriend = (fs, db, me, friend, code) =>
  fs.setDoc(fs.doc(col(fs, db, friend.uid, 'invites'), code), { fromUid: me.uid, fromNick: me.nick || '', code, at: fs.serverTimestamp() })

export const dismissInvite = (fs, db, me, code) => fs.deleteDoc(fs.doc(col(fs, db, me.uid, 'invites'), code))
