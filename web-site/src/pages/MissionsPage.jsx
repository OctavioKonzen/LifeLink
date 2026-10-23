import { useState } from 'react'
import { deckList, useUserData } from '../lib/userData'
import { claimMission, claimSection, isClaimed, missionsFor, tierReward } from '../lib/missions'
import { Modal, PageHeader, btnPrimary, panel } from '../components/ui'
import { Check, Sparkles } from 'lucide-react'

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
      <PageHeader title="Missões" description={`Seção ${tier}: as mesmas missões e recompensas do app.`} />
      <section className={`${panel} relative mb-6 overflow-hidden p-6`}>
        <div className="absolute -right-16 -top-16 size-48 rounded-full bg-accent/10 blur-3xl" aria-hidden="true" />
        <div className="relative mb-3 flex justify-between font-semibold">
          <span>Progresso da seção</span>
          <span className="text-accent">
            {done} / {missions.length}
          </span>
        </div>
        <div className="relative h-2 overflow-hidden rounded-full bg-card">
          <div className="h-full rounded-full bg-accent" style={{ width: `${(done / missions.length) * 100}%` }} />
        </div>
        <p className="relative mt-3 text-sm text-muted">Recompensa da seção: {next.type === 'title' ? `título "${next.name}"` : next.type === 'border' ? `contorno ${next.name}` : `foto de ${next.name}`}</p>
        {done === missions.length && (
          <button
            type="button"
            onClick={() => {
              setReward(next)
              claimSection()
            }}
            className={`${btnPrimary} relative mt-4 h-11 w-full`}
          >
            <Sparkles className="size-4" aria-hidden="true" /> Resgatar recompensa mítica!
          </button>
        )}
      </section>
      <ul className="flex flex-col gap-3">
        {missions.map((m, i) => {
          const claimed = isClaimed(profile, i)
          const ready = m.current >= m.target
          return (
            <li key={m.title} className={`${panel} flex items-center gap-4 p-5 ${ready && !claimed ? 'border-accent/60' : ''}`}>
              <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-card text-2xl">{m.icon}</span>
              <div className="min-w-0 flex-1">
                <p className={`font-semibold ${claimed ? 'text-muted line-through' : ''}`}>{m.title}</p>
                <p className="text-sm text-muted">{m.desc}</p>
                {!claimed && (
                  <>
                    <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-card">
                      <div className="h-full rounded-full bg-accent" style={{ width: `${Math.min(100, (m.current / m.target) * 100)}%` }} />
                    </div>
                    <p className="mt-1 text-xs text-muted">
                      {Math.min(m.current, m.target)} / {m.target}
                    </p>
                  </>
                )}
              </div>
              {claimed ? (
                <span className="flex items-center gap-1 text-sm font-semibold text-success">
                  <Check className="size-4" aria-hidden="true" /> Concluída
                </span>
              ) : ready ? (
                <button type="button" onClick={() => claimMission(i, m.xp)} className={btnPrimary}>
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
            <p className="font-display text-3xl font-bold text-accent">Seção concluída!</p>
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
