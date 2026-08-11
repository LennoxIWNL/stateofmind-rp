import { useCallback, useEffect, useState } from 'react'
import { StatusBadge, useNuiEvent, debugData, type StatusTone } from '@som/ui-kit'

/**
 * The dispatch feed.
 *
 * Render only, and deliberately PASSIVE: it never takes NUI focus and nothing
 * on it is clickable. An alert feed that stole the mouse every time a shot was
 * fired somewhere in the city would be unusable, so the waypoint verb lives on
 * a keybind in Lua instead of on a button here.
 *
 * The call shape is som-dispatch's existing record, unchanged. That record's
 * fields are dictated by ps-mdt's renderer rather than chosen, which is why
 * several of them are duplicated under two names (code/dispatchCode,
 * message/dispatchMessage). This reads the SOM-side name and falls back to the
 * ps-mdt one, so it keeps working whichever survives.
 */

export interface DispatchCall {
  id: number
  priority?: number
  code?: string
  dispatchCode?: string
  message?: string
  dispatchMessage?: string
  /** Milliseconds. ps-mdt compares it against Date.now(). */
  time?: number
  street?: string
  firstStreet?: string
  plate?: string
  model?: string
  weapon?: string
  information?: string
}

interface FeedItem {
  call: DispatchCall
  /** Local arrival time, used for the exit timer rather than call.time. */
  receivedAt: number
  leaving: boolean
}

/** How long a card stays before it starts leaving. */
const HOLD_MS = 14000
/** Must outlast the CSS exit, or the node is pulled mid-animation. */
const LEAVE_MS = 320
/**
 * Cap the stack. A burst of gunfire alerts would otherwise cover the screen,
 * which is the same failure som-ui's notification stack already had to fix.
 */
const MAX_VISIBLE = 4

const PRIORITY_TONE: Record<number, StatusTone> = {
  1: 'danger',
  2: 'warning',
  3: 'neutral',
}

/** Relative time, recomputed on a tick so a card ages while it sits there. */
function ago(ms: number | undefined, now: number): string {
  if (!ms) return 'just now'

  const seconds = Math.max(0, Math.round((now - ms) / 1000))
  if (seconds < 10) return 'just now'
  if (seconds < 60) return `${seconds}s ago`

  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m ago`

  return `${Math.floor(minutes / 60)}h ago`
}

export function App() {
  const [items, setItems] = useState<FeedItem[]>([])
  const [now, setNow] = useState(() => Date.now())

  // One shared clock rather than a timer per card. Thirty cards each holding
  // their own interval is thirty wakeups a second for a label that changes
  // once a minute.
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(timer)
  }, [])

  const dismiss = useCallback((id: number, receivedAt: number) => {
    setItems((prev) =>
      prev.map((item) =>
        item.call.id === id && item.receivedAt === receivedAt ? { ...item, leaving: true } : item,
      ),
    )

    setTimeout(() => {
      setItems((prev) =>
        prev.filter((item) => !(item.call.id === id && item.receivedAt === receivedAt)),
      )
    }, LEAVE_MS)
  }, [])

  useNuiEvent<DispatchCall>('dispatch:call', (call) => {
    if (!call || typeof call.id !== 'number') return

    const receivedAt = Date.now()

    setItems((prev) => {
      // A duplicate id means the same call re-sent (a reconnect, a resource
      // restart). Replace rather than stack, or one incident reads as several.
      const withoutDuplicate = prev.filter((item) => item.call.id !== call.id)
      const next = [...withoutDuplicate, { call, receivedAt, leaving: false }]

      return next.slice(-MAX_VISIBLE)
    })

    setTimeout(() => dismiss(call.id, receivedAt), HOLD_MS)
  })

  // Cleared by Lua when the player goes off duty, so an officer who clocks out
  // does not keep a wall of calls on screen.
  useNuiEvent('dispatch:clear', () => setItems([]))

  return (
    <div className="som-root dispatch">
      {items.map((item) => {
        const { call } = item
        const priority = call.priority ?? 2
        const street = call.street || call.firstStreet
        const detail = [call.plate, call.model, call.weapon].filter(Boolean).join(' · ')

        return (
          <article
            key={`${call.id}-${item.receivedAt}`}
            className={`dispatch__card${item.leaving ? ' is-leaving' : ''}`}
            data-priority={priority}
          >
            <header className="dispatch__head">
              <span className="dispatch__code som-num">{call.code || call.dispatchCode || '10-00'}</span>
              <span className="dispatch__label">{call.message || call.dispatchMessage || 'Call'}</span>
              <StatusBadge tone={PRIORITY_TONE[priority] ?? 'neutral'} dot>
                P{priority}
              </StatusBadge>
            </header>

            <div className="dispatch__meta">
              {street && <span className="dispatch__street">{street}</span>}
              <span className="dispatch__time som-num">{ago(call.time, now)}</span>
            </div>

            {detail && <div className="dispatch__detail">{detail}</div>}
            {call.information && <div className="dispatch__info">{call.information}</div>}
          </article>
        )
      })}
    </div>
  )
}

// Inert in game. Only fires when the page is opened in a browser.
debugData<DispatchCall>([
  {
    action: 'dispatch:call',
    data: {
      id: 1,
      priority: 1,
      code: '10-13',
      message: 'Shots Fired',
      time: Date.now(),
      street: 'Vespucci Boulevard',
      weapon: 'Pistol',
    },
  },
])
