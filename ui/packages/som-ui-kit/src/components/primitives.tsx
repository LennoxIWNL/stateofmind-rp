import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from 'react'

/**
 * The pieces every SOM screen is built from.
 *
 * Styling lives in styles/kit.css and reads var(--som-*) only. Nothing here
 * carries a literal colour, because som-assets/tokens.css is the one place the
 * palette is allowed to exist and a hex in a component is how a second one
 * starts.
 */

const cx = (...parts: (string | false | null | undefined)[]) =>
  parts.filter(Boolean).join(' ')

/* --- Card ---------------------------------------------------------------- */

// `title` is omitted from the DOM attributes on purpose. HTML's title is a
// string tooltip; ours is a rendered head row, and leaving both in place makes
// the two silently fight over the same prop name.
export interface CardProps extends Omit<HTMLAttributes<HTMLDivElement>, 'title'> {
  /** Head row. Rendered only when given, so a bare card has no empty bar. */
  title?: ReactNode
  /** Sits opposite the title. Counts, weights, a close button. */
  aside?: ReactNode
  footer?: ReactNode
  /** Removes the body padding, for a card whose child manages its own. */
  flush?: boolean
  children?: ReactNode
}

export function Card({ title, aside, footer, flush, className, children, ...rest }: CardProps) {
  return (
    <div className={cx('som-card', className)} {...rest}>
      {(title || aside) && (
        <header className="som-card__head">
          {title && <div className="som-card__title">{title}</div>}
          {aside && <div className="som-card__aside">{aside}</div>}
        </header>
      )}

      <div className={cx('som-card__body', flush && 'is-flush')}>{children}</div>

      {footer && <footer className="som-card__foot">{footer}</footer>}
    </div>
  )
}

/* --- Button -------------------------------------------------------------- */

export type ButtonVariant = 'primary' | 'ghost' | 'danger' | 'success' | 'warning'

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  /** Fills its container. For footers and paired confirm/cancel rows. */
  block?: boolean
  /** Shows a busy state AND disables. One prop, so the two cannot disagree. */
  busy?: boolean
  children?: ReactNode
}

export function Button({
  variant = 'primary',
  block,
  busy,
  className,
  disabled,
  children,
  type,
  ...rest
}: ButtonProps) {
  return (
    <button
      // Inside a form an unspecified button submits it. Every button in a NUI
      // is an action, never a submit, so this is defaulted rather than left to
      // each call site to remember.
      type={type ?? 'button'}
      className={cx('som-btn', `som-btn--${variant}`, block && 'is-block', busy && 'is-busy', className)}
      disabled={disabled || busy}
      {...rest}
    >
      {children}
    </button>
  )
}

/* --- IconTile ------------------------------------------------------------ */

export interface IconTileProps extends Omit<HTMLAttributes<HTMLDivElement>, 'title'> {
  /** Image URL. Falls back to the initial of `label` if it fails to load. */
  src?: string
  label: string
  /** Corner badge, typically a stack count. Hidden when 1 or absent. */
  count?: number
  /** Opposite corner. Price on a shop tile, slot index in an inventory. */
  corner?: ReactNode
  /** Rarity or state ring. Maps to a border colour in kit.css. */
  tone?: 'common' | 'rare' | 'epic' | 'legendary' | 'blocked'
  selected?: boolean
}

export function IconTile({
  src,
  label,
  count,
  corner,
  tone = 'common',
  selected,
  className,
  ...rest
}: IconTileProps) {
  return (
    <div
      className={cx('som-tile', `som-tile--${tone}`, selected && 'is-selected', className)}
      {...rest}
    >
      <div className="som-tile__art">
        {src ? (
          <img
            src={src}
            alt=""
            loading="lazy"
            // A missing icon is common while the icon pass is incomplete. The
            // tile falls back to a letter rather than a broken-image glyph,
            // which reads as deliberate instead of as a bug.
            onError={(event) => {
              const img = event.currentTarget
              img.style.display = 'none'
              img.parentElement?.classList.add('is-blank')
            }}
          />
        ) : null}
        <span className="som-tile__initial">{label.replace(/^weapon_|^ammo-/, '').charAt(0).toUpperCase()}</span>
      </div>

      {corner !== undefined && corner !== null && <span className="som-tile__corner">{corner}</span>}
      {typeof count === 'number' && count > 1 && <span className="som-tile__count">{count}</span>}

      <span className="som-tile__label">{label}</span>
    </div>
  )
}

/* --- StatusBadge --------------------------------------------------------- */

export type StatusTone = 'neutral' | 'accent' | 'success' | 'warning' | 'danger'

export interface StatusBadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: StatusTone
  /** Renders a leading dot. For live states: on duty, in progress, active. */
  dot?: boolean
  children?: ReactNode
}

export function StatusBadge({ tone = 'neutral', dot, className, children, ...rest }: StatusBadgeProps) {
  return (
    <span className={cx('som-badge', `som-badge--${tone}`, className)} {...rest}>
      {dot && <i className="som-badge__dot" />}
      {children}
    </span>
  )
}

/* --- Meter --------------------------------------------------------------- */

export interface MeterProps extends HTMLAttributes<HTMLDivElement> {
  value: number
  max?: number
  tone?: StatusTone
  /**
   * Draws the bar as discrete blocks rather than one fill, matching the weight
   * readout in the inventory reference. Segments make a small change visible;
   * a smooth bar at 84% and 86% looks identical.
   */
  segments?: number
}

export function Meter({ value, max = 100, tone = 'accent', segments, className, ...rest }: MeterProps) {
  const pct = Math.max(0, Math.min(100, (value / (max || 1)) * 100))

  return (
    <div className={cx('som-meter', `som-meter--${tone}`, className)} {...rest}>
      {segments ? (
        <div className="som-meter__segments">
          {Array.from({ length: segments }, (_, i) => (
            <i key={i} className={cx('som-meter__seg', (i + 1) / segments <= pct / 100 && 'is-on')} />
          ))}
        </div>
      ) : (
        <div className="som-meter__track">
          <div className="som-meter__fill" style={{ width: `${pct}%` }} />
        </div>
      )}
    </div>
  )
}
