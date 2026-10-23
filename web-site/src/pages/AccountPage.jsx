import { useState } from 'react'
import { changeNick, resetPassword, setNick, signIn, signInWithGoogle, signOut, signUp, useAuth } from '../lib/auth'
import { deleteAccount, logout } from '../lib/sync'
import { Loader2, LogOut, Pencil } from 'lucide-react'
import { PageHeader, btnOutline, btnPrimary, inputClass, panel } from '../components/ui'

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
      <h2 className="text-3xl font-semibold tracking-tight">Escolha seu nick</h2>
      <p className="text-sm text-muted">
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
        className={inputClass}
      />
      <button type="submit" disabled={busy} className={`${btnPrimary} h-11`}>
        Continuar
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

  const field = (key, label, placeholder, type = 'text', extra = null) => (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <label htmlFor={`conta-${key}`} className="text-sm font-medium">
          {label}
        </label>
        {extra}
      </div>
      <input
        id={`conta-${key}`}
        value={form[key]}
        onChange={(e) => setForm((f) => ({ ...f, [key]: e.target.value }))}
        placeholder={placeholder}
        type={type}
        autoComplete={type === 'password' ? (creating ? 'new-password' : 'current-password') : key === 'email' ? 'email' : 'nickname'}
        className={inputClass}
      />
    </div>
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
          <div className="grid h-20 w-20 place-items-center rounded-full bg-accent font-display text-3xl font-bold text-on-accent ring-4 ring-accent/20">
            {(user.name || user.email || '?')[0].toUpperCase()}
          </div>
        )}
        <div>
          <div className="font-display text-2xl font-bold">{user.name}</div>
          <div className="text-sm text-muted">{user.email}</div>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              const next = window.prompt('Novo nick (3 a 20 letras). O antigo fica livre para outras pessoas:', user.name)
              if (next && next.trim() !== user.name) run(() => changeNick(next), `Agora seu nick é ${next.trim()}.`)
            }}
            className="mt-2 inline-flex items-center gap-1.5 text-sm font-medium text-accent hover:underline"
          >
            <Pencil className="size-3.5" aria-hidden="true" /> Trocar nick
          </button>
        </div>
        <p className="max-w-md text-sm text-muted">
          Seus decks, perfil, nível, missões, preferências e a partida do contador ficam na conta. O que você muda aqui aparece no app na hora, e
          vice-versa.
        </p>
        <button type="button" disabled={busy} onClick={() => run(logout)} className={btnOutline}>
          <LogOut className="size-4" aria-hidden="true" /> Sair da conta
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => {
            if (window.confirm('Os decks, o perfil e o nível da conta serão apagados para sempre, no app e no site. Continuar?')) {
              run(deleteAccount, 'Conta excluída.')
            }
          }}
          className="text-sm font-medium text-danger hover:underline"
        >
          Excluir conta
        </button>
      </div>
    )
  } else {
    body = (
      <form
        className="flex flex-col gap-5"
        onSubmit={(e) => {
          e.preventDefault()
          run(() => (creating ? signUp(form.name, form.email, form.password) : signIn(form.email, form.password)))
        }}
      >
        <div className="flex flex-col gap-2">
          <h2 className="text-3xl font-semibold tracking-tight">{creating ? 'Criar conta' : 'Bem-vindo de volta'}</h2>
          <p className="text-muted">
            {creating ? 'Os mesmos decks e o mesmo perfil no site e no app.' : 'Entre para continuar sua jornada pelo multiverso.'}
          </p>
        </div>
        {creating && field('name', 'Nick', 'O nome que aparece para todos')}
        {field('email', 'E-mail', 'voce@exemplo.com', 'email')}
        {field(
          'password',
          'Senha',
          creating ? 'Pelo menos 6 letras' : '••••••••',
          'password',
          !creating && (
            <button
              type="button"
              disabled={busy}
              onClick={() =>
                form.email.trim()
                  ? run(() => resetPassword(form.email), 'Enviamos um link para criar uma nova senha.')
                  : setError('Digite o seu e-mail para receber o link de nova senha.')
              }
              className="cursor-pointer text-xs text-accent hover:underline"
            >
              Esqueci a senha
            </button>
          ),
        )}
        <button type="submit" disabled={busy} className={`${btnPrimary} h-11`}>
          {busy && <Loader2 className="size-4 animate-spin" aria-hidden="true" />}
          {creating ? 'Criar conta' : 'Entrar'}
        </button>
        <div className="flex items-center gap-3 text-xs text-muted">
          <span className="h-px flex-1 bg-line" />
          ou
          <span className="h-px flex-1 bg-line" />
        </div>
        <button type="button" disabled={busy} onClick={() => run(signInWithGoogle)} className={`${btnOutline} h-11 bg-surface`}>
          <span className="font-bold text-[#4285f4]">G</span> Continuar com Google
        </button>
        <p className="text-center text-sm text-muted">
          {creating ? 'Já tem conta?' : 'Não tem conta?'}{' '}
          <button
            type="button"
            onClick={() => {
              setCreating(!creating)
              setError(null)
            }}
            className="cursor-pointer font-medium text-accent hover:underline"
          >
            {creating ? 'Entrar' : 'Criar conta'}
          </button>
        </p>
      </form>
    )
  }

  const messages = (
    <>
      {error && <p className="mt-4 text-center text-sm font-semibold text-danger">{error}</p>}
      {notice && <p className="mt-4 text-center text-sm font-semibold text-success">{notice}</p>}
    </>
  )
  // Na tela de entrar: sem caixa, como no redesign.
  if (bare) {
    return (
      <div>
        {body}
        {messages}
      </div>
    )
  }
  return (
    <div className="mx-auto max-w-xl">
      <PageHeader title="Conta" description="Seu nick, o login e os dados salvos na conta." />
      <div className={`${panel} p-6`}>
        {body}
        {busy && <p className="mt-4 text-center text-sm text-muted">Aguarde...</p>}
        {messages}
      </div>
    </div>
  )
}
