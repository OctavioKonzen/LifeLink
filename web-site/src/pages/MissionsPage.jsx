import { useState } from 'react'
import { deckList, useUserData } from '../lib/userData'
import { claimMission, claimSection, isClaimed, missionsFor, tierReward } from '../lib/missions'
import { Modal } from '../components/ui'

// As missões do app (arena_missions_screen.dart), agora também no site.
export default function MissionsPage() {
  const profile = useUserData((s) => s.profile)
  const decks = useUserData((s) => s.decks)
  const [reward, setReward] = useState(null)
  const tier = profile.tier || 1
  const missions = missionsFor(profile, deckList(decks).length)
  const done = missions.filter((_, i) => isClaimed(profile, i)).length
  const next = tierReward(tier)

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="mb-4 text-2xl font-black">Missões · Rank {tier}</h1>
      <section className="mb-4 rounded-2xl bg-card p-4 shadow">
        <div className="mb-2 flex justify-between font-bold">
          <span>Progresso da seção</span>
          <span className="text-accent">
            {done} / {missions.length}
          </span>
        </div>
        <div className="h-3 overflow-hidden rounded-full bg-text/10">
          <div className="h-full rounded-full bg-accent" style={{ width: `${(done / missions.length) * 100}%` }} />
        </div>
        <p className="mt-2 text-sm text-muted">Recompensa da seção: {next.type === 'title' ? `título "${next.name}"` : next.type === 'border' ? `contorno ${next.name}` : `foto de ${next.name}`}</p>
        {done === missions.length && (
          <button
            type="button"
            onClick={() => {
              setReward(next)
              claimSection()
            }}
            className="mt-3 w-full rounded-full bg-amber-400 py-3 font-black text-black hover:brightness-110"
          >
            Resgatar recompensa mítica!
          </button>
        )}
      </section>
      <ul className="space-y-3">
        {missions.map((m, i) => {
          const claimed = isClaimed(profile, i)
          const ready = m.current >= m.target
          return (
            <li key={m.title} className={`flex items-center gap-4 rounded-2xl bg-card p-4 shadow ${ready && !claimed ? 'ring-2 ring-amber-400' : ''}`}>
              <span className="text-3xl">{m.icon}</span>
              <div className="min-w-0 flex-1">
                <p className="font-black">{m.title}</p>
                <p className="text-sm text-muted">{m.desc}</p>
                {!claimed && (
                  <>
                    <div className="mt-2 h-2 overflow-hidden rounded-full bg-text/10">
                      <div className="h-full rounded-full bg-emerald-400" style={{ width: `${Math.min(100, (m.current / m.target) * 100)}%` }} />
                    </div>
                    <p className="mt-1 text-xs text-muted">
                      {Math.min(m.current, m.target)} / {m.target}
                    </p>
                  </>
                )}
              </div>
              {claimed ? (
                <span className="text-sm font-bold text-emerald-400">Concluído ✓</span>
              ) : ready ? (
                <button type="button" onClick={() => claimMission(i, m.xp)} className="rounded-full bg-accent px-4 py-2 text-sm font-bold text-white">
                  Resgatar {m.xp} XP
                </button>
              ) : (
                <span className="text-sm text-muted">{m.xp} XP</span>
              )}
            </li>
          )
        })}
      </ul>
      {reward && (
        <Modal onClose={() => setReward(null)}>
          <div className="text-center">
            <p className="text-2xl font-black text-amber-400">Seção concluída!</p>
            {reward.type === 'avatar' && <img src={reward.imageUrl} alt="" className="mx-auto mt-4 h-28 w-28 rounded-full object-cover" />}
            {reward.type === 'border' && <div className="mx-auto mt-4 h-28 w-28 rounded-full" style={{ background: `conic-gradient(${reward.colors.join(',')})` }} />}
            {reward.type === 'title' && <p className="mt-4 text-5xl">🎖</p>}
            <p className="mt-4 font-bold">Desbloqueado: {reward.name}</p>
          </div>
        </Modal>
      )}
    </div>
  )
}
