import { useEffect, useRef, useState } from 'react'
import { Modal, Spinner } from './ui'
import { DICE } from '../dice3d/geometry'

/**
 * Dados 3D (o mesmo motor do app: three.js + física). O motor só é baixado
 * quando a janela abre, para não pesar no site.
 */
export default function DiceModal({ onClose }) {
  const box = useRef(null)
  const table = useRef(null)
  const [kind, setKind] = useState('d20')
  const [state, setState] = useState({ loading: true, rolling: false, result: null, error: null })

  useEffect(() => {
    let alive = true
    import('../dice3d/engine')
      .then(({ createDiceTable }) => {
        if (!alive || !box.current) return
        table.current = createDiceTable(box.current, {
          onRollStart: () => setState((s) => ({ ...s, rolling: true, result: null })),
          onResult: (result) => setState((s) => ({ ...s, rolling: false, result })),
        })
        setState((s) => ({ ...s, loading: false }))
      })
      .catch((e) => alive && setState((s) => ({ ...s, loading: false, error: e.message })))
    return () => {
      alive = false
      table.current?.dispose()
    }
  }, [])

  const pick = (k) => {
    if (state.rolling) return
    setKind(k)
    setState((s) => ({ ...s, result: null }))
    table.current?.show(k)
  }
  const roll = () => !state.rolling && table.current?.roll(kind)
  const color = DICE.find((d) => d.kind === kind).color

  return (
    <Modal onClose={onClose}>
      <h2 className="mb-3 text-center text-2xl font-black">Dados</h2>
      <div className="flex flex-wrap justify-center gap-2">
        {DICE.map((d) => (
          <button
            key={d.kind}
            type="button"
            onClick={() => pick(d.kind)}
            className="rounded-full px-4 py-1.5 text-sm font-black"
            style={kind === d.kind ? { background: d.color, color: '#fff' } : { background: 'rgb(127 127 127 / 0.15)' }}
          >
            {d.label}
          </button>
        ))}
      </div>
      <div ref={box} onPointerDown={roll} className="relative mt-3 h-[340px] cursor-pointer overflow-hidden rounded-2xl bg-[#1E1E24]">
        {state.loading && (
          <div className="absolute inset-0 grid place-items-center">
            <Spinner />
          </div>
        )}
        {state.error && <p className="absolute inset-0 grid place-items-center p-4 text-center text-red-400">{state.error}</p>}
      </div>
      <div className="flex h-16 items-center justify-center">
        {state.result ? (
          <span className="text-5xl font-black" style={{ color, textShadow: `0 0 16px ${color}99` }}>
            {state.result.total}
            {state.result.values.length > 1 && <span className="ml-3 text-base font-bold text-muted">({state.result.values.join(' + ')})</span>}
          </span>
        ) : (
          <span className="text-sm text-muted">{state.rolling ? '' : 'Toque na mesa para rolar'}</span>
        )}
      </div>
      <button
        type="button"
        disabled={state.loading || state.rolling}
        onClick={roll}
        className="w-full rounded-full py-3 font-black text-white disabled:opacity-50"
        style={{ background: color }}
      >
        🎲 Rolar
      </button>
    </Modal>
  )
}
