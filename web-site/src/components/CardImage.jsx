import { useState } from 'react'
import { CARD_BACK } from '../lib/scryfall'

/** Imagem de carta com cantos arredondados; mostra o verso se der erro. */
export default function CardImage({ src, alt, className = '', eager = false }) {
  const [failed, setFailed] = useState(false)
  return (
    <img
      src={failed || !src ? CARD_BACK : src}
      alt={alt}
      loading={eager ? 'eager' : 'lazy'}
      decoding="async"
      onError={() => setFailed(true)}
      className={`aspect-[488/680] w-full rounded-[4.5%] bg-bg object-cover ${className}`}
    />
  )
}
