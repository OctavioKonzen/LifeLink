import { useState } from 'react'
import { resetPassword, signIn, signInWithGoogle, signUp, useAuth } from '../lib/auth'
import { deleteAccount, logout } from '../lib/sync'
import { APK_URL } from '../lib/appRelease'

/** Conta (a mesma do app): entrar, criar conta, sair e excluir. */
export default function AccountPage() {
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
        </div>
        <p className="max-w-md text-sm text-white/70">
          Seus decks, perfil, nível, missões, preferências e a partida do contador ficam na conta. O que você muda aqui aparece no app na hora, e
          vice-versa.
        </p>
        <button type="button" disabled={busy} onClick={() => run(logout)} className="rounded-full border border-white/30 px-6 py-2 font-bold hover:bg-white/10">
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
        <p className="text-center text-sm text-white/70">Entre para usar os mesmos decks e o mesmo perfil no site e no app.</p>
        <button
          type="button"
          disabled={busy}
          onClick={() => run(signInWithGoogle)}
          className="flex items-center justify-center gap-2 rounded-xl bg-white py-3 font-bold text-black hover:bg-white/90"
        >
          <span className="text-lg font-black text-blue-600">G</span> Entrar com Google
        </button>
        <div className="flex items-center gap-2 text-xs text-muted">
          <div className="h-px flex-1 bg-white/15" />
          ou com e-mail
          <div className="h-px flex-1 bg-white/15" />
        </div>
        {creating && field('name', 'Seu nome')}
        {field('email', 'E-mail', 'email')}
        {field('password', 'Senha', 'password')}
        <button type="submit" disabled={busy} className="rounded-xl bg-accent py-3 font-bold hover:brightness-110">
          {creating ? 'CRIAR CONTA' : 'ENTRAR'}
        </button>
        <button
          type="button"
          onClick={() => {
            setCreating((c) => !c)
            setError(null)
          }}
          className="text-sm text-accent"
        >
          {creating ? 'Já tenho conta: entrar' : 'Não tenho conta: criar'}
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
      <h1 className="mb-5 text-center text-2xl font-black">Conta</h1>
      <div className="rounded-2xl bg-surface p-5">
        {body}
        {busy && <p className="mt-4 text-center text-sm text-muted">Aguarde...</p>}
        {error && <p className="mt-4 text-center font-bold text-red-400">{error}</p>}
        {notice && <p className="mt-4 text-center font-bold text-emerald-400">{notice}</p>}
      </div>
      <a href={APK_URL} className="mt-6 block rounded-2xl bg-emerald-600 py-3 text-center font-bold hover:brightness-110">
        📱 Baixar o app para Android (APK)
      </a>
    </div>
  )
}
