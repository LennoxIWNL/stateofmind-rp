import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
import { Icon, PhoneContext, callApp, closePhone, type PhoneApi } from '@som/phone-sdk'
import { Bank } from './apps/Bank'
import { Contacts } from './apps/Contacts'
import { Messages } from './apps/Messages'
import { Phone } from './apps/Phone'
import { Properties } from './apps/Properties'
import { Settings } from './apps/Settings'
import { HostApp } from './HostApp'
import type { AppTile, Banner, OpenData } from './types'

/* Colour maths in JS: FiveM's CEF predates color-mix(), and a rejected
 * declaration falls back to nothing, which is what once turned every tile black. */
function parseHex(hex: string) {
  const h = String(hex || '').replace('#', '').trim()
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h
  const n = parseInt(full, 16)
  return Number.isNaN(n) || full.length !== 6
    ? { r: 255, g: 20, b: 147 }
    : { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}

const shade = (c: { r: number; g: number; b: number }, amount: number) => {
  const t = amount < 0 ? 0 : 255
  const p = Math.abs(amount)
  const mix = (v: number) => Math.round((t - v) * p + v)
  return `rgb(${mix(c.r)}, ${mix(c.g)}, ${mix(c.b)})`
}

const BANNER_HOLD_MS = 4900
type View = { kind: 'lock' } | { kind: 'home' } | { kind: 'app'; id: string; arg?: string }
interface CallInfo { state: string; number?: string; name?: string }

function useClock() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(t)
  }, [])
  return now
}

