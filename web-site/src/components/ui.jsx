import { useEffect } from 'react'
import { X } from 'lucide-react'

// Os botões do redesign (o mesmo desenho em todo o site).
export const btnPrimary =
  'inline-flex h-10 shrink-0 cursor-pointer items-center justify-center gap-2 rounded-lg bg-accent px-4 text-sm font-semibold text-on-accent transition hover:brightness-110 active:translate-y-px disabled:pointer-events-none disabled:opacity-50'
export const btnOutline =
  'inline-flex h-10 shrink-0 cursor-pointer items-center justify-center gap-2 rounded-lg border border-line bg-transparent px-4 text-sm font-medium transition hover:bg-card active:translate-y-px disabled:pointer-events-none disabled:opacity-50'
export const btnSecondary =
  'inline-flex h-10 shrink-0 cursor-pointer items-center justify-center gap-2 rounded-lg bg-card px-4 text-sm font-medium transition hover:brightness-125 active:translate-y-px disabled:pointer-events-none disabled:opacity-50'
export const inputClass =
  'h-11 w-full rounded-lg border border-line bg-surface px-3.5 text-sm text-text placeholder:text-muted/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent'
export const panel = 'rounded-2xl border border-line bg-surface'

/** O título de cada página (Cinzel), com a descrição e um botão opcional. */
export function PageHeader({ title, description, action }) {
  return (
    <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="flex flex-col gap-1.5">
        <h1 className="font-display text-3xl font-bold tracking-wide sm:text-4xl">{title}</h1>
        {description && <p className="text-muted">{description}</p>}
      </div>
      {action}
    </div>
  )
}

export function Spinner({ className = '' }) {
  return (
    <div className={`flex justify-center py-10 ${className}`}>
      <div className="h-9 w-9 animate-spin rounded-full border-4 border-text/15 border-t-accent" />
    </div>
  )
}

export function ErrorBox({ message, onRetry }) {
  return (
    <div className="flex flex-col items-center gap-4 rounded-2xl border border-dashed border-line py-12 text-center">
      <p className="font-semibold text-danger">{message}</p>
      {onRetry && (
        <button type="button" onClick={onRetry} className={btnOutline}>
          Tentar de novo
        </button>
      )}
    </div>
  )
}

export function Modal({ onClose, children, wide = false }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = overflow
    }
  }, [onClose])
  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 p-3 backdrop-blur-sm sm:p-6" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        className={`page-in relative mx-auto my-4 w-full rounded-2xl border border-line bg-surface p-5 shadow-2xl sm:p-7 ${wide ? 'max-w-5xl' : 'max-w-3xl'}`}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Fechar"
          className="absolute right-3 top-3 z-10 grid size-9 cursor-pointer place-items-center rounded-full bg-card hover:brightness-125"
        >
          <X className="size-4" aria-hidden="true" />
        </button>
        {children}
      </div>
    </div>
  )
}
