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

const PIP = {
  W: ['Branco', 'bg-mana-w text-black'],
  U: ['Azul', 'bg-mana-u text-white'],
  B: ['Preto', 'bg-mana-b text-white'],
  R: ['Vermelho', 'bg-mana-r text-white'],
  G: ['Verde', 'bg-mana-g text-white'],
  C: ['Incolor', 'bg-mana-c text-black'],
}

/** A bolinha de uma cor de mana (o desenho do redesign). */
export function ManaPip({ color, size = 'sm' }) {
  const [label, cls] = PIP[color] || PIP.C
  return (
    <span
      aria-label={label}
      title={label}
      className={`inline-grid shrink-0 place-items-center rounded-full font-bold ring-1 ring-black/40 ${size === 'sm' ? 'size-4 text-[9px]' : 'size-6 text-xs'} ${cls}`}
    >
      {color === 'C' ? '' : color}
    </span>
  )
}