export function Shell() {
  const [shown, setShown] = useState(false)
  const [stowing, setStowing] = useState(false)
  const [data, setData] = useState<OpenData | null>(null)
  const [view, setView] = useState<View>({ kind: 'lock' })
  const [theme, setTheme] = useState('default')
  const [hasPasscode, setHasPasscode] = useState(false)
  const [badges, setBadges] = useState<Record<string, number>>({})
  const [banners, setBanners] = useState<Banner[]>([])
  const [toast, setToast] = useState<{ text: string; error: boolean } | null>(null)
  const [code, setCode] = useState('')
  const [lockMessage, setLockMessage] = useState('')
  const [call, setCall] = useState<CallInfo | null>(null)
  const nextBanner = useRef(1)
  const now = useClock()

  const time = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
  const date = now.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })

  const api = useMemo<PhoneApi>(() => ({
    toast: (text, isError = false) => {
      setToast({ text, error: isError })
      setTimeout(() => setToast(null), 3200)
    },
    home: () => setView({ kind: 'home' }),
    open: (id, arg) => setView({ kind: 'app', id, arg }),
    badge: (appId, count) => setBadges((b) => ({ ...b, [appId]: count })),
  }), [])

  const close = useCallback(() => {
    closePhone()
    setStowing(true)
    setTimeout(() => { setShown(false); setStowing(false) }, 300)
  }, [])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const msg = event.data
      if (!msg || typeof msg.action !== 'string') return

      if (msg.action === 'open') {
        const d = msg.data as OpenData
        setData(d)
        setTheme(d.settings?.theme || 'default')
        setHasPasscode(Boolean(d.hasPasscode))
        setBadges(d.badges || {})
        setCode('')
        setLockMessage('')
        setView({ kind: 'lock' })
        setStowing(false)
        setShown(true)
        return
      }

      if (msg.action === 'banner') {
        const id = nextBanner.current++
        const banner: Banner = { id, title: String(msg.title || 'Notification'), text: String(msg.text || ''), icon: String(msg.icon || 'bank') }
        // Three at a time, oldest first, so a burst cannot cover the screen.
        setBanners((b) => [...b, banner].slice(-3))
        setTimeout(() => setBanners((b) => b.filter((x) => x.id !== id)), BANNER_HOLD_MS)
        return
      }

      if (msg.action === 'call') {
        const c = msg.data as CallInfo
        setCall(c && c.state !== 'ended' ? c : null)
        return
      }

      if (msg.action === 'close') {
        setStowing(true)
        setTimeout(() => { setShown(false); setStowing(false) }, 300)
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!shown) return
      if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [shown, close])

  const accent = useMemo(() => {
    const hex = data?.themes?.[theme]?.accent || '#ff1493'
    const c = parseHex(hex)
    return {
      '--accent': hex,
      '--accent-soft': `rgba(${c.r}, ${c.g}, ${c.b}, 0.30)`,
      '--accent-wash': `rgba(${c.r}, ${c.g}, ${c.b}, 0.16)`,
      '--accent-deep': `rgba(${c.r}, ${c.g}, ${c.b}, 0.40)`,
    } as CSSProperties
  }, [data, theme])

  const unlock = async (entered?: string) => {
    if (!hasPasscode) return setView({ kind: 'home' })

    const res = await callApp('system', 'unlock', { passcode: entered ?? code })
    if (res.success) return setView({ kind: 'home' })

    setCode('')
    setLockMessage(res.error === 'Try again shortly' ? 'Locked out, try again shortly' : 'Wrong passcode')
  }

  const press = (d: string) => {
    if (code.length >= 4) return
    const next = code + d
    setCode(next)
    setLockMessage('')
    if (next.length === 4) void unlock(next)
  }

  const bannersOnly = !shown && banners.length > 0
  if (!shown && banners.length === 0) return null

  const tiles: AppTile[] = data?.apps || []
  const appLabel = view.kind === 'app' ? tiles.find((a) => a.id === view.id)?.label || view.id : ''

  const renderApp = (id: string, arg?: string) => {
    if (id === 'bank') return <Bank />
    if (id === 'contacts') return <Contacts />
    if (id === 'messages') return <Messages arg={arg} />
    if (id === 'phone') return <Phone arg={arg} />
    if (id === 'properties') return <Properties />
    if (id === 'settings') {
      return (
        <Settings
          themes={data?.themes || {}}
          theme={theme}
          hasPasscode={hasPasscode}
          onTheme={setTheme}
          onPasscode={setHasPasscode}
        />
      )
    }
    return <HostApp id={id} />
  }

  return (
    <PhoneContext.Provider value={api}>
      <div className={`root${bannersOnly ? ' is-banners-only' : ''}`} style={accent}>
        <div className={`phone${stowing ? ' is-stowing' : ''}`}>
          <div className="screen">
            <div className="island" aria-hidden="true" />

            <header className="statusbar">
              <span>{time}</span>
              <span className="statusbar__icons" aria-hidden="true" />
            </header>

            <main className="stage">
              {view.kind === 'lock' && (
                <section className="view lock" onClick={() => { if (!hasPasscode) void unlock() }}>
                  <div className="lock__time">{time}</div>
                  <div className="lock__date">{date}</div>
                  <div className="lock__spacer" />
                  <div className="lock__card">
                    <div className="lock__owner">{data?.owner}</div>
                    <div className="lock__number">{data?.number}</div>
                  </div>
                  {hasPasscode ? (
                    <div className="keypad" aria-label="Passcode">
                      <div className="lock__hint">{lockMessage || `${'•'.repeat(code.length)}${'◦'.repeat(4 - code.length)}`}</div>
                      <div className="keypad__keys">
                        {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((d) => (
                          <button key={d} type="button" className="key" onClick={(e) => { e.stopPropagation(); press(d) }}>{d}</button>
                        ))}
                        <span />
                        <button type="button" className="key" onClick={(e) => { e.stopPropagation(); press('0') }}>0</button>
                        <button type="button" className="key" aria-label="delete" onClick={(e) => { e.stopPropagation(); setCode((c) => c.slice(0, -1)) }}>⌫</button>
                      </div>
                    </div>
                  ) : (
                    <p className="lock__hint">Click to unlock</p>
                  )}
                </section>
              )}

              {view.kind === 'home' && (
                <section className="view home">
                  <div className="apps">
                    {tiles.map((app, i) => {
                      const c = parseHex(app.colour)
                      const count = badges[app.id]
                      return (
                        <button key={app.id} type="button" className="app" style={{ animationDelay: `${35 * i}ms` }}
                          onClick={() => setView({ kind: 'app', id: app.id })}>
                          <span className="app__icon" style={{ background: `linear-gradient(155deg, ${shade(c, 0.38)} 0%, rgb(${c.r}, ${c.g}, ${c.b}) 52%, ${shade(c, -0.28)} 100%)` }}>
                            <Icon name={app.icon} className="app__icon--glyph" stroke="#fff" />
                            {count ? <span className="app__badge">{count > 99 ? '99+' : count}</span> : null}
                          </span>
                          <span className="app__label">{app.label}</span>
                        </button>
                      )
                    })}
                  </div>
                </section>
              )}

              {view.kind === 'app' && (
                <section className="view app-view">
                  <div className="app-view__head">
                    <button className="back" type="button" onClick={() => setView({ kind: 'home' })}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M15 18l-6-6 6-6" /></svg>
                      Home
                    </button>
                    <h2 className="app-view__title">{appLabel}</h2>
                  </div>
                  {renderApp(view.id, view.arg)}
                </section>
              )}
            </main>

            {call && (
              <div className="callbar" role="status">
                <div className="callbar__who">
                  <div className="callbar__name">{call.name || call.number || 'Unknown'}</div>
                  <div className="callbar__state">{call.state === 'ringing' ? 'Incoming call' : call.state === 'dialling' ? 'Calling' : 'On a call'}</div>
                </div>
                {call.state === 'ringing' && (
                  <button type="button" className="btn btn--primary btn--sm" onClick={() => void callApp('phone', 'answer')}>Answer</button>
                )}
                <button type="button" className="btn btn--danger btn--sm" onClick={() => void callApp('phone', 'hangup')}>
                  {call.state === 'ringing' ? 'Decline' : 'End'}
                </button>
              </div>
            )}

            {toast && <div className={`toast${toast.error ? ' toast--error' : ''}`}>{toast.text}</div>}

            <div className="banners">
              {banners.map((b) => (
                <div key={b.id} className="banner">
                  <span className="banner__icon"><Icon name={b.icon} stroke="#fff" /></span>
                  <div className="banner__body">
                    <div className="banner__title">{b.title}</div>
                    <div className="banner__text">{b.text}</div>
                  </div>
                </div>
              ))}
            </div>

            <button className="homebar" type="button" aria-label="Home"
              onClick={() => { if (view.kind !== 'lock') setView({ kind: 'home' }) }} />
          </div>
        </div>
      </div>
    </PhoneContext.Provider>
  )
}
