/**
 * The hover tooltip.
 *
 * Description and the extra rows come from `getItemData`, one of the stock
 * eleven callbacks, fetched on hover rather than held for every item in the
 * grid. `displayMetadata` supplies the label for any metadata key the server
 * wants shown, so a key with no label is skipped rather than printed raw.
 */

import { useEffect, useState } from 'react'
import { fetchNui } from '@som/ui-kit'
import { OUTBOUND, type ItemData, type Slot } from '../contract'
import { formatWeight, itemImage, labelOf, type State } from '../state'

type Props = {
  slot: Slot
  state: State
  x: number
  y: number
}

export function Tooltip({ slot, state, x, y }: Props) {
  const [data, setData] = useState<ItemData | null>(null)

  useEffect(() => {
    let alive = true
    if (!slot.name) return

    void fetchNui<ItemData | null>(OUTBOUND.getItemData, { name: slot.name }, null).then((res) => {
      if (alive) setData(res)
    })

    return () => {
      alive = false
    }
  }, [slot.name])

  if (!slot.name) return null

  const image = itemImage(slot, state.items, state.imagepath)
  const description = data?.description || state.items[slot.name]?.description

  // Only metadata the server named in displayMetadata. Anything else is an
  // internal key and printing it raw is how a UI leaks implementation.
  const rows = state.metadata
    .map(({ metadata, value }) => ({
      label: value,
      value: slot.metadata ? slot.metadata[metadata] : undefined,
    }))
    .filter((r) => r.value !== undefined && r.value !== null && r.value !== '')

  const style: React.CSSProperties = {
    left: Math.min(x + 14, window.innerWidth - 230),
    top: Math.min(y + 14, window.innerHeight - 180),
  }

  return (
    <div className="som-tooltip" style={style}>
      <header className="som-tooltip__head">
        {image && <img src={image} alt="" draggable={false} />}
        <div>
          <div className="som-tooltip__name">{labelOf(slot, state.items)}</div>
          <div className="som-tooltip__weight">{formatWeight((slot.weight || 0))}</div>
        </div>
      </header>

      {description && <p className="som-tooltip__desc">{description}</p>}

      {typeof slot.durability === 'number' && (
        <div className="som-tooltip__row">
          <span>Durability</span>
          <span>{Math.round(slot.durability)}%</span>
        </div>
      )}

      {rows.map((r) => (
        <div key={r.label} className="som-tooltip__row">
          <span>{r.label}</span>
          <span>{String(r.value)}</span>
        </div>
      ))}
    </div>
  )
}
