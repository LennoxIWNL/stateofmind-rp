/**
 * The panel, the grid and the drag layer.
 *
 * Dragging is pointer events rather than react-dnd, which ox_inventory uses.
 * A grid of fixed cells needs a hit test and a ghost, and that is all; pulling
 * in a drag framework to get those would be a dependency for nothing. Pointer
 * capture also survives the cursor leaving the window, which HTML5 drag does
 * not, and a drag that ends outside the panel is exactly the drop-to-world case.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Inventory, InventoryType, Slot } from '../contract'
import { formatWeight, itemImage, labelOf, weightOf, countOf, type State } from '../state'
import type { MenuTarget } from './ContextMenu'

export type DragState = {
  from: { type: InventoryType; slot: number }
  item: Slot
  count: number
  x: number
  y: number
  image?: string
}

export type PanelCtx = {
  state: State
  swap: (
    from: { type: InventoryType; slot: number },
    to: { type: InventoryType | 'newdrop'; slot: number },
    count: number,
  ) => void
  useSlot: (slot: Slot) => void
  giveSlot: (slot: Slot) => void
  buy: (
    from: { type: InventoryType; slot: number },
    to: { type: InventoryType; slot: number },
    count: number,
  ) => void
  setMenu: (t: MenuTarget | null) => void
  drag: DragState | null
  setDrag: (d: DragState | null) => void
  isShopSide: boolean
  addToBasket: (line: { slot: number; name: string; count: number; price: number }) => void
}

/**
 * Categories, derived from the items actually present.
 *
 * ox_inventory's NUI item payload carries no category field of its own, so a
 * fixed ALL/WEAPONS/FOOD/HEALING list would be a lie the moment an item did not
 * fit. This reads `category` when the server supplies one (some do, ours may
 * later), falls back to the one grouping that IS derivable from the contract,
 * and renders only tabs that have something in them.
 */
function categoriesFor(inv: Inventory, items: State['items']): string[] {
  const found = new Set<string>()

  for (const slot of inv.items) {
    if (!slot.name) continue
    const data = items[slot.name] as (typeof items)[string] & { category?: string }

    if (data?.category) {
      found.add(data.category.toLowerCase())
      continue
    }

    // Weapons are keyed uppercase with a WEAPON_ prefix, and ammo carries an
    // ammoName. Both are in the contract, so both are safe to key off.
    if (slot.name.startsWith('WEAPON_')) found.add('weapons')
    else if (data?.ammoName) found.add('weapons')
  }

  return Array.from(found).sort()
}

function inCategory(slot: Slot, category: string, items: State['items']): boolean {
  if (category === 'all') return true
  if (!slot.name) return false

  const data = items[slot.name] as (typeof items)[string] & { category?: string }
  if (data?.category) return data.category.toLowerCase() === category

  if (category === 'weapons') return slot.name.startsWith('WEAPON_') || Boolean(data?.ammoName)
  return false
}

/** Rarity from the item's own data when present. Accent family plus neutrals. */
function rarityOf(slot: Slot, items: State['items']): string | undefined {
  if (!slot.name) return undefined
  const data = items[slot.name] as (typeof items)[string] & { rarity?: string }
  return data?.rarity?.toLowerCase()
}

// ---------------------------------------------------------------------------

type SlotCellProps = {
  slot: Slot
  invType: InventoryType
  ctx: PanelCtx
  onDragStart: (e: React.PointerEvent, slot: Slot, invType: InventoryType) => void
}

function SlotCell({ slot, invType, ctx, onDragStart }: SlotCellProps) {
  const { state } = ctx
  const image = itemImage(slot, state.items, state.imagepath)
  const label = labelOf(slot, state.items)
  const rarity = rarityOf(slot, state.items)
  const has = Boolean(slot.name)

  const durability = typeof slot.durability === 'number' ? slot.durability : undefined
  const price = (slot as any).price as number | undefined

  return (
    <div
      className={`som-slot ${has ? 'has-item' : ''} ${rarity ? `rarity-${rarity}` : ''}`}
      data-slot={slot.slot}
      data-invtype={invType}
      onPointerDown={(e) => {
        if (!has || e.button !== 0) return
        onDragStart(e, slot, invType)
      }}
      onContextMenu={(e) => {
        e.preventDefault()
        if (!has) return
        ctx.setMenu({ slot, invType, x: e.clientX, y: e.clientY })
      }}
      onDoubleClick={() => {
        if (!has) return
        if (ctx.isShopSide && invType !== 'player') return
        ctx.useSlot(slot)
      }}
    >
      {has && (
        <>
          <span className="som-slot__index">{slot.slot}</span>
          {(slot.count || 0) > 1 && <span className="som-slot__count">{slot.count}</span>}
          {price !== undefined && <span className="som-slot__price">${price}</span>}
          {image && <img className="som-slot__art" src={image} alt="" draggable={false} />}
          <span className="som-slot__label">{label}</span>
          {durability !== undefined && (
            <span className="som-slot__durability">
              <span style={{ width: `${Math.max(0, Math.min(100, durability))}%` }} />
            </span>
          )}
        </>
      )}
      {!has && <span className="som-slot__index som-slot__index--empty">{slot.slot}</span>}
    </div>
  )
}

// ---------------------------------------------------------------------------

type PanelProps = {
  side: 'primary' | 'secondary'
  inventory: Inventory
  ctx: PanelCtx
}

