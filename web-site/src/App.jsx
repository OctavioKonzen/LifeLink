import { useEffect, useState } from 'react'
import { HashRouter, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import SearchPage from './pages/SearchPage'
import PricesPage from './pages/PricesPage'
import DecksPage from './pages/DecksPage'
import LifeCounterPage from './pages/LifeCounterPage'
import MyDecksPage from './pages/MyDecksPage'
import ProfilePage from './pages/ProfilePage'
import AccountPage from './pages/AccountPage'
import LoginPage from './pages/LoginPage'
import Icon from './components/Icon'
import { useAuth } from './lib/auth'
import { logout } from './lib/sync'
import { APK_URL } from './lib/appRelease'
import { setTheme, useTheme } from './lib/theme'

// Mesmas áreas do menu do app (home_screen.dart), com as cores dos botões.
const SECTIONS = [
  { path: '/', label: 'Cartas', color: '#448aff', icon: 'search' },
  { path: '/meus-decks', label: 'Meus decks', color: '#7c4dff', icon: 'layers' },
  { path: '/precos', label: 'Preços de hoje', color: '#ffa000', icon: 'money' },
  { path: '/decks', label: 'Decks oficiais', color: '#00c853', icon: 'book' },
  { path: '/contador', label: 'Contador de vida', color: '#ff5252', icon: 'heart' },
  { path: '/perfil', label: 'Perfil', color: '#00b0ff', icon: 'trophy' },
]

function NavButton({ section }) {
  return (
    <NavLink
      to={section.path}
      end={section.path === '/'}
      title={section.label}
      className="group flex shrink-0 items-center gap-2 rounded-full px-3 py-2 text-[15px] font-semibold whitespace-nowrap transition duration-200 hover:scale-105 active:scale-95 md:px-4"
      style={({ isActive }) =>
        isActive
          ? { background: section.color, color: '#fff', boxShadow: `0 4px 12px ${section.color}70` }
          : { color: 'var(--text)' }
      }
    >
      {({ isActive }) => (
        <>
          <Icon name={section.icon} size={20} style={{ color: isActive ? undefined : section.color }} />
          {/* Em telas menores aparecem só os ícones. */}
          <span className="hidden xl:inline">{section.label}</span>
        </>
      )}
    </NavLink>
  )
}

/** Botão de tema claro/escuro no menu (sol ↔ lua). */
function ThemeToggle() {
  const theme = useTheme()
  const dark = theme === 'dark'
  return (
    <button
      type="button"
      onClick={() => setTheme(dark ? 'light' : 'dark')}
      aria-label={dark ? 'Mudar para tema claro' : 'Mudar para tema escuro'}
      title={dark ? 'Tema claro' : 'Tema escuro'}
      className="grid h-10 w-10 shrink-0 cursor-pointer place-items-center rounded-full bg-bg transition hover:scale-110 active:scale-90"
    >
      <Icon name={dark ? 'sun' : 'moon'} size={22} className={dark ? 'text-yellow-300' : 'text-indigo-500'} />
    </button>
  )
}

export function Avatar({ user, size = 36 }) {
  if (user?.photo) return <img src={user.photo} alt="" width={size} height={size} className="rounded-full" referrerPolicy="no-referrer" />
  return (
    <span className="grid place-items-center rounded-full bg-accent font-black text-white" style={{ width: size, height: size, fontSize: size * 0.45 }}>
      {(user?.name || user?.email || '?')[0].toUpperCase()}
    </span>
  )
}

function MenuItem({ icon, danger = false, onClick, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full cursor-pointer items-center gap-3 rounded-xl px-3 py-2.5 text-left font-semibold transition hover:bg-surface ${danger ? 'text-red-500' : 'text-text'}`}
    >
      <Icon name={icon} size={20} className={danger ? '' : 'text-muted'} />
      {children}
    </button>
  )
}

/** Pessoa logada: foto de perfil; o menu tem o perfil, a conta e sair. */
function UserMenu() {
  const { status, user } = useAuth()
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  useEffect(() => {
    if (!open) return
    const close = () => setOpen(false)
    window.addEventListener('click', close)
    return () => window.removeEventListener('click', close)
  }, [open])
  if (status !== 'signedIn') return null
  const go = (path) => {
    setOpen(false)
    navigate(path)
  }
  return (
    <div className="relative shrink-0">
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation()
          setOpen(!open)
        }}
        title={user.name || user.email}
        aria-label="Menu da conta"
        className="flex cursor-pointer items-center gap-2 rounded-full bg-bg p-1 transition hover:scale-105 xl:pr-4"
      >
        <Avatar user={user} />
        <span className="hidden max-w-[140px] truncate font-semibold xl:inline">{(user.name || 'Conta').split(' ')[0]}</span>
      </button>
      {open && (
        <div onClick={(e) => e.stopPropagation()} className="page-in absolute right-0 mt-2 w-64 rounded-2xl bg-card p-4 shadow-2xl ring-1 ring-line">
          <div className="mb-4 flex items-center gap-3">
            <Avatar user={user} size={56} />
            <div className="min-w-0">
              <div className="truncate text-lg font-bold">{user.name}</div>
              <div className="truncate text-sm text-muted">{user.email}</div>
            </div>
          </div>
          <MenuItem icon="trophy" onClick={() => go('/perfil')}>
            Perfil e nível
          </MenuItem>
          <MenuItem icon="person" onClick={() => go('/conta')}>
            Conta
          </MenuItem>
          <div className="my-2 h-px bg-line" />
          <MenuItem icon="logout" danger onClick={logout}>
            Sair da conta
          </MenuItem>
        </div>
      )}
    </div>
  )
}

function TopBar() {
  const navigate = useNavigate()
  return (
    <header className="sticky top-0 z-40 bg-surface shadow-lg">
      <div className="mx-auto flex h-[72px] max-w-[1920px] items-center gap-2 px-3 sm:gap-4 sm:px-6">
        <button type="button" onClick={() => navigate('/')} className="flex shrink-0 cursor-pointer items-center gap-2 transition hover:scale-105" aria-label="LifeLink">
          <img src="./logo.svg" alt="" className="h-10 w-10 md:h-12 md:w-12" />
          <span className="hidden text-xl font-black tracking-wide sm:inline">LIFELINK</span>
        </button>
        <nav className="flex min-w-0 flex-1 gap-1 overflow-x-auto py-2">
          {SECTIONS.map((s) => (
            <NavButton key={s.path} section={s} />
          ))}
        </nav>
        <a
          href={APK_URL}
          title="Baixar o app para Android"
          className="flex shrink-0 items-center gap-1.5 rounded-full bg-[#3DDC84] px-2.5 py-2 text-sm font-bold text-[#073042] transition hover:scale-105 active:scale-95 2xl:px-4"
        >
          <Icon name="android" size={20} />
          <span className="hidden 2xl:inline">Baixar app</span>
        </a>
        <ThemeToggle />
        <UserMenu />
      </div>
    </header>
  )
}

/** O conteúdo da página, com a largura toda da tela (o contador sem rodapé). */
function Main({ children }) {
  const { pathname } = useLocation()
  const mode = pathname === '/contador' ? 'counter' : 'wide'
  const mainClass = mode === 'counter' ? 'px-3 py-3 sm:px-6' : 'px-4 py-5 sm:px-6'
  return (
    <>
      <main className={mainClass}>{children}</main>
      {mode !== 'counter' && (
        <footer className="px-4 pb-8 pt-4 text-xs text-muted sm:px-6">
          Dados e imagens das cartas:{' '}
          <a className="underline" href="https://scryfall.com" target="_blank" rel="noreferrer">
            Scryfall
          </a>
          . Decks oficiais:{' '}
          <a className="underline" href="https://mtgjson.com" target="_blank" rel="noreferrer">
            MTGJSON
          </a>
          . Magic: The Gathering é marca da Wizards of the Coast; este site não tem ligação com ela.
        </footer>
      )}
    </>
  )
}

/** A troca de página: um fade curto (sem corte seco). */
function PageFade({ children }) {
  const { pathname } = useLocation()
  useEffect(() => {
    window.scrollTo(0, 0)
  }, [pathname])
  return (
    <div key={pathname} className="page-in">
      {children}
    </div>
  )
}

/** Tela de abertura enquanto o login é verificado. */
function Splash() {
  return (
    <div className="grid min-h-screen place-items-center bg-bg">
      <div className="flex flex-col items-center gap-6">
        <img src="./logo.svg" alt="LifeLink" className="login-float h-24 w-24" />
        <div className="h-9 w-9 animate-spin rounded-full border-4 border-text/15 border-t-gold" />
      </div>
    </div>
  )
}

export default function App() {
  const { status } = useAuth()
  // Sem estar logado, a primeira tela é sempre a de login (a mesma conta do
  // app). Sem Firebase configurado, o login fica desligado e o site abre direto.
  if (status === 'loading') return <Splash />
  if (status === 'signedOut') return <LoginPage />
  return (
    <HashRouter>
      <TopBar />
      <Main>
        <PageFade>
          <Routes>
            <Route path="/" element={<SearchPage />} />
            <Route path="/precos" element={<PricesPage />} />
            <Route path="/decks" element={<DecksPage />} />
            <Route path="/contador" element={<LifeCounterPage />} />
            <Route path="/meus-decks" element={<MyDecksPage />} />
            <Route path="/perfil" element={<ProfilePage />} />
            <Route path="/conta" element={<AccountPage />} />
            <Route path="*" element={<SearchPage />} />
          </Routes>
        </PageFade>
      </Main>
    </HashRouter>
  )
}
