/** O logo do LifeLink (o original, logo.svg) e o nome em Cinzel. */
export default function Logo({ size = 'md' }) {
  const lg = size === 'lg'
  return (
    <span className="flex items-center gap-2.5">
      <img src="./logo.svg" alt="" className={`drop-shadow-[0_4px_12px_rgba(240,180,76,0.25)] ${lg ? 'size-12' : 'size-9'}`} />
      <span className={`font-display font-bold tracking-wider ${lg ? 'text-2xl' : 'text-lg'}`}>LifeLink</span>
    </span>
  )
}
