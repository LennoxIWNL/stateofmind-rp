import { useEffect, useState, type FormEvent } from 'react'
import { type ActionResult, Empty, Row, Section, callApp, usePhone } from '@som/phone-sdk'

interface Service { job: string; label: string; onDuty?: number }

export function Services() {
  const { toast } = usePhone()
  const [services, setServices] = useState<Service[] | null>(null)
  const [message, setMessage] = useState('')

  useEffect(() => { void callApp<ActionResult & { services?: Service[] }>('services', 'list').then((r) => setServices(r.services || [])) }, [])

  const call = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('services', 'emergency', { message })
    if (!res.success) return toast(String(res.error || 'Could not send'), true)
    toast('Your call has been passed to dispatch')
    setMessage('')
  }

  return (
    <div className="app-view__body">
      <Section>Emergency</Section>
      <form className="form" onSubmit={call}>
        <input className="input" aria-label="What is happening" maxLength={140} placeholder="What is happening and where?" value={message} onChange={(e) => setMessage(e.target.value)} />
        <button className="btn btn--danger" type="submit">Call 911</button>
      </form>
      <Section>Available services</Section>
      {!services ? <Empty icon="dispatch" text="Loading" /> : services.length === 0 ? <Empty icon="dispatch" text="Nothing listed" /> : (
        <div className="list">
          {services.map((s) => <Row key={s.job} title={s.label} sub={s.onDuty === undefined ? undefined : s.onDuty > 0 ? `${s.onDuty} on duty` : 'Nobody on duty'} />)}
        </div>
      )}
    </div>
  )
}
