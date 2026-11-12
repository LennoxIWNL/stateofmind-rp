import type { ReactNode } from 'react'
import { Icon } from './icons'

export const money = (n: number | string | undefined | null) => `$${Number(n || 0).toLocaleString('en-US')}`

export const digits = (s: string) => String(s || '').replace(/\D/g, '')

export function Empty({ icon, text }: { icon: string; text: string }) {
  return (
    <div className="empty">
      <Icon name={icon} />
      <div>{text}</div>
    </div>
  )
}

export function Section({ children }: { children: ReactNode }) {
  return <h3 className="section">{children}</h3>
}

export function Pill({ children }: { children: ReactNode }) {
  return <span className="pill">{children}</span>
}

export interface RowProps {
  title: string
  sub?: string
  glyph?: ReactNode
  amount?: ReactNode
  actions?: ReactNode
}

export function Row({ title, sub, glyph, amount, actions }: RowProps) {
  return (
    <div className="row">
      {glyph}
      <div className="row__main">
        <div className="row__title">{title}</div>
        {sub ? <div className="row__sub">{sub}</div> : null}
      </div>
      {amount}
      {actions ? <div className="row__actions">{actions}</div> : null}
    </div>
  )
}

export interface SegmentProps {
  tabs: { id: string; label: string; count?: number }[]
  active: string
  onChange: (id: string) => void
}

export function Segment({ tabs, active, onChange }: SegmentProps) {
  return (
    <nav className="segment">
      {tabs.map((t) => (
        <button
          key={t.id}
          type="button"
          className={`segment__item${t.id === active ? ' is-active' : ''}`}
          onClick={() => onChange(t.id)}
        >
          {t.label}
          {t.count ? <span className="pill">{t.count}</span> : null}
        </button>
      ))}
    </nav>
  )
}
