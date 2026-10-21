import CardDetails from './CardDetails'
import CardImage from './CardImage'
import ExpandingGrid from './ExpandingGrid'
import { displayName, imageOf } from '../lib/scryfall'

/**
 * Cartas em quantas colunas couberem (a tela toda). Clicando, a ficha da
 * carta abre embaixo da linha dela, empurrando as outras para baixo.
 */
export default function CardGrid({ cards, onOpen }) {
  return (
    <ExpandingGrid
      items={cards}
      keyOf={(c) => c.id}
      minWidth={window.innerWidth < 640 ? 150 : 180}
      renderItem={(c, i, open, selected) => (
        <button
          type="button"
          onClick={() => {
            if (!selected) onOpen?.(c)
            open()
          }}
          className={`block w-full rounded-[4.5%] text-left transition hover:scale-[1.03] ${selected ? 'ring-4 ring-accent' : ''}`}
          title={displayName(c)}
        >
          <CardImage src={imageOf(c, 'normal')} alt={displayName(c)} />
        </button>
      )}
      renderPanel={(c, { close, previous, next }) => <CardDetails card={c} onClose={close} onPrevious={previous} onNext={next} />}
    />
  )
}
