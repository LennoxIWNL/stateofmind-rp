/**
 * The shop basket.
 *
 * NO BRIDGE NEEDED, and worth saying why: the basket is staging, not state.
 * Lines live on the page until checkout, and checkout replays them through
 * ox_inventory's OWN `buyItem` callback one line at a time. So the server
 * re-prices and re-validates every line exactly as it does for a stock
 * drag-to-buy, and a doctored basket buys a doctored total of nothing.
 *
 * Cart persistence across a close/reopen is deliberately NOT here. That belongs
 * in the client Lua keyed by shop id, per the plan, because the page is
 * destroyed when the inventory closes.
 */

import { useMemo } from 'react'
import type { InventoryType, Slot } from '../contract'
import { itemImage, labelOf, type State } from '../state'

export type BasketLine = {
  /** Slot in the SHOP inventory. The server re-reads price from it. */
  slot: number
  name: string
  count: number
  price: number
}

type Props = {
  lines: BasketLine[]
  state: State
  shopType: InventoryType
  onChange: (lines: BasketLine[]) => void
  onCheckout: (account: 'bank' | 'cash') => void
}

export function Basket({ lines, state, onChange, onCheckout }: Props) {
  const total = useMemo(
    () => lines.reduce((sum, l) => sum + l.price * l.count, 0),
    [lines],
  )

  const weight = useMemo(
    () =>
      lines.reduce((sum, l) => {
        const shopSlot = findShopSlot(state, l.slot)
        return sum + (shopSlot?.weight || 0) * l.count
      }, 0),
    [lines, state],
  )

  if (!lines.length) return null

  const setCount = (slot: number, count: number) => {
    if (count < 1) {
      onChange(lines.filter((l) => l.slot !== slot))
      return
    }
    onChange(lines.map((l) => (l.slot === slot ? { ...l, count } : l)))
  }

  return (
    <section className="som-panel som-basket">
      <header className="som-panel__head">
        <span className="som-panel__icon" aria-hidden="true" />
        <h2 className="som-panel__title">Basket</h2>
        <div className="som-panel__weight">
          <span className="som-panel__kg">{(weight / 1000).toFixed(1)}KG</span>
        </div>
      </header>

      <div className="som-panel__sub">{lines.length} items</div>

      <div className="som-basket__rows">
        {lines.map((line) => {
          const shopSlot = findShopSlot(state, line.slot)
          const image = itemImage(shopSlot, state.items, state.imagepath)

          return (
            <div key={line.slot} className="som-basket__row">
              {image && <img src={image} alt="" draggable={false} />}
              <span className="som-basket__name">
                {shopSlot ? labelOf(shopSlot, state.items) : line.name}
              </span>

              <div className="som-basket__stepper">
                <button onClick={() => setCount(line.slot, line.count - 1)} aria-label="less">
                  &minus;
                </button>
                <span>{line.count}</span>
                <button onClick={() => setCount(line.slot, line.count + 1)} aria-label="more">
                  +
                </button>
              </div>

              <span className="som-basket__price">${line.price * line.count}</span>

              <button
                className="som-basket__remove"
                onClick={() => onChange(lines.filter((l) => l.slot !== line.slot))}
                aria-label="remove"
              >
                &times;
              </button>
            </div>
          )
        })}
      </div>

      <div className="som-basket__total">
        <span>Total</span>
        <strong>${total}</strong>
      </div>

      {/*
        Two buttons rather than a toggle, which is the reference's choice and
        the right one: it makes the account that pays an explicit decision taken
        at the moment of paying, rather than a setting that was true earlier.
      */}
      <div className="som-basket__pay">
        <button className="som-btn som-btn--use" onClick={() => onCheckout('bank')}>
          Bank
        </button>
        <button className="som-btn som-btn--give" onClick={() => onCheckout('cash')}>
          Cash
        </button>
      </div>

      <button className="som-btn som-btn--drop som-basket__clear" onClick={() => onChange([])}>
        Clear
      </button>
    </section>
  )
}

function findShopSlot(state: State, slot: number): Slot | undefined {
  if (!state.right) return undefined
  return state.right.items.find((s) => s.slot === slot)
}
