import { useEffect } from 'react'

export function Spinner({ className = '' }) {
  return (
    <div className={`flex justify-center py-10 ${className}`}>
      <div className="h-9 w-9 animate-spin rounded-full border-4 border-white/15 border-t-accent" />
    </div>
  )
}

export function ErrorBox({ message, onRetry }) {
  return (
    <div className="flex flex-col items-center gap-4 py-12 text-center">
      <p className="font-bold text-red-400">{message}</p>
      {onRetry && (
        <button type="button" onClick={onRetry} className="rounded-full border border-white/30 px-4 py-2 text-sm font-bold hover:bg-white/10">
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
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 p-3 sm:p-6" onClick={onClose}>
      <div
        className={`relative mx-auto my-4 w-full rounded-2xl bg-surface p-4 shadow-2xl sm:p-6 ${wide ? 'max-w-5xl' : 'max-w-3xl'}`}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Fechar"
          className="absolute right-3 top-3 grid h-9 w-9 place-items-center rounded-full bg-white/10 text-lg hover:bg-white/20"
        >
          ✕
        </button>
        {children}
      </div>
    </div>
  )
}
