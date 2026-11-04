import { useCallback, useEffect, useState } from 'react'
import { Empty, Row, Section, callApp, usePhone } from '@som/phone-sdk'

/**
 * Shows an app that another resource ships. The resource answers `view` with
 * plain data (no markup, no script); every tap is sent back to it as an action
 * and checked there. Text is set through React, never as HTML.
 */
interface HostRow { title: string; sub?: string; action?: string; payload?: Record<string, unknown> }
interface HostButton { label: string; action: string; payload?: Record<string, unknown>; danger?: boolean }
interface HostView {
  sections?: { title?: string; rows?: HostRow[] }[]
  buttons?: HostButton[]
  empty?: string
}

export function HostApp({ id }: { id: string }) {
  const { toast } = usePhone()
  const [view, setView] = useState<HostView | null>(null)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const res = await callApp<{ success: boolean; error?: string; view?: HostView }>(id, 'view')
    if (!res.success || !res.view) return setError(String(res.error || 'Not available'))
    setError('')
    setView(res.view)
  }, [id])

  useEffect(() => { void load() }, [load])

  const act = async (action: string, payload?: Record<string, unknown>) => {
    const res = await callApp(id, action, payload || {})
    if (!res.success) toast(String(res.error || 'Could not do that'), true)
    await load()
  }

  if (error) return <div className="app-view__body"><div className="empty">{error}</div></div>
  if (!view) return <div className="app-view__body"><Empty icon="briefcase" text="Loading" /></div>

  const sections = view.sections || []
  const any = sections.some((s) => (s.rows || []).length > 0)

  return (
    <div className="app-view__body">
      {!any && <div className="empty">{view.empty || 'Nothing here'}</div>}
      {sections.map((s, i) => (
        <div key={i}>
          {s.title ? <Section>{s.title}</Section> : null}
          <div className="list">
            {(s.rows || []).map((r, j) => (
              <Row
                key={j}
                title={String(r.title).slice(0, 120)}
                sub={r.sub ? String(r.sub).slice(0, 160) : undefined}
                actions={r.action ? <button type="button" className="btn btn--primary btn--sm" onClick={() => act(r.action as string, r.payload)}>Open</button> : undefined}
              />
            ))}
          </div>
        </div>
      ))}
      {(view.buttons || []).map((b, i) => (
        <button key={i} type="button" className={`btn ${b.danger ? 'btn--danger' : 'btn--primary'}`} onClick={() => act(b.action, b.payload)}>{String(b.label).slice(0, 40)}</button>
      ))}
    </div>
  )
}
