import { Link } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import { deckList, useUserData } from '../lib/userData'
import { xpForNextLevel } from '../lib/xp'
import { BANNERS, BORDERS, select } from '../lib/missions'

function Stat({ label, value }) {
  return (
    <div className="rounded-xl bg-text/5 p-3 text-center">
      <div className="text-2xl font-black">{value}</div>
      <div className="text-xs text-muted">{label}</div>
    </div>
  )
}

/** Escolher banner, título, foto e contorno entre os desbloqueados (como no app). */
function Cosmetics({ profile }) {
  const unlocked = (list, fallback) => (Array.isArray(list) && list.length ? list : fallback)
  const banners = BANNERS.filter((b) => unlocked(profile.unlockedBanners, ['0']).includes(b.id))
  const borders = BORDERS.filter((b) => unlocked(profile.unlockedBorders, ['0']).includes(b.id))
  const chip = (on) => `rounded-full px-3 py-1.5 text-sm font-bold ${on ? 'bg-accent text-white' : 'bg-text/10 hover:bg-text/20'}`
  return (
    <div className="mt-5 space-y-4">
      <section>
        <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Banner</h2>
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
        <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Título</h2>
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
        <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Foto</h2>
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
        <h2 className="mb-2 text-xs font-black uppercase tracking-wide text-muted">Contorno</h2>
        <div className="flex flex-wrap gap-3">
          {borders.map((b) => (
            <button key={b.id} type="button" onClick={() => select('selectedBorder', b.id)} className="flex flex-col items-center gap-1 text-xs" title={b.name}>
              <span className={`h-12 w-12 rounded-full ${profile.selectedBorder === b.id ? 'ring-4 ring-accent' : ''}`} style={{ background: `conic-gradient(${b.colors.join(',')}, ${b.colors[0]})` }} />
              {b.name}
            </button>
          ))}
        </div>
      </section>
    </div>
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

  return (
    <div>
      <div
        className="flex items-center gap-4 rounded-2xl p-5 text-white"
        style={{ background: `linear-gradient(135deg, ${(BANNERS.find((b) => b.id === profile.selectedBanner) || BANNERS[0]).colors.join(',')})` }}
      >
        {profile.selectedAvatar ? (
          <img src={profile.selectedAvatar} alt="" className="h-24 w-24 rounded-full object-cover ring-4 ring-accent" />
        ) : (
          <div className="grid h-24 w-24 place-items-center rounded-full bg-text/10 text-4xl">🧙</div>
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-2xl font-black">{user?.name || 'Jogador'}</div>
          {profile.selectedTitle && <div className="font-bold text-amber-300">{profile.selectedTitle}</div>}
          <div className="mt-2 text-sm text-white/75">
            Nível <b className="text-white">{profile.level}</b> · {profile.xp} / {end} XP
          </div>
          <div className="mt-1 h-2.5 overflow-hidden rounded-full bg-white/20">
            <div className="h-full rounded-full bg-accent" style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        <Stat label="Decks" value={deckList(decks).length} />
        <Stat label="Decks criados" value={profile.statDecks} />
        <Stat label="Cartas adicionadas" value={profile.statCards} />
        <Stat label="Buscas" value={profile.statSearches} />
        <Stat label="Artes vistas" value={profile.statArts} />
        <Link to="/partidas" className="block hover:opacity-80">
          <Stat label="Partidas" value={profile.totalMatches} />
        </Link>
      </div>

      <Cosmetics profile={profile} />

      <div className="mt-4 flex flex-wrap gap-2">
        <Link to="/missoes" className="rounded-full bg-amber-400 px-4 py-2 text-sm font-bold text-black hover:brightness-110">
          🏅 Missões
        </Link>
        <Link to="/amigos" className="rounded-full bg-accent px-4 py-2 text-sm font-bold text-white hover:brightness-110">
          👥 Amigos
        </Link>
        <Link to="/partidas" className="rounded-full bg-text/10 px-4 py-2 text-sm font-bold hover:bg-text/20">
          📜 Partidas e estatísticas
        </Link>
      </div>

      <p className="mt-5 text-sm text-muted">
        Missão atual: seção {profile.tier}. As missões e as recompensas são as mesmas do app: o que você resgata aqui aparece lá.
      </p>
      {status !== 'signedIn' && status !== 'disabled' && (
        <p className="mt-3 rounded-xl bg-accent/10 p-3 text-sm text-accent">
          <Link to="/conta" className="font-bold underline">
            Entre na conta
          </Link>{' '}
          para usar o mesmo perfil e o mesmo nível do app.
        </p>
      )}
    </div>
  )
}
