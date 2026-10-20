import { HashRouter, NavLink, Route, Routes } from 'react-router-dom'
import SearchPage from './pages/SearchPage'
import PricesPage from './pages/PricesPage'
import DecksPage from './pages/DecksPage'
import LifeCounterPage from './pages/LifeCounterPage'

// Mesmas áreas do menu do app (home_screen.dart).
const SECTIONS = [
  { path: '/', label: 'Cartas', color: '#448aff' },
  { path: '/precos', label: 'Preços de hoje', color: '#ffc107' },
  { path: '/decks', label: 'Decks oficiais', color: '#69f0ae' },
  { path: '/contador', label: 'Contador de vida', color: '#ff5252' },
]

function Header() {
  return (
    <header className="sticky top-0 z-30 border-b border-line bg-bg/95 backdrop-blur">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
        <NavLink to="/" className="text-xl font-black tracking-wide">
          MAGIC
        </NavLink>
        <nav className="-mx-1 flex flex-1 gap-1 overflow-x-auto">
          {SECTIONS.map((s) => (
            <NavLink
              key={s.path}
              to={s.path}
              end={s.path === '/'}
              className={({ isActive }) =>
                `whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-bold transition ${
                  isActive ? 'text-black' : 'text-white/70 hover:bg-white/10 hover:text-white'
                }`
              }
              style={({ isActive }) => (isActive ? { background: s.color } : undefined)}
            >
              {s.label}
            </NavLink>
          ))}
        </nav>
      </div>
    </header>
  )
}

export default function App() {
  return (
    <HashRouter>
      <Header />
      <main className="mx-auto max-w-6xl px-4 py-5">
        <Routes>
          <Route path="/" element={<SearchPage />} />
          <Route path="/precos" element={<PricesPage />} />
          <Route path="/decks" element={<DecksPage />} />
          <Route path="/contador" element={<LifeCounterPage />} />
          <Route path="*" element={<SearchPage />} />
        </Routes>
      </main>
      <footer className="mx-auto max-w-6xl px-4 pb-8 pt-4 text-xs text-muted">
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
    </HashRouter>
  )
}
