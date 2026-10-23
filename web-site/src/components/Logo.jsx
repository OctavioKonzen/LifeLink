import { Heart } from 'lucide-react'

/** O logo do LifeLink: o coração no quadrado dourado e o nome em Cinzel. */
export default function Logo({ size = 'md' }) {
  const lg = size === 'lg'
  return (
    <span className="flex items-center gap-2.5">
      <span className={`grid place-items-center rounded-xl bg-accent text-on-accent shadow-lg shadow-accent/25 ${lg ? 'size-11' : 'size-9'}`}>
        <Heart className={lg ? 'size-6' : 'size-5'} fill="currentColor" aria-hidden="true" />
      </span>
      <span className={`font-display font-bold tracking-wider ${lg ? 'text-2xl' : 'text-lg'}`}>LifeLink</span>
    </span>
  )
}
