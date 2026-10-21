import { useEffect, useRef, useState } from 'react'
import { Modal, Spinner } from './ui'
import { getJson, imageOf } from '../lib/scryfall'

// Planechase e Archenemy (o mesmo do app, planar_dialogs.dart): um plano ou
// esquema sorteado da Scryfall e, no Planechase, o dado planar 3D.

async function randomCard(query) {
  // Sem cache: cada pedido é uma carta nova.
  const data = await getJson(`https://api.scryfall.com/cards/random?q=${encodeURIComponent(query)}&t=${Date.now()}`)
  return { id: data.id, name: data.printed_name || data.name, type: data.type_line || '', image: imageOf(data) || '', text: data.oracle_text || '' }
}

function TableCard({ card, sideways }) {
  const [turned, setTurned] = useState(sideways)
  return (
    <button type="button" onClick={() => setTurned((t) => !t)} className="mx-auto block text-center" title="Girar a carta">
      <div className="grid h-72 place-items-center">
        {card.image ? (
          <img
            src={card.image}
            alt={card.name}
            className="max-h-72 rounded-xl shadow-lg transition-transform duration-300"
            style={{ transform: turned ? 'rotate(90deg) scale(0.72)' : 'none' }}
          />
        ) : (
          <p className="max-w-xs text-sm text-muted">{card.text}</p>
        )}
      </div>
      <p className="mt-1 text-lg font-black">{card.name}</p>
      <p className="text-xs text-muted">{card.type} · toque para girar</p>
    </button>
  )
}

/** mode: 'planechase' ou 'archenemy'. turnKey muda quando a vez passa (zera o custo do dado). */
export default function TableCardsModal({ mode, card, onCard, turnKey, onClose }) {
  const planar = mode === 'planechase'
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [rolls, setRolls] = useState({ key: turnKey, count: 0 })
  const [roll, setRoll] = useState({ rolling: false, result: '' })
  const box = useRef(null)
  const table = useRef(null)
  const cost = rolls.key === turnKey ? rolls.count : 0

  const draw = async () => {
    setLoading(true)
    setError(null)
    try {
      onCard(await randomCard(planar ? 't:plane or t:phenomenon' : 't:scheme'))
    } catch (e) {
      setError(e.message || 'Não deu para virar uma carta agora.')
    }
    setLoading(false)
  }

  useEffect(() => {
    if (planar && !card) draw()
    if (!planar) return undefined
    let alive = true
    import('../dice3d/engine').then(({ createDiceTable }) => {
      if (!alive || !box.current) return
      table.current = createDiceTable(box.current, {
        onRollStart: () => setRoll({ rolling: true, result: '' }),
        onResult: ({ values }) => {
          const face = values[0]
          setRoll({ rolling: false, result: face === 1 ? 'CAOS! Vale a habilidade de caos do plano.' : face === 6 ? 'VIAGEM! Indo para um plano novo...' : 'Nada acontece.' })
          if (face === 6) setTimeout(draw, 900)
        },
      })
      table.current.show('planar')
    })
    return () => {
      alive = false
      table.current?.dispose()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const rollDie = () => {
    if (roll.rolling || !table.current) return
    setRolls({ key: turnKey, count: cost + 1 })
    table.current.roll('planar')
  }

  return (
    <Modal onClose={onClose}>
      <h2 className="mb-1 text-center text-2xl font-black">{planar ? '🌍 Planechase' : '🔥 Archenemy'}</h2>
      {!planar && <p className="mb-2 text-center text-sm text-muted">No começo de cada vez dele, o arqui-inimigo revela um esquema.</p>}
      {loading ? (
        <div className="grid h-72 place-items-center">
          <Spinner />
        </div>
      ) : error ? (
        <p className="grid h-40 place-items-center text-center text-red-400">{error}</p>
      ) : card ? (
        <TableCard key={card.id} card={card} sideways={planar} />
      ) : (
        <p className="grid h-40 place-items-center text-6xl">🔥</p>
      )}
      {planar && (
        <>
          <div ref={box} onPointerDown={rollDie} className="mt-3 h-44 cursor-pointer overflow-hidden rounded-2xl bg-[#1E1E24]" />
          <p className="flex h-10 items-center justify-center text-center font-black text-amber-300">
            {roll.result || <span className="text-sm font-normal text-muted">{roll.rolling ? '' : 'Toque no dado para rolar'}</span>}
          </p>
        </>
      )}
      <div className="mt-2 flex gap-2">
        <button type="button" disabled={loading} onClick={draw} className="flex-1 rounded-full bg-text/10 py-2.5 font-bold hover:bg-text/20 disabled:opacity-50">
          {planar ? 'Outro plano' : card ? 'Revelar o próximo' : 'Revelar esquema'}
        </button>
        {planar && (
          <button
            type="button"
            disabled={roll.rolling}
            onClick={rollDie}
            className="flex-1 rounded-full bg-slate-600 py-2.5 font-black text-white hover:brightness-110 disabled:opacity-50"
          >
            {cost === 0 ? 'Rolar (grátis)' : `Rolar (${cost} de mana)`}
          </button>
        )}
      </div>
      {planar && <p className="mt-2 text-center text-xs text-muted">A primeira rolagem de cada vez é grátis; cada outra na mesma vez custa 1 a mais.</p>}
    </Modal>
  )
}
