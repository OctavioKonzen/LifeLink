// Grade em que o item clicado abre logo abaixo da linha dele, empurrando os
// outros para baixo (como no site do Pocketdex). As setas ← → passam para o
// anterior/próximo, Esc fecha e, ao fechar, a página volta para onde estava.

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'

const TOP_BAR = 64

function useWidth(ref) {
  const [width, setWidth] = useState(0)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(el)
    setWidth(el.getBoundingClientRect().width)
    return () => observer.disconnect()
  }, [ref])
  return width
}

/**
 * @param items        a lista
 * @param keyOf        a chave de cada item
 * @param minWidth     largura mínima de cada coluna (px)
 * @param gap          espaço entre os itens (px)
 * @param renderItem   (item, index, open) → o item; abre com onOpen(index)
 * @param renderPanel  (item, {close, previous, next}) → o painel aberto
 */
export default function ExpandingGrid({ items, keyOf, minWidth, gap = 12, renderItem, renderPanel }) {
  const containerRef = useRef(null)
  const rowRefs = useRef([])
  const width = useWidth(containerRef)
  const columns = Math.max(1, Math.floor((width + gap) / (Math.min(minWidth, width || minWidth) + gap)) || 1)

  // {key, byClick, count}: o aberto, guardado pela chave (sobrevive a "carregar mais").
  const [open, setOpen] = useState(null)
  const returnScroll = useRef(null)
  const index = open ? items.findIndex((it) => keyOf(it) === open.key) : -1
  const openRow = index < 0 ? -1 : Math.floor(index / columns)

  useEffect(() => {
    if (open && index < 0) setOpen(null)
  }, [open, index])

  const scrollToRow = useCallback((row) => {
    // Funciona na página e dentro de uma janela (os decks).
    rowRefs.current[row]?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }, [])

  const show = (i, byClick) => {
    const item = items[i]
    if (!item) return
    const row = Math.floor(i / columns)
    if (!open) returnScroll.current = window.scrollY
    if (row !== openRow) requestAnimationFrame(() => scrollToRow(row))
    setOpen((o) => ({ key: keyOf(item), byClick: row !== openRow ? byClick : o?.byClick, count: row !== openRow ? (o?.count ?? 0) + 1 : o.count }))
  }

  const close = () => {
    setOpen(null)
    if (returnScroll.current !== null) {
      window.scrollTo({ top: returnScroll.current, behavior: 'smooth' })
      returnScroll.current = null
    }
  }

  const onOpen = (i) => (open && index === i ? close() : show(i, true))

  // Teclado: ← → navegam, Esc fecha (menos digitando ou numa janela).
  useEffect(() => {
    if (index < 0) return
    const onKey = (e) => {
      if (e.target.closest?.('input, textarea, select, [role=dialog]')) return
      if (e.key === 'ArrowRight') show(index + 1, false)
      else if (e.key === 'ArrowLeft') show(index - 1, false)
      else if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  const rows = Math.ceil(items.length / columns)
  return (
    <div ref={containerRef}>
      {width > 0 &&
        Array.from({ length: rows }, (_, row) => (
          <div key={row} ref={(el) => (rowRefs.current[row] = el)} style={{ marginBottom: gap, scrollMarginTop: TOP_BAR + 12 }}>
            <div className="grid" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`, gap }}>
              {items.slice(row * columns, row * columns + columns).map((item, k) => {
                const i = row * columns + k
                return <div key={keyOf(item)}>{renderItem(item, i, () => onOpen(i), i === index)}</div>
              })}
            </div>
            {row === openRow && (
              <div className="panel-open">
                <div className="min-h-0 overflow-hidden">
                  <div
                    key={open.count}
                    className={open.byClick ? 'panel-pop' : ''}
                    style={{ paddingTop: gap, transformOrigin: `${((index % columns) + 0.5) * (100 / columns)}% 0%` }}
                  >
                    {renderPanel(items[index], {
                      close,
                      previous: index > 0 ? () => show(index - 1, false) : null,
                      next: index < items.length - 1 ? () => show(index + 1, false) : null,
                    })}
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
    </div>
  )
}
