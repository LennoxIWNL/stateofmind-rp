/**
 * The detached hotbar strip.
 *
 * Shown while the inventory is CLOSED, toggled by ox_inventory's `toggleHotbar`
 * message. It is a readout, not an interaction: ox_inventory binds the number
 * keys itself on the Lua side, so making these clickable would be a second way
 * to do the same thing that could disagree with the first.
 */

import { itemImage, labelOf, type State } from '../state'

const HOTBAR_SLOTS = 5

export function Hotbar({ open, state }: { open: boolean; state: State }) {
  if (!open || !state.ready) return null

  const slots = state.left.items.slice(0, HOTBAR_SLOTS)

  return (
    <div className="som-hotbar">
      {slots.map((slot, i) => {
        const image = itemImage(slot, state.items, state.imagepath)
        return (
          <div key={slot.slot ?? i} className={`som-hotbar__slot ${slot.name ? 'has-item' : ''}`}>
            <span className="som-hotbar__key">{i + 1}</span>
            {(slot.count || 0) > 1 && <span className="som-hotbar__count">{slot.count}</span>}
            {image && <img src={image} alt="" draggable={false} />}
            {slot.name && <span className="som-hotbar__label">{labelOf(slot, state.items)}</span>}
          </div>
        )
      })}
    </div>
  )
}
