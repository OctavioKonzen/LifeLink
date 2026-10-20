import AccountPage from './AccountPage'
import { APK_URL } from '../lib/appRelease'
import Icon from '../components/Icon'

/** Tela de entrar, como a do Pocketdex: arte à esquerda e o formulário à direita. */
export default function LoginPage() {
  return (
    <div className="grid min-h-screen bg-bg lg:grid-cols-2">
      <div className="relative hidden overflow-hidden lg:block" style={{ background: 'linear-gradient(135deg, #3a2a14 0%, #1e1e24 55%, #0d0d12 100%)' }}>
        <img src="./logo.svg" alt="" className="login-float absolute -right-24 -bottom-24 h-[560px] w-[560px] opacity-15" />
        <div className="relative z-10 flex h-full flex-col p-12">
          <div className="flex items-center gap-3">
            <img src="./logo.svg" alt="" className="h-16 w-16" />
            <span className="text-3xl font-black tracking-wide text-white">LIFELINK</span>
          </div>
          <div className="flex-1" />
          <h2 className="max-w-md text-4xl leading-tight font-black text-white">Seus decks, sua vida e suas cartas de Magic em qualquer lugar.</h2>
          <p className="mt-3 max-w-md text-white/80">Entre na sua conta para salvar tudo e usar no computador ou no app.</p>
        </div>
      </div>
      <div className="flex flex-col items-center justify-center px-4 py-10">
        <div className="mb-6 flex flex-col items-center gap-2 lg:hidden">
          <img src="./logo.svg" alt="" className="login-float h-24 w-24" />
          <span className="text-3xl font-black tracking-wide">LIFELINK</span>
        </div>
        <div className="w-full max-w-md">
          <AccountPage bare />
          <a
            href={APK_URL}
            className="mt-5 flex items-center justify-center gap-2 rounded-2xl bg-[#3DDC84] py-3 font-bold text-[#073042] transition hover:brightness-105"
          >
            <Icon name="android" size={20} /> Baixar o app para Android
          </a>
        </div>
      </div>
    </div>
  )
}
