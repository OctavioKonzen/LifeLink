// Som dos dados, gerado na hora (Web Audio, sem arquivo): cada batida é um
// "clac" curto, mais alto quanto mais forte a batida. Dado na mesa soa mais
// grave; dado batendo em dado, mais agudo.

let ctx = null
let noise = null
let muted = false

function audio() {
  if (ctx) return ctx
  const AC = window.AudioContext || window.webkitAudioContext
  if (!AC) return null
  ctx = new AC()
  // Ruído branco curto, reaproveitado em todas as batidas.
  noise = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.12), ctx.sampleRate)
  const data = noise.getChannelData(0)
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1
  return ctx
}

/** Chamar num toque/clique: o navegador só libera o som depois de um gesto. */
export function unlockSound() {
  const c = audio()
  if (c && c.state === 'suspended') c.resume().catch(() => {})
}

export function setMuted(value) {
  muted = value
}

/**
 * Uma batida. strength: 0 a 1; kind: 'table' (na mesa) ou 'dice' (dado com dado).
 */
export function playClack(strength, kind = 'table') {
  if (muted) return
  const c = audio()
  if (!c || c.state !== 'running') return
  const now = c.currentTime
  const volume = Math.min(1, Math.max(0.05, strength)) * 0.9

  // O estalo: ruído filtrado com queda rápida.
  const src = c.createBufferSource()
  src.buffer = noise
  const band = c.createBiquadFilter()
  band.type = 'bandpass'
  band.frequency.value = (kind === 'dice' ? 3400 : 1900) + Math.random() * 900
  band.Q.value = kind === 'dice' ? 6 : 3.5
  const gain = c.createGain()
  gain.gain.setValueAtTime(0.0001, now)
  gain.gain.exponentialRampToValueAtTime(volume, now + 0.002)
  gain.gain.exponentialRampToValueAtTime(0.0001, now + (kind === 'dice' ? 0.05 : 0.09))
  src.connect(band).connect(gain).connect(c.destination)
  src.start(now)
  src.stop(now + 0.12)

  // O "toc" do corpo do dado: um tom curto por baixo do estalo.
  const tone = c.createOscillator()
  tone.type = 'triangle'
  tone.frequency.setValueAtTime((kind === 'dice' ? 1500 : 700) + Math.random() * 200, now)
  tone.frequency.exponentialRampToValueAtTime(kind === 'dice' ? 900 : 380, now + 0.05)
  const toneGain = c.createGain()
  toneGain.gain.setValueAtTime(0.0001, now)
  toneGain.gain.exponentialRampToValueAtTime(volume * 0.35, now + 0.002)
  toneGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.06)
  tone.connect(toneGain).connect(c.destination)
  tone.start(now)
  tone.stop(now + 0.08)
}
