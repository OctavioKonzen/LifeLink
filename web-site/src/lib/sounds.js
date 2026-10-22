// Sons do contador de vida (public/sounds, os mesmos do app, gerados por
// tool/make_sounds.py): dano, cura, veneno, comandante e morte.

const KEY = 'lifelink_sons'
const cache = {}
const last = {}

export function soundsOn() {
  try {
    return localStorage.getItem(KEY) !== 'off'
  } catch {
    return true
  }
}

export function setSoundsOn(on) {
  try {
    localStorage.setItem(KEY, on ? 'on' : 'off')
  } catch {
    // Navegador sem armazenamento: vale só nesta visita.
  }
}

// Segurando o botão: guarda o som e toca uma vez só ao soltar (o mais
// importante: morte > comandante > veneno > dano > cura).
const RANK = { cura: 1, dano: 2, veneno: 3, comandante: 4, morte: 5 }
let holding = false
let pending = null

export function beginHold() {
  holding = true
  pending = null
}

export function endHold() {
  if (!holding) return
  holding = false
  const name = pending
  pending = null
  if (name) playSound(name)
}

export function playSound(name) {
  if (!soundsOn()) return
  if (holding) {
    if (!pending || RANK[name] > RANK[pending]) pending = name
    return
  }
  const now = Date.now()
  if (now - (last[name] || 0) < 90) return // vários toques seguidos: um som
  last[name] = now
  cache[name] ??= new Audio(`./sounds/${name}.wav`)
  const audio = cache[name].cloneNode()
  audio.volume = 0.9
  audio.play().catch(() => {})
}

const dead = (g, i) => g.lives[i] <= 0 || g.poison[i] >= 10 || g.commander[i].some((d) => d >= 21) || (g.partnerDamage?.[i] || []).some((d) => d >= 21)
const sum = (list) => list.reduce((a, b) => a + b, 0)

/**
 * O som de uma mudança na partida (antes → depois): morte se alguém acabou
 * de morrer; senão comandante, veneno, dano ou cura.
 */
export function soundFor(before, after) {
  let pick = null
  const rank = { morte: 5, comandante: 4, veneno: 3, dano: 2, cura: 1 }
  const take = (name) => {
    if (!pick || rank[name] > rank[pick]) pick = name
  }
  for (let i = 0; i < after.players; i++) {
    if (!dead(before, i) && dead(after, i)) take('morte')
    const cmd = sum(after.commander[i]) + sum(after.partnerDamage?.[i] || []) - sum(before.commander[i]) - sum(before.partnerDamage?.[i] || [])
    const poison = after.poison[i] - before.poison[i]
    const life = after.lives[i] - before.lives[i]
    if (cmd > 0) take('comandante')
    else if (poison > 0) take('veneno')
    else if (life < 0) take('dano')
    else if (life > 0 || poison < 0 || cmd < 0) take('cura')
  }
  return pick
}
