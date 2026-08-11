/**
 * Item pickup/loss toasts, from ox_inventory's `itemNotify`.
 *
 * The payload is a TUPLE, `[item, text, count?]`, not an object. That is
 * unusual enough that it is worth the reminder here as well as in contract.ts.
 */

import type { SlotWithItem } from '../contract'
import { itemImage, labelOf, type State } from '../state'

export type Notification = {
  id: number
  item: SlotWithItem
  text: string
  count?: number
}

export function ItemNotifications({ list, state }: { list: Notification[]; state: State }) {
  if (!list.length) return null

  return (
    <div className="som-notify">
      {list.map((n) => {
        const image = itemImage(n.item, state.items, state.imagepath)
        return (
          <div key={n.id} className="som-notify__row">
            {image && <img src={image} alt="" draggable={false} />}
            <div className="som-notify__text">
              <span className="som-notify__verb">{n.text}</span>
              <span className="som-notify__name">
                {labelOf(n.item, state.items)}
                {n.count && n.count > 1 ? ` x${n.count}` : ''}
              </span>
            </div>
          </div>
        )
      })}
    </div>
  )
}
