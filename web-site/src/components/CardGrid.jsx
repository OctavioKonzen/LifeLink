import CardImage from './CardImage'
import { displayName, imageOf } from '../lib/scryfall'

export default function CardGrid({ cards, onOpen }) {
  return (
    // Quantas colunas couberem (cada carta com pelo menos ~170px): a tela toda.
    <div className="grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3 sm:grid-cols-[repeat(auto-fill,minmax(180px,1fr))]">
      {cards.map((c) => (
        <button key={c.id} type="button" onClick={() => onOpen(c)} className="text-left transition hover:scale-[1.03]" title={displayName(c)}>
          <CardImage src={imageOf(c, 'normal')} alt={displayName(c)} />
        </button>
      ))}
    </div>
  )
}
