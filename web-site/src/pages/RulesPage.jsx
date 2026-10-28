import { useEffect, useMemo, useState } from 'react'
import { Gavel, Search } from 'lucide-react'
import CardDetails from '../components/CardDetails'
import { ErrorBox, Modal, PageHeader, Spinner, panel } from '../components/ui'
import { family, loadRules, norm, searchRules, sectionOf } from '../lib/rules'
import { search as ownSearch } from '../lib/lifelinkCards'
import { useUserData } from '../lib/userData'

// Perguntas de exemplo (tocar já busca).
const EXAMPLES = ['atropelar com toque mortífero', 'dano de comandante', 'quantos marcadores de veneno', 'regra da lenda', 'pilha e prioridade', '702.19']

/** O texto da regra, com "Example:" em itálico. */
function RuleText({ text }) {
  return text.split('\n').map((line, k) => (
    <p key={k} className={line.startsWith('Example:') ? 'mt-1.5 text-sm italic text-muted' : ''}>
      {line}
    </p>
  ))
}

/**
 * O juiz de regras: a pergunta (em português ou inglês) busca nas Regras
 * Completas oficiais e no glossário; se for o nome de uma carta, mostra a
 * carta com as regras dela (rulings).
 */
export default function RulesPage() {
  const lang = useUserData((s) => s.settings?.cardLanguage) || 'pt'
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)
  const [retry, setRetry] = useState(0)
  const [text, setText] = useState('')
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(null) // id da regra aberta
  const [card, setCard] = useState(null) // carta com o nome perguntado
  const [cardOpen, setCardOpen] = useState(false)

  useEffect(() => {
    setError(null)
    loadRules().then(setData, (e) => setError(e.message))
  }, [retry])

  // Busca 300 ms depois de parar de digitar.
  useEffect(() => {
    const timer = setTimeout(() => setQuery(text), 300)
    return () => clearTimeout(timer)
  }, [text])

  // A pergunta é o nome de uma carta? Mostra a carta (com as regras dela).
  useEffect(() => {
    setCard(null)
    const q = query.trim()
    if (q.length < 3 || /^\d/.test(q)) return
    let alive = true
    ownSearch({ text: q, nameOnly: true, lang })
      .then((r) => {
        const hit = r.cards.find((c) => norm(c.printed_name || c.name) === norm(q) || norm(c.name) === norm(q))
        if (alive && hit) setCard(hit)
      })
      .catch(() => {})
    return () => {
      alive = false
    }
  }, [query, lang])

  const result = useMemo(() => (data && query.trim() ? searchRules(data, query) : null), [data, query])

  return (
    <div>
      <PageHeader title="Regras" description="Pergunte em português ou inglês: a resposta vem das Regras Completas oficiais de Magic (em inglês)." />
      <div className={`${panel} mb-4 p-3`}>
        <label className="relative block">
          <span className="sr-only">Pergunta</span>
          <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden="true" />
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Ex.: atropelar com toque mortífero, dano de comandante, 702.19"
            className="h-11 w-full rounded-xl bg-bg pl-10 pr-3 text-sm placeholder:text-muted/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
            type="search"
            enterKeyHint="search"
            autoFocus
          />
        </label>
      </div>

      {error ? (
        <ErrorBox message={error} onRetry={() => setRetry((r) => r + 1)} />
      ) : !data ? (
        <Spinner />
      ) : !result ? (
        <div className="space-y-4">
          <p className="text-sm text-muted">
            Regras vigentes desde {data.effective}. Toque num exemplo:
          </p>
          <div className="flex flex-wrap gap-2">
            {EXAMPLES.map((e) => (
              <button key={e} type="button" onClick={() => setText(e)} className="cursor-pointer rounded-full bg-card px-3.5 py-1.5 text-sm hover:brightness-125">
                {e}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          {card && (
            <button type="button" onClick={() => setCardOpen(true)} className={`${panel} flex w-full cursor-pointer items-center gap-3 p-4 text-left hover:bg-card`}>
              <Gavel className="size-5 shrink-0 text-accent" aria-hidden="true" />
              <span>
                <span className="block font-semibold">Carta: {card.printed_name || card.name}</span>
                <span className="text-sm text-muted">Ver a carta e as regras oficiais dela</span>
              </span>
            </button>
          )}
          {result.terms.length > 0 && (
            <p className="text-xs text-muted">
              Buscando por: {result.terms.join(' · ')}
            </p>
          )}
          {result.glossary.map(([term, def]) => (
            <div key={term} className={`${panel} border-accent/40 p-4`}>
              <p className="mb-1 text-xs font-bold uppercase tracking-widest text-accent">Glossário</p>
              <p className="font-semibold">{term}</p>
              <div className="mt-1 text-sm">
                <RuleText text={def} />
              </div>
            </div>
          ))}
          {result.rules.length === 0 && !result.glossary.length && (
            <p className="rounded-2xl border border-dashed border-line py-12 text-center text-muted">
              Nada encontrado. Tente outras palavras (ex.: o nome da habilidade) ou o número da regra.
            </p>
          )}
          {result.rules.map(([id, rule]) => (
            <button key={id} type="button" onClick={() => setOpen(id)} className={`${panel} block w-full cursor-pointer p-4 text-left hover:bg-card`}>
              <span className="mb-1 flex items-center gap-2 text-xs text-muted">
                <span className="rounded-md bg-accent px-1.5 py-0.5 font-bold text-on-accent">{id}</span>
                {sectionOf(data, id)}
              </span>
              <span className="line-clamp-4 block text-sm">
                <RuleText text={rule} />
              </span>
            </button>
          ))}
        </div>
      )}

      {open && data && (
        <Modal onClose={() => setOpen(null)}>
          <p className="mb-1 text-sm text-muted">{sectionOf(data, open)}</p>
          <div className="space-y-3 pr-6">
            {family(data, open).map(([id, rule]) => (
              <div key={id} className={id === open ? 'rounded-xl bg-card p-3' : 'px-3'}>
                <span className="text-xs font-bold text-accent">{id}</span>
                <div className="text-sm">
                  <RuleText text={rule} />
                </div>
              </div>
            ))}
          </div>
        </Modal>
      )}
      {cardOpen && card && (
        <Modal onClose={() => setCardOpen(false)} wide>
          <CardDetails id={card.id} card={card} onClose={() => setCardOpen(false)} />
        </Modal>
      )}
    </div>
  )
}
