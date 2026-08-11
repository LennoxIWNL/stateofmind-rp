/**
 * The cursor-anchored slot menu.
 *
 * Every action here has a STOCK ox_inventory path behind it. Throw is
 * deliberately absent: it has no stock callback, so it needs a som-inventory
 * server event with its own validation before it can exist as a button. A
 * button that silently does nothing is worse than one that is not there yet.
 */

import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { InventoryType, Slot } from '../contract'
import { itemImage, labelOf, type State } from '../state'

export type MenuTarget = {
  slot: Slot
  invType: InventoryType
  x: number
  y: number
}

type Props = {
  target: MenuTarget
  state: State
  onClose: () => void
  onUse: (slot: Slot) => void
  onGive: (slot: Slot) => void
  onSwap: (
    from: { type: InventoryType; slot: number },
    to: { type: InventoryType | 'newdrop'; slot: number },
    count: number,
  ) => void
}

export function SlotContextMenu({ target, state, onClose, onUse, onGive, onSwap }: Props) {
  const { slot, invType } = target
  const total = slot.count || 1
  const [count, setCount] = useState(1)
  const ref = useRef<HTMLDivElement>(null)
  const [pos, setPos] = useState({ x: target.x, y: target.y })

  const data = state.items[slot.name || ''] as
    | (State['items'][string] & { rarity?: string })
    | undefined
  const rarity = data?.rarity

  // Anchored at the cursor, then pulled back inside the viewport. Without this
  // a right click near the bottom opens a menu half off screen.
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const box = el.getBoundingClientRect()
    const x = Math.min(target.x, window.innerWidth - box.width - 8)
    const y = Math.min(target.y, window.innerHeight - box.height - 8)
    setPos({ x: Math.max(8, x), y: Math.max(8, y) })
  }, [target.x, target.y])

  useEffect(() => {
    const away = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) onClose()
    }
    const key = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation()
        onClose()
      }
    }
    window.addEventListener('mousedown', away)
    window.addEventListener('keydown', key, true)
    return () => {
      window.removeEventListener('mousedown', away)
      window.removeEventListener('keydown', key, true)
    }
  }, [onClose])

  const act = (fn: () => void) => {
    fn()
    onClose()
  }

  const usable = data?.usable !== false && invType === 'player'

  return (
    <div ref={ref} className="som-menu" style={{ left: pos.x, top: pos.y }}>
      <header className="som-menu__head">
        {(() => {
          const image = itemImage(slot, state.items, state.imagepath)
          return image ? <img src={image} alt="" draggable={false} /> : null
        })()}
        <span className="som-menu__name">{labelOf(slot, state.items)}</span>
        {rarity && <span className={`som-menu__rarity rarity-${rarity}`}>{rarity}</span>}
      </header>

      {total > 1 && (
        <div className="som-menu__stepper">
          <button onClick={() => setCount((c) => Math.max(1, c - 1))} aria-label="less">
            &minus;
          </button>
          <input
            type="number"
            value={count}
            min={1}
            max={total}
            onChange={(e) => {
              const n = Number(e.target.value)
              setCount(Number.isFinite(n) ? Math.max(1, Math.min(total, Math.floor(n))) : 1)
            }}
          />
          <button onClick={() => setCount((c) => Math.min(total, c + 1))} aria-label="more">
            +
          </button>
        </div>
      )}

      <div className="som-menu__actions">
        {usable && (
          <button className="som-btn som-btn--use" onClick={() => act(() => onUse(slot))}>
            Use
          </button>
        )}
        {invType === 'player' && (
          <button
            className="som-btn som-btn--drop"
            onClick={() => act(() => onSwap({ type: invType, slot: slot.slot }, { type: 'newdrop', slot: 0 }, count))}
          >
            Drop
          </button>
        )}
        {total > 1 && (
          <button
            className="som-btn som-btn--split"
            onClick={() =>
              act(() => {
                // A split needs an empty slot to land in. Finding it here rather
                // than asking the server for "anywhere" keeps the one swapItems
                // path doing all the work.
                const inv = state.left
                const empty = inv.items.find((s) => !s.name)
                if (!empty) return
                onSwap({ type: invType, slot: slot.slot }, { type: invType, slot: empty.slot }, count)
              })
            }
          >
            Split
          </button>
        )}
        {invType === 'player' && (
          <button className="som-btn som-btn--give" onClick={() => act(() => onGive(slot))}>
            Give
          </button>
        )}
      </div>
    </div>
  )
}