export function InventoryPanel({ side, inventory, ctx }: PanelProps) {
  const { state } = ctx
  const [category, setCategory] = useState('all')
  const dragRef = useRef<DragState | null>(null)
  const [ghost, setGhost] = useState<DragState | null>(null)

  const categories = useMemo(
    () => ['all', ...categoriesFor(inventory, state.items)],
    [inventory, state.items],
  )

  const weight = weightOf(inventory)
  const max = inventory.maxWeight || 0
  const pct = max > 0 ? Math.min(100, (weight / max) * 100) : 0

  const visibleSlots = useMemo(
    () => inventory.items.filter((s) => category === 'all' || inCategory(s, category, state.items)),
    [inventory.items, category, state.items],
  )

  const finishDrag = useCallback(
    (clientX: number, clientY: number) => {
      const drag = dragRef.current
      dragRef.current = null
      setGhost(null)
      ctx.setDrag(null)
      if (!drag) return

      const el = document.elementFromPoint(clientX, clientY) as HTMLElement | null

      // The discard zone. Only lit while dragging, and only meaningful from a
      // player inventory: ox_inventory refuses a newdrop in a vehicle or while
      // falling anyway, but asking for one from a shop is nonsense.
      const zone = el?.closest('.som-panel__drop') as HTMLElement | null
      if (zone && drag.from.type === 'player') {
        ctx.swap(drag.from, { type: 'newdrop', slot: 0 }, drag.count)
        return
      }

      const cell = el?.closest('.som-slot') as HTMLElement | null
      if (!cell) return

      const toSlot = Number(cell.dataset.slot)
      const toType = cell.dataset.invtype as InventoryType
      if (!toSlot || !toType) return
      if (toType === drag.from.type && toSlot === drag.from.slot) return

      // Dragging OUT of a shop stages a basket line rather than buying on the
      // spot. Checkout replays each line through ox_inventory's own buyItem, so
      // the server still prices and validates every one of them; the basket is
      // only a chance to change your mind before paying.
      if (drag.from.type === 'shop' || drag.from.type === 'crafting') {
        const price = (drag.item as { price?: number }).price
        ctx.addToBasket({
          slot: drag.from.slot,
          name: drag.item.name || '',
          count: drag.count,
          price: typeof price === 'number' ? price : 0,
        })
        return
      }

      ctx.swap(drag.from, { type: toType, slot: toSlot }, drag.count)
    },
    [ctx],
  )

  const onDragStart = useCallback(
    (e: React.PointerEvent, slot: Slot, invType: InventoryType) => {
      // Shift splits the stack in half, which is the stock behaviour and the
      // one shortcut players expect to already work.
      const total = slot.count || 1
      const count = e.shiftKey && total > 1 ? Math.floor(total / 2) : total

      const drag: DragState = {
        from: { type: invType, slot: slot.slot },
        item: slot,
        count,
        x: e.clientX,
        y: e.clientY,
        image: itemImage(slot, state.items, state.imagepath),
      }

      dragRef.current = drag
      setGhost(drag)
      ctx.setDrag(drag)
      ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
    },
    [ctx, state.imagepath, state.items],
  )

  useEffect(() => {
    const move = (e: PointerEvent) => {
      if (!dragRef.current) return
      const next = { ...dragRef.current, x: e.clientX, y: e.clientY }
      dragRef.current = next
      setGhost(next)
    }
    const up = (e: PointerEvent) => finishDrag(e.clientX, e.clientY)

    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
    return () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
    }
  }, [finishDrag])

  const isPlayer = inventory.type === 'player'
  const title = inventory.label || (isPlayer ? 'Inventory' : inventory.type)

  return (
    <section className={`som-panel som-panel--${side}`}>
      <header className="som-panel__head">
        <span className="som-panel__icon" aria-hidden="true" />
        <h2 className="som-panel__title">{title}</h2>
        <div className="som-panel__weight">
          <span className="som-panel__kg">{formatWeight(weight)}</span>
          <span className="som-panel__bar">
            {/* Segmented, not smooth. Reads as capacity rather than progress. */}
            {Array.from({ length: 12 }, (_, i) => (
              <i key={i} className={i < Math.round((pct / 100) * 12) ? 'is-on' : ''} />
            ))}
          </span>
          <span className="som-panel__kg">{max ? formatWeight(max) : ''}</span>
        </div>
      </header>

      {side === 'secondary' && (
        <div className="som-panel__sub">{countOf(inventory)} items</div>
      )}

      {categories.length > 1 && (
        <nav className="som-panel__cats">
          {categories.map((c) => (
            <button
              key={c}
              className={`som-pill ${category === c ? 'is-active' : ''}`}
              onClick={() => setCategory(c)}
            >
              {c}
            </button>
          ))}
        </nav>
      )}

      <div className="som-panel__grid">
        {visibleSlots.map((slot) => (
          <SlotCell
            key={slot.slot}
            slot={slot}
            invType={inventory.type}
            ctx={ctx}
            onDragStart={onDragStart}
          />
        ))}
      </div>

      {side === 'primary' && (
        <div className={`som-panel__drop ${ctx.drag ? 'is-live' : ''}`}>
          Drag items here to drop it
        </div>
      )}

      {ghost && (
        <div
          className="som-ghost"
          style={{ left: ghost.x, top: ghost.y }}
        >
          {ghost.image && <img src={ghost.image} alt="" draggable={false} />}
          {ghost.count > 1 && <span>{ghost.count}</span>}
        </div>
      )}
    </section>
  )
}
