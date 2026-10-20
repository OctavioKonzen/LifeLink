import { Link } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import { deckList, useUserData } from '../lib/userData'
import { xpForNextLevel } from '../lib/xp'

function Stat({ label, value }) {
  return (
    <div className="rounded-xl bg-text/5 p-3 text-center">
      <div className="text-2xl font-black">{value}</div>
      <div className="text-xs text-muted">{label}</div>
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
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center gap-4 rounded-2xl bg-gradient-to-br from-card to-surface p-5">
        {profile.selectedAvatar ? (
          <img src={profile.selectedAvatar} alt="" className="h-24 w-24 rounded-full object-cover ring-4 ring-accent" />
        ) : (
          <div className="grid h-24 w-24 place-items-center rounded-full bg-text/10 text-4xl">🧙</div>
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-2xl font-black">{user?.name || 'Jogador'}</div>
          {profile.selectedTitle && <div className="font-bold text-amber-300">{profile.selectedTitle}</div>}
          <div className="mt-2 text-sm text-muted">
            Nível <b className="text-text">{profile.level}</b> · {profile.xp} / {end} XP
          </div>
          <div className="mt-1 h-2.5 overflow-hidden rounded-full bg-text/10">
            <div className="h-full rounded-full bg-accent" style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <Stat label="Decks" value={deckList(decks).length} />
        <Stat label="Decks criados" value={profile.statDecks} />
        <Stat label="Cartas adicionadas" value={profile.statCards} />
        <Stat label="Buscas" value={profile.statSearches} />
        <Stat label="Artes vistas" value={profile.statArts} />
        <Stat label="Partidas" value={profile.totalMatches} />
      </div>

      <p className="mt-5 text-sm text-muted">
        Missão atual: seção {profile.tier}. As missões e as recompensas (avatares, bordas, banners e títulos) são resgatadas no app; o que você
        desbloqueia lá aparece aqui.
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
