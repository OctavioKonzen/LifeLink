import { useEffect, useState } from 'react'
import { Modal } from './ui'
import { useAuth } from '../lib/auth'
import { useUserData } from '../lib/userData'
import { createTable, dismissInvite, inviteFriend, joinTable, leaveTable, messageOf, setMySeat, useOnlineTable, watchList } from '../lib/online'

/** Mesa online: criar (com código), entrar com código, convites e convidar amigos. */
export default function OnlineModal({ onClose }) {
  const { status } = useAuth()
  const table = useOnlineTable()
  const game = useUserData((s) => s.game)
  const names = Array.from({ length: game.playerCount }, (_, i) => String(game.playerNames?.[i] ?? `Jogador ${i + 1}`).replace(/^Player (\d)$/, 'Jogador $1'))
  const [code, setCode] = useState('')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState(null)
  const [friends, setFriends] = useState([])
  const [invites, setInvites] = useState([])
  const signedIn = status === 'signedIn'

  useEffect(() => {
    if (!signedIn) return undefined
    const a = watchList('friends', setFriends)
    const b = watchList('invites', setInvites)
    return () => {
      a()
      b()
    }
  }, [signedIn])

  const run = async (fn) => {
    setBusy(true)
    setMsg(null)
    try {
      const info = await fn()
      if (typeof info === 'string') setMsg({ ok: true, text: info })
    } catch (e) {
      setMsg({ ok: false, text: messageOf(e) })
    }
    setBusy(false)
  }

  return (
    <Modal onClose={onClose}>
      <h2 className="mb-3 text-2xl font-black">🌐 Mesa online</h2>
      {!signedIn ? (
        <p className="text-muted">Entre na conta para jogar com a mesa online.</p>
      ) : table.code ? (
        <div className="space-y-4">
          <p className="text-sm text-muted">Cada um entra com este código no próprio celular (app) ou aqui no site, e a vida de todos aparece em todos.</p>
          <button
            type="button"
            onClick={() => navigator.clipboard?.writeText(table.code).then(() => setMsg({ ok: true, text: 'Código copiado.' }))}
            className="w-full rounded-2xl bg-text/10 py-4 text-center text-4xl font-black tracking-[0.4em]"
            title="Copiar o código"
          >
            {table.code}
          </button>
          <div>
            <p className="text-xs font-black uppercase text-muted">Meu lugar</p>
            <p className="mb-1.5 text-xs text-muted">Cada um no seu celular: o seu quadro fica grande e os dos outros pequenos, todos de frente para você.</p>
            <div className="flex flex-wrap gap-2">
              {[[-1, 'Mesa inteira'], ...names.map((n, i) => [i, n])].map(([seat, label]) => (
                <button
                  key={seat}
                  type="button"
                  onClick={() => setMySeat(seat)}
                  className={`rounded-full px-3 py-1.5 text-sm font-bold ${table.mySeat === seat ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div>
            <p className="mb-1 text-xs font-black uppercase text-muted">Convidar amigo</p>
            {friends.filter((f) => f.accepted).length === 0 && <p className="text-sm text-muted">Sem amigos ainda (Perfil → Amigos).</p>}
            <div className="flex flex-wrap gap-2">
              {friends
                .filter((f) => f.accepted)
                .map((f) => (
                  <button
                    key={f.uid}
                    type="button"
                    disabled={busy}
                    onClick={() => run(async () => (await inviteFriend(f, table.code), `Convite enviado para ${f.nick}.`))}
                    className="rounded-full bg-text/10 px-3 py-1.5 text-sm font-bold hover:bg-text/20"
                  >
                    ✉️ {f.nick}
                  </button>
                ))}
            </div>
          </div>
          <button type="button" onClick={() => leaveTable()} className="rounded-full bg-red-500/15 px-4 py-2 text-sm font-bold text-red-400 hover:bg-red-500/25">
            {table.isOwner ? 'Fechar a mesa' : 'Sair da mesa'}
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {table.error && <p className="rounded-xl bg-amber-400/15 p-3 text-sm text-amber-300">{table.error}</p>}
          <button
            type="button"
            disabled={busy}
            onClick={() => run(createTable)}
            className="w-full rounded-xl bg-accent py-3 font-bold text-white hover:brightness-110 disabled:opacity-60"
          >
            + Criar mesa com esta partida
          </button>
          <form
            className="flex gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              run(() => joinTable(code))
            }}
          >
            <input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              maxLength={6}
              placeholder="CÓDIGO"
              className="min-w-0 flex-1 rounded-xl border border-line bg-card px-4 py-2.5 text-xl font-black tracking-widest outline-none focus:border-accent"
            />
            <button type="submit" disabled={busy} className="rounded-xl bg-text/10 px-5 font-bold hover:bg-text/20">
              Entrar
            </button>
          </form>
          {invites.length > 0 && (
            <div>
              <p className="mb-1 text-xs font-black uppercase text-muted">Convites</p>
              <ul className="space-y-1">
                {invites.map((i) => (
                  <li key={i.id} className="flex items-center gap-2 rounded-xl bg-text/5 px-3 py-2">
                    <span className="flex-1">
                      ✉️ <b>{i.fromNick}</b> chamou para a mesa {i.code}
                    </span>
                    <button type="button" onClick={() => dismissInvite(i.code)} className="text-muted" aria-label="Recusar">
                      ✕
                    </button>
                    <button
                      type="button"
                      onClick={() => run(async () => (await joinTable(i.code), await dismissInvite(i.code)))}
                      className="rounded-full bg-accent px-3 py-1 text-sm font-bold text-white"
                    >
                      Entrar
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
          <p className="text-xs text-muted">Ao entrar numa mesa, a partida daqui vira a da mesa.</p>
        </div>
      )}
      {msg && <p className={`mt-3 text-sm ${msg.ok ? 'text-emerald-400' : 'text-red-400'}`}>{msg.text}</p>}
    </Modal>
  )
}
