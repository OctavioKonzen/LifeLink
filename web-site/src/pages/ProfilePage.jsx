import { Link } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import { deckList, useUserData } from '../lib/userData'
import { xpForNextLevel } from '../lib/xp'
import { BANNERS, BORDERS, select } from '../lib/missions'
import { panel } from '../components/ui'
import { Eye, Hammer, Layers, PlusSquare, Search, Swords, Target, Users } from 'lucide-react'

function Stat({ icon: StatIcon, label, value }) {
  return (
    <div className={`${panel} flex h-full items-center gap-4 p-5`}>
      <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-card text-accent">
        <StatIcon className="size-5" aria-hidden="true" />
      </span>
      <div className="min-w-0">
        <dt className="truncate text-sm text-muted">{label}</dt>
        <dd className="text-xl font-semibold">{value}</dd>
      </div>
    </div>
  )
}

/** Escolher banner, título, foto e contorno entre os desbloqueados (como no app). */
function Cosmetics({ profile }) {
  const unlocked = (list, fallback) => (Array.isArray(list) && list.length ? list : fallback)
  const banners = BANNERS.filter((b) => unlocked(profile.unlockedBanners, ['0']).includes(b.id))
  const borders = BORDERS.filter((b) => unlocked(profile.unlockedBorders, ['0']).includes(b.id))
  const chip = (on) => `cursor-pointer rounded-lg px-3 py-1.5 text-sm font-medium ${on ? 'bg-accent text-on-accent' : 'bg-card text-muted hover:text-text'}`
  return (
    <section className={`${panel} space-y-6 p-6`}>
      <h2 className="text-lg font-semibold">Personalizar o perfil</h2>
      <section>
        <h3 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Banner</h3>
        <div className="flex flex-wrap gap-2">
          {banners.map((b) => (
            <button
              key={b.id}
              type="button"
              onClick={() => select('selectedBanner', b.id)}
              className={`h-12 w-28 rounded-xl text-xs font-bold text-white ${profile.selectedBanner === b.id ? 'ring-4 ring-accent' : ''}`}
              style={{ background: `linear-gradient(135deg, ${b.colors.join(',')})` }}
            >
              {b.name}
            </button>
          ))}
        </div>
        <p className="mt-1 text-xs text-muted">Vencer partidas no contador desbloqueia banners: na 1ª, 2ª, 4ª, 8ª, 16ª...</p>
      </section>
      <section>
        <h3 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Título</h3>
        {(profile.unlockedTitles || []).length === 0 ? (
          <p className="text-sm text-muted">Nenhum ainda: complete as seções das Missões para ganhar títulos.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {profile.unlockedTitles.map((t) => (
              <button key={t} type="button" onClick={() => select('selectedTitle', t)} className={chip(profile.selectedTitle === t)}>
                {t}
              </button>
            ))}
          </div>
        )}
      </section>
      <section>
        <h3 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Foto</h3>
        {(profile.unlockedAvatars || []).length === 0 ? (
          <p className="text-sm text-muted">Nenhuma ainda: complete as seções das Missões para ganhar fotos com artes de cartas.</p>
        ) : (
          <div className="flex flex-wrap gap-3">
            {profile.unlockedAvatars.map((url) => (
              <button key={url} type="button" onClick={() => select('selectedAvatar', url)} className={`rounded-full ${profile.selectedAvatar === url ? 'ring-4 ring-accent' : ''}`}>
                <img src={url} alt="" className="h-16 w-16 rounded-full object-cover" />
              </button>
            ))}
          </div>
        )}
      </section>
      <section>
        <h3 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Contorno</h3>
        <div className="flex flex-wrap gap-3">
          {borders.map((b) => (
            <button key={b.id} type="button" onClick={() => select('selectedBorder', b.id)} className="flex flex-col items-center gap-1 text-xs" title={b.name}>
              <span className={`h-12 w-12 rounded-full ${profile.selectedBorder === b.id ? 'ring-4 ring-accent' : ''}`} style={{ background: `conic-gradient(${b.colors.join(',')}, ${b.colors[0]})` }} />
              {b.name}
            </button>
          ))}
        </div>
      </section>
    </section>
  )
}

