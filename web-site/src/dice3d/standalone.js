// A mesa de dados sozinha, para o app (assets/dice/index.html numa WebView).
// O app chama LifeLinkDice.init(cheia) e depois roll('d20') / show('d6') /
// rollAt([...]), e recebe o resultado pelo canal DiceChannel (JSON).
//   init(false): a mesa da janela de Dados (um dado, tocar rola).
//   init(true): a mesa cobre a tela toda (o "Quem começa"), dados menores,
//   vistos de cima, cada um caindo em cima de um jogador.

import { createDiceTable } from './engine'
import { unlockSound } from './sound'

const send = (message) => {
  const text = JSON.stringify(message)
  if (window.DiceChannel?.postMessage) window.DiceChannel.postMessage(text)
  else window.parent?.postMessage(message, '*')
}

const container = document.getElementById('table')
let table = null
let full = false

function init(cheia = false) {
  if (table) return
  full = cheia
  table = createDiceTable(container, {
    dieSize: full ? (half) => Math.max(0.35, Math.min(half.w, half.d) * 0.24) : undefined,
    topDown: full,
    onResult: (result) => send({ type: 'result', ...result }),
    onRollStart: () => send({ type: 'rolling' }),
  })
  if (full) table.clear()
}

// Tocar na mesa também rola (e libera o som no celular).
container.addEventListener('pointerdown', () => {
  unlockSound()
  if (table && !full && !table.rolling) table.roll()
})

window.LifeLinkDice = {
  init,
  roll: (kind) => table?.roll(kind),
  show: (kind) => table?.show(kind),
  rollAt: (items) => table?.rollAt(items),
  clear: () => table?.clear(),
}

// Para testar no navegador: index.html?mesa=cheia ou index.html?mesa=normal.
const mode = new URLSearchParams(location.search).get('mesa')
if (mode) init(mode === 'cheia')
send({ type: 'ready' })
