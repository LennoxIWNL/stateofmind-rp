import type { InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from 'react'

const cx = (...parts: (string | false | null | undefined)[]) =>
  parts.filter(Boolean).join(' ')

/* --- Input --------------------------------------------------------------- */

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
  /** Shown under the field. Replaces the hint when present. */
  error?: string
  hint?: string
}

export function Input({ label, error, hint, className, id, ...rest }: InputProps) {
  const fieldId = id ?? (label ? `som-in-${label.replace(/\s+/g, '-').toLowerCase()}` : undefined)

  return (
    <label className={cx('som-field', error && 'has-error', className)} htmlFor={fieldId}>
      {label && <span className="som-field__label">{label}</span>}
      <input id={fieldId} className="som-field__input" {...rest} />
      {(error || hint) && <span className="som-field__note">{error ?? hint}</span>}
    </label>
  )
}

/* --- Select -------------------------------------------------------------- */

export interface SelectOption {
  value: string
  label: string
}

export interface SelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'children'> {
  label?: string
  options: SelectOption[]
  /** Leading blank option. Absent means the first real option is preselected. */
  placeholder?: string
}

export function Select({ label, options, placeholder, className, id, ...rest }: SelectProps) {
  const fieldId = id ?? (label ? `som-sel-${label.replace(/\s+/g, '-').toLowerCase()}` : undefined)

  return (
    <label className={cx('som-field', className)} htmlFor={fieldId}>
      {label && <span className="som-field__label">{label}</span>}

      <select id={fieldId} className="som-field__input som-field__select" {...rest}>
        {placeholder && <option value="">{placeholder}</option>}
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  )
}

/* --- Stepper ------------------------------------------------------------- */

export interface StepperProps {
  value: number
  onChange: (next: number) => void
  min?: number
  max?: number
  disabled?: boolean
}

/**
 * Quantity control, as on the basket rows in the shop reference.
 *
 * Clamped HERE as well as wherever it is read. A stepper is a convenience and
 * never an authority: the server re-derives every quantity it acts on, and a
 * clamp in a component is only there so the number on screen makes sense.
 */
export function Stepper({ value, onChange, min = 1, max = 9999, disabled }: StepperProps) {
  const clamp = (next: number) => Math.max(min, Math.min(max, next))

  return (
    <div className={cx('som-stepper', disabled && 'is-disabled')}>
      <button
        type="button"
        className="som-stepper__btn"
        aria-label="Decrease"
        disabled={disabled || value <= min}
        onClick={() => onChange(clamp(value - 1))}
      >
        &#8722;
      </button>

      <input
        className="som-stepper__value"
        type="text"
        inputMode="numeric"
        value={value}
        disabled={disabled}
        onChange={(event) => {
          // Strip anything non-numeric rather than rejecting the keystroke, so
          // pasting "12kg" gives 12 instead of clearing the field.
          const digits = event.target.value.replace(/\D/g, '')
          onChange(clamp(digits === '' ? min : Number(digits)))
        }}
      />

      <button
        type="button"
        className="som-stepper__btn"
        aria-label="Increase"
        disabled={disabled || value >= max}
        onClick={() => onChange(clamp(value + 1))}
      >
        +
      </button>
    </div>
  )
}

/* --- Tabs ---------------------------------------------------------------- */

export interface TabItem {
  id: string
  label: ReactNode
  /** Trailing count, as on a category filter showing how many match. */
  count?: number
}

export interface TabsProps {
  items: TabItem[]
  active: string
  onChange: (id: string) => void
  /** 'pill' for category filters, 'line' for a panel's top-level sections. */
  variant?: 'pill' | 'line'
}

export function Tabs({ items, active, onChange, variant = 'pill' }: TabsProps) {
  return (
    <div className={cx('som-tabs', `som-tabs--${variant}`)} role="tablist">
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          role="tab"
          aria-selected={item.id === active}
          className={cx('som-tabs__tab', item.id === active && 'is-active')}
          onClick={() => onChange(item.id)}
        >
          {item.label}
          {typeof item.count === 'number' && <span className="som-tabs__count">{item.count}</span>}
        </button>
      ))}
    </div>
  )
}