/** O mesmo perfil do app: nível, XP, título e contadores das missões. */
export default function ProfilePage() {
  const profile = useUserData((s) => s.profile)
  const decks = useUserData((s) => s.decks)
  const { status, user } = useAuth()
  const start = profile.level > 1 ? xpForNextLevel(profile.level - 1) : 0
  const end = xpForNextLevel(profile.level)
  const progress = Math.min(1, Math.max(0, (profile.xp - start) / (end - start)))

  const banner = (BANNERS.find((b) => b.id === profile.selectedBanner) || BANNERS[0]).colors
  const name = user?.name || 'Jogador'

  return (
    <div className="flex flex-col gap-8">
      <section className={`${panel} relative overflow-hidden rounded-3xl p-6 sm:p-8`}>
        {/* O banner escolhido, bem suave, e o brilho dourado. */}
        <div className="absolute inset-0 opacity-25" style={{ background: `linear-gradient(135deg, ${banner.join(',')})` }} aria-hidden="true" />
        <div className="absolute -right-20 -top-20 size-64 rounded-full bg-accent/10 blur-3xl" aria-hidden="true" />
        <div className="relative flex flex-col gap-6 sm:flex-row sm:items-center">
          {profile.selectedAvatar ? (
            <img src={profile.selectedAvatar} alt="" className="size-24 shrink-0 rounded-full object-cover ring-4 ring-accent/40" />
          ) : (
            <span className="grid size-24 shrink-0 place-items-center rounded-full bg-accent font-display text-4xl font-bold text-on-accent ring-4 ring-accent/20">
              {name[0].toUpperCase()}
            </span>
          )}
          <div className="flex min-w-0 flex-1 flex-col gap-3">
            <div>
              <h1 className="truncate font-display text-3xl font-bold">{name}</h1>
              <p className="text-muted">{profile.selectedTitle || 'Sem título ainda'}</p>
            </div>
            <div className="flex flex-col gap-2">
              <div className="flex justify-between text-sm">
                <span className="font-semibold text-accent">Nível {profile.level}</span>
                <span className="text-muted">
                  {profile.xp} / {end} XP
                </span>
              </div>
              <div className="h-2 overflow-hidden rounded-full bg-card">
                <div className="h-full rounded-full bg-accent" style={{ width: `${progress * 100}%` }} />
              </div>
            </div>
          </div>
        </div>
      </section>

      <dl className="grid grid-cols-2 gap-4 lg:grid-cols-3 xl:grid-cols-6">
        <Stat icon={Layers} label="Decks" value={deckList(decks).length} />
        <Stat icon={Hammer} label="Decks criados" value={profile.statDecks} />
        <Stat icon={PlusSquare} label="Cartas" value={profile.statCards} />
        <Stat icon={Search} label="Buscas" value={profile.statSearches} />
        <Stat icon={Eye} label="Artes vistas" value={profile.statArts} />
        <Link to="/partidas" className="block transition hover:opacity-80">
          <Stat icon={Swords} label="Partidas" value={profile.totalMatches} />
        </Link>
      </dl>

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          ['/missoes', Target, 'Missões', `Seção ${profile.tier}: recompensas iguais às do app.`],
          ['/amigos', Users, 'Amigos', 'Adicione pelo nick, veja decks e trocas.'],
          ['/partidas', Swords, 'Partidas', 'Histórico e estatísticas das partidas.'],
        ].map(([to, LinkIcon, title, text]) => (
          <Link key={to} to={to} className={`${panel} flex items-center gap-4 p-5 transition hover:border-accent/50`}>
            <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-accent/15 text-accent">
              <LinkIcon className="size-5" aria-hidden="true" />
            </span>
            <span className="min-w-0">
              <span className="block font-semibold">{title}</span>
              <span className="block text-sm text-muted">{text}</span>
            </span>
          </Link>
        ))}
      </div>

      <Cosmetics profile={profile} />

      {status !== 'signedIn' && status !== 'disabled' && (
        <p className="rounded-xl border border-accent/30 bg-accent/10 p-3 text-sm text-accent">
          <Link to="/conta" className="font-semibold underline">
            Entre na conta
          </Link>{' '}
          para usar o mesmo perfil e o mesmo nível do app.
        </p>
      )}
    </div>
  )
}
