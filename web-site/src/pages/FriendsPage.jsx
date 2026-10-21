import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import CardImage from '../components/CardImage'
import { useAuth } from '../lib/auth'
import { acceptFriend, addFriend, declineFriend, friendDecks, messageOf, removeFriend, watchList } from '../lib/online'
import { saveDeck } from '../lib/userData'

// Amigos pelo nick (o mesmo do app, online_screens.dart): pedir, aceitar,
// ver os decks deles e copiar para os meus.

function FriendDecks({ friend }) {
  const [decks, setDecks] = useState(null)
  const [error, setError] = useState(null)
  const [copied, setCopied] = useState(null)
  useEffect(() => {
    friendDecks(friend).then(setDecks, (e) => setError(messageOf(e)))
  }, [friend])
  if (error) return <p className="text-sm text-red-400">{error}</p>
  if (!decks) return <p className="text-sm text-muted">Carregando...</p>
  if (!decks.length) return <p className="text-sm text-muted">{friend.nick} ainda não tem decks.</p>
  return (
    <ul className="mt-2 grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3">
      {decks.map((d) => (
        <li key={d.id} className="rounded-xl bg-text/5 p-2">
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
            className="mt-2 w-full rounded-full bg-accent py-1 text-xs font-bold text-white"
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
      <h1 className="text-2xl font-black">Amigos</h1>
      <p className="mb-4 text-sm text-muted">Seu nick: {user?.name}</p>
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
          className="min-w-0 flex-1 rounded-xl border border-line bg-card px-4 py-2.5 outline-none focus:border-accent"
        />
        <button type="submit" className="rounded-xl bg-accent px-5 font-bold text-white hover:brightness-110">
          Adicionar
        </button>
      </form>
      {msg && <p className={`mt-2 text-sm ${msg.ok ? 'text-emerald-400' : 'text-red-400'}`}>{msg.text}</p>}

      {requests.length > 0 && (
        <section className="mt-6">
          <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Pedidos de amizade</h2>
          <ul className="space-y-2">
            {requests.map((r) => (
              <li key={r.uid} className="flex items-center gap-2 rounded-xl bg-card p-3 shadow">
                <span className="flex-1">
                  ✉️ <b>{r.nick}</b> quer ser seu amigo
                </span>
                <button type="button" onClick={() => declineFriend(r)} className="rounded-full bg-text/10 px-3 py-1 text-sm font-bold">
                  Recusar
                </button>
                <button type="button" onClick={() => acceptFriend(r)} className="rounded-full bg-emerald-500 px-3 py-1 text-sm font-bold text-white">
                  Aceitar
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-6">
        <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Amigos</h2>
        {friends === null ? (
          <p className="text-sm text-muted">Carregando...</p>
        ) : friends.length === 0 ? (
          <p className="text-sm text-muted">Nenhum amigo ainda. Adicione pelo nick.</p>
        ) : (
          <ul className="space-y-2">
            {friends.map((f) => (
              <li key={f.uid} className="rounded-xl bg-card p-3 shadow">
                <div className="flex items-center gap-3">
                  <span className="grid h-9 w-9 place-items-center rounded-full bg-accent font-black text-white">{(f.nick || '?')[0].toUpperCase()}</span>
                  <button type="button" disabled={!f.accepted} onClick={() => setOpen(open === f.uid ? null : f.uid)} className="flex-1 text-left">
                    <span className="block font-bold">{f.nick}</span>
                    <span className="block text-xs text-muted">{f.accepted ? (open === f.uid ? 'Esconder os decks' : 'Ver os decks') : 'Esperando aceitar o pedido'}</span>
                  </button>
                  <button type="button" onClick={() => removeFriend(f)} className="text-sm text-muted hover:text-red-400" title="Tirar dos amigos">
                    Remover
                  </button>
                </div>
                {open === f.uid && <FriendDecks friend={f} />}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}
