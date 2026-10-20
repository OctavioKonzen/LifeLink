import { symbolUrl } from '../lib/scryfall'

/** Custo de mana ou texto com símbolos ({W}, {2/U}, {T}...) desenhados. */
export function ManaText({ text, size = 16, className = '' }) {
  if (!text) return null
  const parts = text.split(/(\{[^}]+\})/g)
  return (
    <span className={className}>
      {parts.map((part, i) => {
        const m = part.match(/^\{([^}]+)\}$/)
        if (!m) return part
        return (
          <img
            key={i}
            src={symbolUrl(m[1])}
            alt={part}
            title={part}
            width={size}
            height={size}
            className="mx-px inline-block align-[-0.15em]"
            loading="lazy"
          />
        )
      })}
    </span>
  )
}
