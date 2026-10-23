import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import CardImage from '../components/CardImage'
import { useAuth } from '../lib/auth'
import { acceptFriend, addFriend, declineFriend, friendDecks, friendTrade, messageOf, removeFriend, watchList } from '../lib/online'
import { saveDeck, useUserData } from '../lib/userData'
import { tradeMatches } from '../lib/collection'

// Amigos pelo nick (o mesmo do app, online_screens.dart): pedir, aceitar,
// ver os decks deles e copiar para os meus, e as trocas possíveis.

/**
 * As trocas possíveis com o amigo (o mesmo do app, _TradeWith): o que ele tem
 * para troca e está na minha lista de desejos, e o que eu tenho para troca e ele quer.
 */
function TradeWith({ friend }) {
  const collection = useUserData((s) => s.collection)
  const wishlist = useUserData((s) => s.wishlist)
  const [data, setData] = useState(null)
  useEffect(() => {
    let alive = true
    friendTrade(friend).then((d) => alive && setData(d), () => {})
    return () => {
      alive = false
    }
  }, [friend])
  if (!data) return null
  const m = tradeMatches(collection, wishlist, data.trade, data.wish)
  const nick = friend.nick || ''
  const list = (title, cards, empty) => (
    <div className="mb-3">
      <p className="mb-1 text-xs font-medium uppercase tracking-widest text-muted">{title}</p>
      {!cards.length && <p className="text-sm text-muted">{empty}</p>}
      <ul className="space-y-1">
        {cards.map((c, k) => (
          <li key={`${c.id}-${k}`} className="flex items-center gap-2">
            {c.img ? <img src={c.img} alt="" loading="lazy" className="h-10 w-7 shrink-0 rounded-sm object-cover" /> : <div className="h-10 w-7 shrink-0 rounded-sm bg-card" />}
            <span className="min-w-0">
              <span className="block truncate text-sm font-bold">{c.name}</span>
              <span className="block truncate text-xs text-muted">
                {c.set || ''} · US$ {(Number(c.usd) || 0).toFixed(2)}
              </span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
  return (
    <div className="mt-3 rounded-xl bg-bg p-3">
      <p className="mb-2 font-semibold">Trocas com {nick}</p>
      {list(`${nick.toUpperCase()} tem para troca e você quer`, m.theyHave, 'Nada da sua lista de desejos.')}
      {list(`Você tem para troca e ${nick.toUpperCase()} quer`, m.iHave, `Nada da lista de desejos de ${nick}. Marque cartas "para troca" na sua coleção.`)}
      <p className="text-xs text-muted">
        {data.trade.length} carta(s) para troca · {data.wish.length} na lista de desejos
      </p>
    </div>
  )
}

function FriendDecks({ friend }) {
  const [decks, setDecks] = useState(null)
  const [error, setError] = useState(null)
  const [copied, setCopied] = useState(null)
  useEffect(() => {
    friendDecks(friend).then(setDecks, (e) => setError(messageOf(e)))
  }, [friend])
  if (error) return <p className="text-sm text-danger">{error}</p>
  if (!decks) return <p className="text-sm text-muted">Carregando...</p>
  if (!decks.length) return <p className="text-sm text-muted">{friend.nick} ainda não tem decks.</p>
  return (
    <ul className="mt-2 grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3">
      {decks.map((d) => (
        <li key={d.id} className="rounded-xl bg-bg p-2">
          <div className="mx-auto w-20">
            <CardImage src={d.cards?.[0]?.imageUrl} alt="" />
          </div>
          <p className="mt-2 truncate text-sm font-bold">{d.name}</p>
          <p className="text-xs text-muted">
            {d.type} · {d.cards?.length || 0} cartas
          </p>
          <button
            type="button"
            onClick={() => {
              saveDeck({ id: String(Date.now()), name: `${d.name} (de ${friend.nick})`, type: d.type || 'Normal', cards: d.cards || [] })
              setCopied(d.id)
            }}
            className="mt-2 w-full rounded-lg bg-accent py-1 text-xs font-bold text-on-accent"
          >
            {copied === d.id ? 'Copiado ✓' : 'Copiar para os meus'}
          </button>
        </li>
      ))}
    </ul>
  )
}

export default function FriendsPage() {
  const { status, user } = useAuth()
  const [nick, setNick] = useState('')
  const [msg, setMsg] = useState(null)
  const [friends, setFriends] = useState(null)
  const [requests, setRequests] = useState([])
  const [open, setOpen] = useState(null)
  const signedIn = status === 'signedIn'

  useEffect(() => {
    if (!signedIn) return undefined
    const onError = (e) => setMsg({ ok: false, text: messageOf(e) })
    const a = watchList('friends', setFriends, onError)
    const b = watchList('requests', setRequests, onError)
    return () => {
      a()
      b()
    }
  }, [signedIn])

  if (!signedIn)
    return (
      <p className="py-12 text-center text-muted">
        <Link to="/conta" className="font-bold text-accent underline">
          Entre na conta
        </Link>{' '}
        para adicionar amigos pelo nick.
      </p>
    )

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="font-display text-3xl font-bold tracking-wide sm:text-4xl">Amigos</h1>
      <p className="mb-8 mt-1.5 text-muted">Seu nick: {user?.name}. Adicione amigos pelo nick para ver os decks e as trocas.</p>
      <form
        className="flex gap-2"
        onSubmit={async (e) => {
          e.preventDefault()
          setMsg(null)
          try {
            setMsg({ ok: true, text: await addFriend(nick) })
            setNick('')
          } catch (err) {
            setMsg({ ok: false, text: messageOf(err) })
          }
        }}
      >
        <input
          value={nick}
          onChange={(e) => setNick(e.target.value)}
          placeholder="Nick do amigo"
          className="min-w-0 flex-1 h-11 rounded-lg border border-line bg-surface px-3.5 text-sm outline-none placeholder:text-muted/70 focus:border-accent"
        />
        <button type="submit" className="h-11 cursor-pointer rounded-lg bg-accent px-5 text-sm font-semibold text-on-accent hover:brightness-110">
          Adicionar
        </button>
      </form>
      {msg && <p className={`mt-2 text-sm ${msg.ok ? 'text-success' : 'text-danger'}`}>{msg.text}</p>}

      {requests.length > 0 && (
        <section className="mt-6">
          <h2 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Pedidos de amizade</h2>
          <ul className="space-y-2">
            {requests.map((r) => (
              <li key={r.uid} className="flex items-center gap-2 rounded-2xl border border-line bg-surface p-4">
                <span className="flex-1">
                  ✉️ <b>{r.nick}</b> quer ser seu amigo
                </span>
                <button type="button" onClick={() => declineFriend(r)} className="rounded-lg bg-card px-3 py-1 text-sm font-bold">
                  Recusar
                </button>
                <button type="button" onClick={() => acceptFriend(r)} className="rounded-lg bg-success px-3 py-1 text-sm font-bold text-black">
                  Aceitar
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-6">
        <h2 className="mb-2 text-xs font-medium uppercase tracking-widest text-muted">Amigos</h2>
        {friends === null ? (
          <p className="text-sm text-muted">Carregando...</p>
        ) : friends.length === 0 ? (
          <p className="text-sm text-muted">Nenhum amigo ainda. Adicione pelo nick.</p>
        ) : (
          <ul className="space-y-2">
            {friends.map((f) => (
              <li key={f.uid} className="rounded-2xl border border-line bg-surface p-4">
                <div className="flex items-center gap-3">
                  <span className="grid h-9 w-9 place-items-center rounded-full bg-accent font-bold text-on-accent">{(f.nick || '?')[0].toUpperCase()}</span>
                  <button type="button" disabled={!f.accepted} onClick={() => setOpen(open === f.uid ? null : f.uid)} className="flex-1 text-left">
                    <span className="block font-bold">{f.nick}</span>
                    <span className="block text-xs text-muted">{f.accepted ? (open === f.uid ? 'Esconder os decks e as trocas' : 'Ver os decks e as trocas') : 'Esperando aceitar o pedido'}</span>
                  </button>
                  <button type="button" onClick={() => removeFriend(f)} className="text-sm text-muted hover:text-danger" title="Tirar dos amigos">
                    Remover
                  </button>
                </div>
                {open === f.uid && (
                  <>
                    <TradeWith friend={f} />
                    <FriendDecks friend={f} />
                  </>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}
