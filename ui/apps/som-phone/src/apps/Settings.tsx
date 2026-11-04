import { useState } from 'react'
import { Icon, Section, callApp, digits, usePhone } from '@som/phone-sdk'
import type { Theme } from '../types'

export interface SettingsProps {
  themes: Record<string, Theme>
  theme: string
  hasPasscode: boolean
  onTheme: (id: string) => void
  onPasscode: (set: boolean) => void
}

export function Settings({ themes, theme, hasPasscode, onTheme, onPasscode }: SettingsProps) {
  const { toast } = usePhone()
  const [code, setCode] = useState('')

  const pick = async (id: string) => {
    const res = await callApp('settings', 'setTheme', { theme: id })
    if (!res.success) return toast(String(res.error || 'That theme is not unlocked'), true)
    onTheme(id)
  }

  const savePasscode = async () => {
    const res = await callApp('settings', 'setPasscode', { passcode: code })
    if (!res.success) return toast(String(res.error || 'Could not set it'), true)
    setCode('')
    onPasscode(true)
    toast('Passcode set')
  }

  const removePasscode = async () => {
    const res = await callApp('settings', 'setPasscode', {})
    if (!res.success) return toast(String(res.error || 'Could not remove it'), true)
    onPasscode(false)
    toast('Passcode removed')
  }

  return (
    <div className="app-view__body">
      <Section>Appearance</Section>
      <div className="list">
        {Object.entries(themes).map(([id, t]) => (
          <button key={id} type="button" className="theme" onClick={() => pick(id)}>
            <span className="theme__swatch" style={{ background: t.accent }} />
            <span className="theme__label">{t.label}</span>
            {id === theme ? <span className="theme__check"><Icon name="check" /></span>
              : t.perk ? <span className="theme__lock">Supporter</span> : null}
          </button>
        ))}
      </div>
      <p className="hint">Supporter themes unlock with a Patreon tier. Everyone keeps State of Mind.</p>

      <Section>Passcode</Section>
      <div className="form">
        <div className="field">
          <label className="field__label" htmlFor="passcode">{hasPasscode ? 'Change passcode' : 'Set a passcode'}</label>
          <input id="passcode" className="input input--mono" inputMode="numeric" maxLength={4} autoComplete="off" placeholder="0000"
            value={code} onChange={(e) => setCode(digits(e.target.value))} />
        </div>
        <button className="btn btn--primary" type="button" disabled={code.length !== 4} onClick={savePasscode}>Save</button>
        {hasPasscode && <button className="btn btn--danger" type="button" onClick={removePasscode}>Remove passcode</button>}
      </div>
    </div>
  )
}
