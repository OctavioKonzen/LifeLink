import { useState } from 'react'
import { changeNick, resetPassword, setNick, signIn, signInWithGoogle, signOut, signUp, useAuth } from '../lib/auth'
import { deleteAccount, logout } from '../lib/sync'

/** Primeira vez com Google: escolhe o nick antes de entrar. */
function NickForm({ user, busy, run }) {
  const [nick, setNickText] = useState(() => (user?.name || '').trim().split(' ')[0].slice(0, 20))
  return (
    <form
      className="flex flex-col gap-3"
      onSubmit={(e) => {
        e.preventDefault()
        run(() => setNick(nick))
      }}
    >
      <h2 className="text-center text-xl font-black">Escolha seu nick</h2>
      <p className="text-center text-sm text-text/70">
        É o nome que aparece no seu perfil, no site e no app.
        {user?.email && (
          <>
            <br />
            Conta: {user.email}
          </>
        )}
      </p>
      <input
        value={nick}
        onChange={(e) => setNickText(e.target.value)}
        placeholder="Nick"
        maxLength={20}
        autoFocus
        className="w-full rounded-xl border border-line bg-card px-4 py-3 outline-none focus:border-accent"
      />
      <button type="submit" disabled={busy} className="rounded-xl bg-accent py-3 font-bold hover:brightness-110">
        CONTINUAR
      </button>
      <button type="button" disabled={busy} onClick={() => run(signOut)} className="text-sm text-muted hover:underline">
        Usar outra conta
      </button>
    </form>
  )
}

/** Conta (a mesma do app): entrar, criar conta (com nick), sair e excluir. */
export default function AccountPage({ bare = false }) {
  const { status, user } = useAuth()
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({ name: '', email: '', password: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState(null)

  const run = async (action, done) => {
    setBusy(true)
    setError(null)
    setNotice(null)
    try {
      await action()
      if (done) setNotice(done)
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  const field = (key, label, type = 'text') => (
    <input
      value={form[key]}
      onChange={(e) => setForm((f) => ({ ...f, [key]: e.target.value }))}
      placeholder={label}
      type={type}
      autoComplete={type === 'password' ? (creating ? 'new-password' : 'current-password') : key === 'email' ? 'email' : 'name'}
      className="w-full rounded-xl border border-line bg-card px-4 py-3 outline-none focus:border-accent"
    />
  )

  let body
  if (status === 'disabled') {
    body = <p className="text-center text-muted">O login ainda não foi configurado no site. Tudo continua salvo neste navegador.</p>
  } else if (status === 'needsNick') {
    body = <NickForm user={user} busy={busy} run={run} />
  } else if (status === 'loading') {
    body = <p className="text-center text-muted">Carregando...</p>
  } else if (status === 'signedIn') {
    body = (
      <div className="flex flex-col items-center gap-3 text-center">
        {user.photo ? (
          <img src={user.photo} alt="" className="h-20 w-20 rounded-full" referrerPolicy="no-referrer" />
        ) : (
          <div className="grid h-20 w-20 place-items-center rounded-full bg-accent text-3xl font-black">
            {(user.name || user.email || '?')[0].toUpperCase()}
          </div>
        )}
        <div>
          <div className="text-xl font-black">{user.name}</div>
          <div className="text-sm text-muted">{user.email}</div>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              const next = window.prompt('Novo nick (3 a 20 letras). O antigo fica livre para outras pessoas:', user.name)
              if (next && next.trim() !== user.name) run(() => changeNick(next), `Agora seu nick é ${next.trim()}.`)
            }}
            className="mt-1 text-sm font-bold text-accent hover:underline"
          >
            ✏️ Trocar nick
          </button>
        </div>
        <p className="max-w-md text-sm text-text/70">
          Seus decks, perfil, nível, missões, preferências e a partida do contador ficam na conta. O que você muda aqui aparece no app na hora, e
          vice-versa.
        </p>
        <button type="button" disabled={busy} onClick={() => run(logout)} className="rounded-full border border-text/30 px-6 py-2 font-bold hover:bg-text/10">
          Sair da conta
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => {
            if (window.confirm('Os decks, o perfil e o nível da conta serão apagados para sempre, no app e no site. Continuar?')) {
              run(deleteAccount, 'Conta excluída.')
            }
          }}
          className="text-sm font-bold text-red-400 hover:underline"
        >
          Excluir conta
        </button>
      </div>
    )
  } else {
    body = (
      <form
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault()
          run(() => (creating ? signUp(form.name, form.email, form.password) : signIn(form.email, form.password)))
        }}
      >
        <p className="text-center text-sm text-text/70">Entre para usar os mesmos decks e o mesmo perfil no site e no app.</p>
        <button
          type="button"
          disabled={busy}
          onClick={() => run(signInWithGoogle)}
          className="flex items-center justify-center gap-2 rounded-xl bg-white py-3 font-bold text-black ring-1 ring-black/10 hover:bg-white/90"
        >
          <span className="text-lg font-black text-blue-600">G</span> Entrar com Google
        </button>
        <div className="flex items-center gap-2 text-xs text-muted">
          <div className="h-px flex-1 bg-text/15" />
          ou com e-mail
          <div className="h-px flex-1 bg-text/15" />
        </div>
        {/* Entrar ou criar conta: as duas opções sempre à vista. */}
        <div className="grid grid-cols-2 gap-1 rounded-xl bg-text/5 p-1">
          {[
            [false, 'Entrar'],
            [true, 'Criar conta'],
          ].map(([value, label]) => (
            <button
              key={label}
              type="button"
              onClick={() => {
                setCreating(value)
                setError(null)
              }}
              className={`rounded-lg py-2 text-sm font-bold ${creating === value ? 'bg-accent text-white' : 'text-muted hover:text-text'}`}
            >
              {label}
            </button>
          ))}
        </div>
        {creating && field('name', 'Nick (o nome que aparece para todos)')}
        {field('email', 'E-mail', 'email')}
        {field('password', creating ? 'Senha (pelo menos 6 letras)' : 'Senha', 'password')}
        <button type="submit" disabled={busy} className="rounded-xl bg-accent py-3 font-bold hover:brightness-110">
          {creating ? 'CRIAR CONTA' : 'ENTRAR'}
        </button>
        {!creating && (
          <button
            type="button"
            disabled={busy}
            onClick={() =>
              form.email.trim()
                ? run(() => resetPassword(form.email), 'Enviamos um link para criar uma nova senha.')
                : setError('Digite o seu e-mail para receber o link de nova senha.')
            }
            className="text-sm text-muted hover:underline"
          >
            Esqueci a senha
          </button>
        )}
      </form>
    )
  }

  return (
    <div className="mx-auto max-w-md">
      {!bare && <h1 className="mb-5 text-center text-2xl font-black">Conta</h1>}
      <div className="rounded-2xl bg-surface p-5 shadow-xl ring-1 ring-line">
        {bare && status !== 'needsNick' && <h1 className="mb-4 text-center text-2xl font-black">Bem-vindo</h1>}
        {body}
        {busy && <p className="mt-4 text-center text-sm text-muted">Aguarde...</p>}
        {error && <p className="mt-4 text-center font-bold text-red-400">{error}</p>}
        {notice && <p className="mt-4 text-center font-bold text-emerald-400">{notice}</p>}
      </div>
    </div>
  )
}
