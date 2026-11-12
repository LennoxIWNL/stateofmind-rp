import { useEffect, useState } from 'react'
import { Empty, Icon, Row, callApp, digits, usePhone } from '@som/phone-sdk'

interface Recent { number: string; name?: string | null; status: string; outgoing: boolean; created_at: string }

export function Phone({ arg }: { arg?: string }) {
  const { toast } = usePhone()
  const [number, setNumber] = useState(digits(arg || ''))
  const [recents, setRecents] = useState<Recent[] | null>(null)

  useEffect(() => { void callApp<{ recents?: Recent[] }>('phone', 'recents').then((r) => setRecents(r.recents || [])) }, [])

  const dial = async (n: string) => {
    const res = await callApp('phone', 'dial', { number: n })
    if (!res.success) toast(String(res.error || 'Could not call'), true)
  }

  return (
    <div className="app-view__body">
      <div className="dialer">
        <div className="dialer__number" aria-live="polite">{number || 'Enter a number'}</div>
        <div className="keypad__keys">
          {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((d) => (
            <button key={d} type="button" className="key" onClick={() => setNumber((n) => (n.length < 7 ? n + d : n))}>{d}</button>
          ))}
          <button type="button" className="key" aria-label="delete" onClick={() => setNumber((n) => n.slice(0, -1))}>⌫</button>
          <button type="button" className="key" onClick={() => setNumber((n) => (n.length < 7 ? n + '0' : n))}>0</button>
          <button type="button" className="key key--call" aria-label="Call" disabled={number.length !== 7} onClick={() => dial(number)}><Icon name="phone" /></button>
        </div>
      </div>

      <h3 className="section">Recent</h3>
      {!recents ? <Empty icon="phone" text="Loading" /> : recents.length === 0 ? <Empty icon="phone" text="No calls yet" /> : (
        <div className="list">
          {recents.map((r, i) => (
            <button key={i} type="button" className="rowbtn" onClick={() => setNumber(digits(r.number))}>
              <Row title={r.name || r.number} sub={`${r.outgoing ? 'Outgoing' : 'Incoming'} · ${r.status}`} />
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
