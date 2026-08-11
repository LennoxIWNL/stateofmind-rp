import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react'

const cx = (...parts: (string | false | null | undefined)[]) =>
  parts.filter(Boolean).join(' ')

/* --- Modal --------------------------------------------------------------- */

export interface ModalProps {
  open: boolean
  onClose: () => void
  title?: ReactNode
  footer?: ReactNode
  /**
   * A modal that must be answered rather than dismissed. Blocks the backdrop
   * click and the Escape key. Enforce the same rule wherever the decision
   * actually lives too: a page is not a place to keep a rule.
   */
  dismissable?: boolean
  children?: ReactNode
}

export function Modal({ open, onClose, title, footer, dismissable = true, children }: ModalProps) {
  useEffect(() => {
    if (!open || !dismissable) return

    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose()
    }

    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, dismissable, onClose])

  if (!open) return null

  return (
    <div className="som-modal">
      <div className="som-modal__backdrop" onClick={dismissable ? onClose : undefined} />

      <div className="som-modal__panel" role="dialog" aria-modal="true">
        {title && (
          <header className="som-modal__head">
            <div className="som-modal__title">{title}</div>
            {dismissable && (
              <button className="som-modal__close" type="button" aria-label="Close" onClick={onClose}>
                &#10005;
              </button>
            )}
          </header>
        )}

        <div className="som-modal__body">{children}</div>

        {footer && <footer className="som-modal__foot">{footer}</footer>}
      </div>
    </div>
  )
}

/* --- Drawer -------------------------------------------------------------- */

export interface DrawerProps {
  open: boolean
  /**
   * Which edge it enters from. The inventory reference is the reason this
   * exists: the player's own panel comes from the right and a secondary
   * container (trunk, stash, dumpster) comes from the left, so the direction
   * itself tells you whose inventory you are looking at.
   */
  side?: 'left' | 'right'
  title?: ReactNode
  aside?: ReactNode
  footer?: ReactNode
  children?: ReactNode
}

export function Drawer({ open, side = 'right', title, aside, footer, children }: DrawerProps) {
  // Kept mounted through the exit animation. Unmounting on !open would make it
  // vanish rather than leave, which is the specific cheapness the phone rework
  // was about.
  const [mounted, setMounted] = useState(open)

  useEffect(() => {
    if (open) return setMounted(true)

    const timer = setTimeout(() => setMounted(false), 260)
    return () => clearTimeout(timer)
  }, [open])

  if (!mounted) return null

  return (
    <aside className={cx('som-drawer', `som-drawer--${side}`, open ? 'is-open' : 'is-leaving')}>
      {(title || aside) && (
        <header className="som-drawer__head">
          {title && <div className="som-drawer__title">{title}</div>}
          {aside && <div className="som-drawer__aside">{aside}</div>}
        </header>
      )}

      <div className="som-drawer__body">{children}</div>

      {footer && <footer className="som-drawer__foot">{footer}</footer>}
    </aside>
  )
}

/* --- ContextMenu --------------------------------------------------------- */

export interface ContextMenuItem {
  label: string
  onSelect: () => void
  tone?: 'default' | 'accent' | 'danger' | 'success' | 'warning'
  disabled?: boolean
}

export interface ContextMenuProps {
  /** Cursor position. Null closes it. */
  at: { x: number; y: number } | null
  onClose: () => void
  items: ContextMenuItem[]
  /** Rendered above the items. The quantity stepper goes here. */
  header?: ReactNode
}

export function ContextMenu({ at, onClose, items, header }: ContextMenuProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [pos, setPos] = useState({ x: 0, y: 0 })

  /**
   * Clamped to the viewport AFTER measuring, which is why this is a layout
   * effect rather than an effect: a menu opened near the right or bottom edge
   * would otherwise paint off screen for a frame, or stay there entirely.
   */
  useLayoutEffect(() => {
    if (!at || !ref.current) return

    const box = ref.current.getBoundingClientRect()
    const margin = 8

    setPos({
      x: Math.min(at.x, window.innerWidth - box.width - margin),
      y: Math.min(at.y, window.innerHeight - box.height - margin),
    })
  }, [at])

  useEffect(() => {
    if (!at) return

    const onDown = (event: MouseEvent) => {
      if (ref.current?.contains(event.target as Node)) return
      onClose()
    }

    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose()
    }

    // Capture, so a click that opens another menu closes this one first rather
    // than leaving two on screen.
    window.addEventListener('mousedown', onDown, true)
    window.addEventListener('keydown', onKey)

    return () => {
      window.removeEventListener('mousedown', onDown, true)
      window.removeEventListener('keydown', onKey)
    }
  }, [at, onClose])

  if (!at) return null

  return (
    <div ref={ref} className="som-ctx" style={{ left: pos.x, top: pos.y }}>
      {header && <div className="som-ctx__head">{header}</div>}

      {items.map((item, index) => (
        <button
          key={`${item.label}-${index}`}
          type="button"
          className={cx('som-ctx__item', `som-ctx__item--${item.tone ?? 'default'}`)}
          disabled={item.disabled}
          onClick={() => {
            item.onSelect()
            onClose()
          }}
        >
          {item.label}
        </button>
      ))}
    </div>
  )
}
