import { useEffect, useState } from 'react'
import { HashRouter, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import SearchPage from './pages/SearchPage'
import PricesPage from './pages/PricesPage'
import DecksPage from './pages/DecksPage'
import LifeCounterPage from './pages/LifeCounterPage'
import MatchesPage from './pages/MatchesPage'
import CollectionPage from './pages/CollectionPage'
import FriendsPage from './pages/FriendsPage'
import MissionsPage from './pages/MissionsPage'
import MyDecksPage from './pages/MyDecksPage'
import ProfilePage from './pages/ProfilePage'
import AccountPage from './pages/AccountPage'
import LoginPage from './pages/LoginPage'
import RulesPage from './pages/RulesPage'
import SharedDeckPage from './pages/SharedDeckPage'
import { BookOpen, Box, Check, Gavel, Heart, Layers, LogOut, Menu, Palette, Search, Smartphone, TrendingUp, Trophy, User, X } from 'lucide-react'
import Logo from './components/Logo'
import { useAuth } from './lib/auth'
import { logout } from './lib/sync'
import { APK_URL } from './lib/appRelease'
import { THEMES, applyTheme, setTheme, useTheme } from './lib/theme'

// Mesmas áreas do menu do app (home_screen.dart).
const SECTIONS = [
  { path: '/', label: 'Cartas', icon: Search },
  { path: '/meus-decks', label: 'Meus decks', icon: Layers },
  { path: '/colecao', label: 'Coleção', icon: Box },
  { path: '/precos', label: 'Preços', icon: TrendingUp },
  { path: '/decks', label: 'Decks oficiais', icon: BookOpen },
  { path: '/contador', label: 'Contador', icon: Heart },
  { path: '/regras', label: 'Regras', icon: Gavel },
  { path: '/perfil', label: 'Perfil', icon: Trophy },
]

const navClass = ({ isActive }) =>
  `flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
    isActive ? 'bg-card text-text' : 'text-muted hover:text-text'
  }`

/** A cor de fundo (a mesma do app): o botão abre as opções. */
function ThemePicker() {
  const theme = useTheme()
  const [open, setOpen] = useState(false)
  useEffect(() => {
    if (!open) return
    const close = () => setOpen(false)
    window.addEventListener('click', close)
    return () => window.removeEventListener('click', close)
  }, [open])
  return (
    <div className="relative shrink-0">
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation()
          setOpen(!open)
        }}
        aria-label="Cor de fundo"
        title="Cor de fundo"
        aria-expanded={open}
        className="grid size-9 cursor-pointer place-items-center rounded-full text-muted transition hover:bg-card hover:text-text"
      >
        <Palette className="size-4" aria-hidden="true" />
      </button>
      {open && (
        <div onClick={(e) => e.stopPropagation()} className="page-in absolute right-0 mt-2 w-56 rounded-2xl border border-line bg-surface p-3 shadow-2xl">
          <p className="mb-2 px-1 text-xs font-medium uppercase tracking-widest text-muted">Cor de fundo</p>
          {THEMES.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => setTheme(t.id)}
              className={`flex w-full cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-left text-sm font-medium hover:bg-card ${theme === t.id ? 'text-text' : 'text-muted'}`}
            >
              <span className={`size-6 rounded-full border ${theme === t.id ? 'ring-2 ring-accent' : ''}`} style={{ background: t.color, borderColor: 'rgb(0 0 0 / 0.15)' }} />
              {t.name}
              {theme === t.id && <Check className="ml-auto size-4 text-accent" aria-hidden="true" />}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export function Avatar({ user, size = 28 }) {
  if (user?.photo) return <img src={user.photo} alt="" width={size} height={size} className="rounded-full" referrerPolicy="no-referrer" />
  return (
    <span className="grid place-items-center rounded-full bg-accent font-bold text-on-accent" style={{ width: size, height: size, fontSize: size * 0.42 }}>
      {(user?.name || user?.email || '?')[0].toUpperCase()}
    </span>
  )
}

function MenuItem({ icon: ItemIcon, danger = false, onClick, children }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full cursor-pointer items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm font-medium transition hover:bg-card ${danger ? 'text-danger' : 'text-text'}`}
    >
      <ItemIcon className={`size-4 ${danger ? '' : 'text-muted'}`} aria-hidden="true" />
      {children}
    </button>
  )
}

/** Pessoa logada: o nome; o menu tem o perfil, a conta e sair. */
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
        className="flex cursor-pointer items-center gap-2 rounded-full bg-card py-1 pl-1 pr-3 text-sm font-medium transition hover:brightness-125"
      >
        <Avatar user={user} />
        <span className="hidden max-w-[120px] truncate sm:inline">{(user.name || 'Conta').split(' ')[0]}</span>
      </button>
      {open && (
        <div onClick={(e) => e.stopPropagation()} className="page-in absolute right-0 mt-2 w-64 rounded-2xl border border-line bg-surface p-3 shadow-2xl">
          <div className="mb-3 flex items-center gap-3 px-1">
            <Avatar user={user} size={44} />
            <div className="min-w-0">
              <div className="truncate font-semibold">{user.name}</div>
              <div className="truncate text-xs text-muted">{user.email}</div>
            </div>
          </div>
          <MenuItem icon={Trophy} onClick={() => go('/perfil')}>
            Perfil e nível
          </MenuItem>
          <MenuItem icon={User} onClick={() => go('/conta')}>
            Conta
          </MenuItem>
          <div className="my-2 h-px bg-line" />
          <MenuItem icon={LogOut} danger onClick={logout}>
            Sair da conta
          </MenuItem>
        </div>
      )}
    </div>
  )
}

function TopBar() {
  const [open, setOpen] = useState(false)
  const { pathname } = useLocation()
  useEffect(() => setOpen(false), [pathname])
  return (
    <header className="sticky top-0 z-40 border-b border-line/60 bg-bg/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-3 px-4 sm:gap-4 sm:px-6">
        {/* No celular, o menu abre pelo botão (sem abas embaixo). */}
        <button
          type="button"
          onClick={() => setOpen(!open)}
          aria-label={open ? 'Fechar o menu' : 'Abrir o menu'}
          aria-expanded={open}
          className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-lg text-muted hover:bg-card hover:text-text md:hidden"
        >
          {open ? <X className="size-5" aria-hidden="true" /> : <Menu className="size-5" aria-hidden="true" />}
        </button>
        <NavLink to="/" aria-label="LifeLink, início" className="shrink-0">
          <Logo />
        </NavLink>
        <nav aria-label="Principal" className="hidden min-w-0 flex-1 items-center gap-1 overflow-x-auto md:flex">
          {SECTIONS.map(({ path, label, icon: NavIcon }) => (
            <NavLink key={path} to={path} end={path === '/'} className={navClass}>
              {({ isActive }) => (
                <>
                  <NavIcon className={`size-4 ${isActive ? 'text-accent' : ''}`} aria-hidden="true" />
                  <span className="hidden lg:inline">{label}</span>
                </>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-1.5">
          <a
            href={APK_URL}
            title="Baixar o app para Android"
            className="hidden items-center gap-2 rounded-full bg-card px-3 py-1.5 text-sm font-medium text-muted transition hover:text-text sm:flex"
          >
            <Smartphone className="size-4 text-success" aria-hidden="true" />
            <span className="hidden xl:inline">Baixar app</span>
          </a>
          <ThemePicker />
          <UserMenu />
        </div>
      </div>
      {open && (
        <nav aria-label="Principal" className="page-in border-t border-line/60 px-4 pb-4 pt-2 md:hidden">
          <ul className="flex flex-col gap-1">
            {SECTIONS.map(({ path, label, icon: NavIcon }) => (
              <li key={path}>
                <NavLink
                  to={path}
                  end={path === '/'}
                  className={({ isActive }) =>
                    `flex items-center gap-3 rounded-xl px-3 py-3 font-medium ${isActive ? 'bg-card text-text' : 'text-muted hover:bg-card hover:text-text'}`
                  }
                >
                  {({ isActive }) => (
                    <>
                      <NavIcon className={`size-5 ${isActive ? 'text-accent' : ''}`} aria-hidden="true" />
                      {label}
                    </>
                  )}
                </NavLink>
              </li>
            ))}
            <li>
              <a href={APK_URL} className="flex items-center gap-3 rounded-xl px-3 py-3 font-medium text-muted hover:bg-card hover:text-text">
                <Smartphone className="size-5 text-success" aria-hidden="true" /> Baixar o app para Android
              </a>
            </li>
          </ul>
        </nav>
      )}
    </header>
  )
}

/** O conteúdo da página (o contador ocupa a tela toda, sem rodapé nem abas). */
function Main({ children }) {
  const { pathname } = useLocation()
  const counter = pathname === '/contador'
  return (
    <>
      <main className={counter ? 'px-3 py-3 sm:px-6' : 'mx-auto max-w-7xl px-4 pb-12 pt-8 sm:px-6'}>{children}</main>
      {!counter && (
        <footer className="mx-auto max-w-7xl px-4 pb-8 text-xs text-muted sm:px-6">
          Dados e imagens das cartas:{' '}
          <a className="underline hover:text-text" href="https://scryfall.com" target="_blank" rel="noreferrer">
            Scryfall
          </a>
          . Decks oficiais:{' '}
          <a className="underline hover:text-text" href="https://mtgjson.com" target="_blank" rel="noreferrer">
            MTGJSON
          </a>
          . Magic: The Gathering é marca da Wizards of the Coast; este site não tem ligação com ela.
        </footer>
      )}
    </>
  )
}

/** A troca de página: sobe e aparece (sem corte seco). */
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
        <div className="login-float">
          <Logo size="lg" />
        </div>
        <div className="h-9 w-9 animate-spin rounded-full border-4 border-text/15 border-t-accent" />
      </div>
    </div>
  )
}

export default function App() {
  const { status } = useAuth()
  // A cor muda junto quando chega a da conta (ou o app troca).
  const theme = useTheme()
  useEffect(() => applyTheme(theme), [theme])
  // Sem estar logado, a primeira tela é sempre a de login (a mesma conta do
  // app). Sem Firebase configurado, o login fica desligado e o site abre direto.
  if (status === 'loading') return <Splash />
  if (status === 'signedOut' || status === 'needsNick') return <LoginPage />
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
            <Route path="/partidas" element={<MatchesPage />} />
            <Route path="/colecao" element={<CollectionPage />} />
            <Route path="/amigos" element={<FriendsPage />} />
            <Route path="/missoes" element={<MissionsPage />} />
            <Route path="/meus-decks" element={<MyDecksPage />} />
            <Route path="/perfil" element={<ProfilePage />} />
            <Route path="/conta" element={<AccountPage />} />
            <Route path="/regras" element={<RulesPage />} />
            <Route path="/d/:code" element={<SharedDeckPage />} />
            <Route path="*" element={<SearchPage />} />
          </Routes>
        </PageFade>
      </Main>
    </HashRouter>
  )
}
