import { Smartphone } from 'lucide-react'
import AccountPage from './AccountPage'
import Logo from '../components/Logo'
import { APK_URL } from '../lib/appRelease'

/** Tela de entrar: a arte à esquerda (no computador) e o formulário à direita. */
export default function LoginPage() {
  return (
    <main className="grid min-h-dvh bg-bg lg:grid-cols-2">
      <section className="relative hidden overflow-hidden lg:block">
        <img src="./art/login.webp" alt="" className="absolute inset-0 h-full w-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-bg via-bg/40 to-transparent" />
        <div className="absolute inset-x-0 bottom-0 flex flex-col gap-4 p-12">
          <p className="font-display text-4xl leading-tight font-bold text-balance">Cada partida conta. Cada ponto de vida importa.</p>
          <p className="max-w-md text-pretty text-muted">
            Busque cartas, monte decks, acompanhe sua coleção e os preços do dia — tudo em um só lugar, no site e no app.
          </p>
        </div>
      </section>

      <section className="flex items-center justify-center px-6 py-12">
        <div className="page-in flex w-full max-w-sm flex-col gap-8">
          <Logo size="lg" />
          <AccountPage bare />
          <a href={APK_URL} className="flex items-center justify-center gap-2 text-sm text-muted transition hover:text-text">
            <Smartphone className="size-4 text-success" aria-hidden="true" /> Baixar o app para Android
          </a>
        </div>
      </section>
    </main>
  )
}
