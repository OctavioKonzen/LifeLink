// A mesa de dados sozinha, para o app (assets/dice/index.html numa WebView).
// O app chama LifeLinkDice.roll('d20') / LifeLinkDice.show('d6') e recebe o
// resultado pelo canal DiceChannel (JSON { kind, values, total }).

import { createDiceTable } from './engine'
import { unlockSound } from './sound'

const send = (message) => {
  const text = JSON.stringify(message)
  if (window.DiceChannel?.postMessage) window.DiceChannel.postMessage(text)
  else window.parent?.postMessage(message, '*')
}

const container = document.getElementById('table')
const table = createDiceTable(container, {
  onResult: (result) => send({ type: 'result', ...result }),
  onRollStart: () => send({ type: 'rolling' }),
})

// Tocar na mesa também rola (e libera o som no celular).
container.addEventListener('pointerdown', () => {
  unlockSound()
  if (!table.rolling) table.roll()
})

window.LifeLinkDice = {
  roll: (kind) => table.roll(kind),
  show: (kind) => table.show(kind),
}
send({ type: 'ready' })
