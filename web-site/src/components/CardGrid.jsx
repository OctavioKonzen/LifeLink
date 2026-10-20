import CardImage from './CardImage'
import { displayName, imageOf } from '../lib/scryfall'

export default function CardGrid({ cards, onOpen }) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      {cards.map((c) => (
        <button key={c.id} type="button" onClick={() => onOpen(c)} className="text-left transition hover:scale-[1.03]" title={displayName(c)}>
          <CardImage src={imageOf(c, 'normal')} alt={displayName(c)} />
        </button>
      ))}
    </div>
  )
}
