import CardDetails from './CardDetails'
import CardImage from './CardImage'
import ExpandingGrid from './ExpandingGrid'
import { displayName, imageOf } from '../lib/scryfall'

const priceOf = (c) => c.prices?.usd ?? c.prices?.usd_foil ?? c.prices?.usd_etched

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
          className="group flex w-full cursor-pointer flex-col gap-2.5 text-left"
          title={displayName(c)}
        >
          <CardImage
            src={imageOf(c, 'normal')}
            alt={displayName(c)}
            className={`shadow-xl shadow-black/50 transition duration-300 group-hover:-translate-y-1.5 group-hover:shadow-accent/20 ${selected ? 'ring-4 ring-accent' : ''}`}
          />
          <span className="flex items-center justify-between gap-2 px-0.5">
            <span className="truncate text-sm font-medium">{displayName(c)}</span>
            {priceOf(c) && <span className="shrink-0 text-sm font-semibold text-accent">US$ {priceOf(c)}</span>}
          </span>
        </button>
      )}
      renderPanel={(c, { close, previous, next }) => <CardDetails card={c} onClose={close} onPrevious={previous} onNext={next} />}
    />
  )
}
