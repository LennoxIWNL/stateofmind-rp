import { useCallback, useEffect, useState } from 'react'
import { Empty, Pill, Row, Section, callApp, callHousing, money, usePhone } from '@som/phone-sdk'

interface Nearby { slug: string; label: string; price: number; tier: string; realtorOnly?: boolean }
interface Owned { id: number; label: string; role: string }
interface Finance { property_id: number; remaining: number; instalment: number; missed_cycles: number }
interface Account { account: string; label: string }
interface Overview {
  success: boolean
  error?: string
  properties: Owned[]
  finance: Finance[]
  nearby: Nearby[]
  accounts: Account[]
  owned: number
  maxOwned: number
}

const ROLES: Record<string, string> = { owner: 'Owner', co_owner: 'Co-owner', tenant: 'Tenant' }

export function Properties() {
  const { toast } = usePhone()
  const [data, setData] = useState<Overview | null>(null)

  const load = useCallback(async () => setData(await callApp<Overview>('properties', 'overview')), [])
  useEffect(() => { void load() }, [load])

  if (!data) return <div className="app-view__body"><Empty icon="briefcase" text="Loading" /></div>
  if (!data.success) return <div className="app-view__body"><div className="empty">{data.error || 'Unavailable'}</div></div>

  const buy = async (p: Nearby, account: string) => {
    const res = await callHousing({ slug: p.slug, account })
    if (!res.success) return toast(String(res.error || 'Could not buy that'), true)
    toast(`${p.label} is yours`)
    await load()
  }

  const owed = new Map(data.finance.map((f) => [f.property_id, f]))
  const full = data.owned >= data.maxOwned

  return (
    <div className="app-view__body">
      {data.nearby.length > 0 && (
        <>
          <Section>For sale here</Section>
          <div className="list">
            {data.nearby.map((p) => (
              <Row
                key={p.slug}
                title={p.label}
                sub={`${money(p.price)} · ${p.tier}`}
                actions={
                  p.realtorOnly ? <Pill>Agent only</Pill>
                    : full ? <Pill>At your limit</Pill>
                    : data.accounts.length === 0 ? <Pill>No funds</Pill>
                    : data.accounts.map((a) => (
                      <button key={a.account} type="button" className="btn btn--primary btn--sm" onClick={() => buy(p, a.account)}>{a.label}</button>
                    ))
                }
              />
            ))}
          </div>
        </>
      )}

      <Section>Yours</Section>
      {data.properties.length === 0 ? <div className="empty">You do not hold any property.</div> : (
        <div className="list">
          {data.properties.map((p) => {
            const debt = owed.get(p.id)
            const sub = !debt ? 'Owned outright'
              : debt.missed_cycles > 0 ? `${money(debt.remaining)} outstanding · ${debt.missed_cycles} missed`
              : `${money(debt.remaining)} outstanding · ${money(debt.instalment)} each`
            return <Row key={p.id} title={p.label} sub={sub} actions={<Pill>{ROLES[p.role] || p.role}</Pill>} />
          })}
        </div>
      )}
    </div>
  )
}
