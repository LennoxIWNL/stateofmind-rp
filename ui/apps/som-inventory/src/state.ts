/**
 * Inventory state.
 *
 * A plain reducer rather than Redux, which ox_inventory uses. There is one
 * store, one consumer tree and no async middleware worth the dependency.
 *
 * The rule this file exists to enforce: **the server is the authority and the
 * next `refreshSlots` is the truth.** Local edits here are optimistic rendering
 * so a drag feels instant. They are never treated as fact, and any of them can
 * be overwritten by the next message without ceremony.
 */

import { useCallback, useReducer } from 'react'
import type {
  Inventory,
  InventoryType,
  ItemData,
  ItemsPayload,
  Slot,
  InboundRefreshSlots,
  InboundSetupInventory,
} from './contract'

export type State = {
  left: Inventory
  right: Inventory | null
  /** Item catalogue from `init`, keyed exactly as ox_inventory keys it. */
  items: Record<string, ItemData>
  locale: Record<string, string>
  imagepath: string
  /** Extra rows the tooltip shows, from `displayMetadata`. */
  metadata: Array<{ metadata: string; value: string }>
  ready: boolean
}

const EMPTY: Inventory = { id: '', type: 'player', slots: 0, items: [] }

export const initialState: State = {
  left: EMPTY,
  right: null,
  items: {},
  locale: {},
  imagepath: 'nui://ox_inventory/web/images',
  metadata: [],
  ready: false,
}

type Action =
  | { type: 'init'; locale: Record<string, string>; items: Record<string, ItemData>; left: Inventory; imagepath: string }
  | { type: 'setup'; data: InboundSetupInventory }
  | { type: 'refresh'; data: InboundRefreshSlots }
  | { type: 'metadata'; data: Array<{ metadata: string; value: string }> }
  | { type: 'localSwap'; from: { type: InventoryType; slot: number }; to: { type: InventoryType; slot: number }; count: number }

/** Grows a sparse item list to `slots`, so the grid can render empty cells. */
function pad(inv: Inventory): Inventory {
  const items: Slot[] = []
  for (let i = 1; i <= inv.slots; i++) items[i - 1] = { slot: i }
  for (const item of inv.items || []) {
    if (item && item.slot >= 1 && item.slot <= inv.slots) items[item.slot - 1] = item
  }
  return { ...inv, items }
}

const sideOf = (state: State, type: InventoryType): 'left' | 'right' | null => {
  if (state.left && state.left.type === type) return 'left'
  if (state.right && state.right.type === type) return 'right'
  // A container/shop always renders right, a player always left. Falling back
  // on that rather than returning null keeps a refresh for an inventory whose
  // type string we have not seen from being dropped silently.
  return type === 'player' ? 'left' : 'right'
}

function applyItemsPayload(state: State, payload: ItemsPayload): State {
  const side = sideOf(state, payload.inventory)
  if (!side) return state

  const inv = state[side]
  if (!inv) return state

  const items = inv.items.slice()
  const index = payload.item.slot - 1
  if (index < 0 || index >= items.length) return state

  // A slot emptied server side arrives as { slot } with no name. Writing it
  // through verbatim is what clears the cell.
  items[index] = payload.item

  return { ...state, [side]: { ...inv, items } } as State
}

export function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'init':
      return {
        ...state,
        locale: action.locale || {},
        items: action.items || {},
        imagepath: action.imagepath || state.imagepath,
        left: pad(action.left),
        ready: true,
      }

    case 'setup': {
      const next = { ...state }
      if (action.data.leftInventory) next.left = pad(action.data.leftInventory)
      // An explicit null/undefined right is how a container closes. Only clear
      // it when the message actually carried the key, or opening the inventory
      // on foot would wipe a trunk that is still open.
      if ('rightInventory' in action.data) {
        next.right = action.data.rightInventory ? pad(action.data.rightInventory) : null
      }
      return next
    }

    case 'refresh': {
      let next = state

      // THE DUAL SHAPE. `items` is one payload or an array of them, and
      // client.lua sends both forms from two different call sites. Treating it
      // as always-an-array drops every single-item refresh on the floor.
      const raw = action.data.items
      if (raw) {
        const list = Array.isArray(raw) ? raw : [raw]
        for (const payload of list) {
          if (payload && payload.item) next = applyItemsPayload(next, payload)
        }
      }

      // Weight can change without any slot changing, when a container's
      // capacity is re-declared.
      const wd = action.data.weightData
      if (wd) {
        if (next.left && next.left.id === wd.inventoryId) {
          next = { ...next, left: { ...next.left, maxWeight: wd.maxWeight } }
        } else if (next.right && next.right.id === wd.inventoryId) {
          next = { ...next, right: { ...next.right, maxWeight: wd.maxWeight } }
        }
      }

      return next
    }

    case 'metadata':
      return { ...state, metadata: action.data || [] }

    case 'localSwap': {
      // Optimistic only. The server decides, and its `refreshSlots` overwrites
      // whatever this produced. It exists so a drag lands under the cursor
      // immediately instead of after a round trip.
      const fromSide = sideOf(state, action.from.type)
      const toSide = sideOf(state, action.to.type)
      if (!fromSide || !toSide) return state

      const fromInv = state[fromSide]
      const toInv = state[toSide]
      if (!fromInv || !toInv) return state

      const fromItems = fromInv.items.slice()
      const toItems = fromSide === toSide ? fromItems : toInv.items.slice()

      const a = fromItems[action.from.slot - 1]
      const b = toItems[action.to.slot - 1]
      if (!a || !a.name) return state

      const moving = Math.min(action.count, a.count || 0)
      const partial = moving < (a.count || 0)

      if (partial && (!b || !b.name)) {
        fromItems[action.from.slot - 1] = { ...a, count: (a.count || 0) - moving }
        toItems[action.to.slot - 1] = { ...a, slot: action.to.slot, count: moving }
      } else if (b && b.name === a.name) {
        fromItems[action.from.slot - 1] = { slot: action.from.slot }
        toItems[action.to.slot - 1] = { ...b, count: (b.count || 0) + moving }
      } else {
        fromItems[action.from.slot - 1] = b ? { ...b, slot: action.from.slot } : { slot: action.from.slot }
        toItems[action.to.slot - 1] = { ...a, slot: action.to.slot }
      }

      const next = { ...state }
      next[fromSide] = { ...fromInv, items: fromItems } as Inventory
      if (fromSide !== toSide) next[toSide] = { ...toInv, items: toItems } as Inventory
      return next
    }

    default:
      return state
  }
}

export function useInventoryState() {
  const [state, dispatch] = useReducer(reducer, initialState)
  return { state, dispatch: useCallback(dispatch, []) }
}

// ---------------------------------------------------------------------------
// Derived helpers
// ---------------------------------------------------------------------------

export const weightOf = (inv: Inventory | null): number =>
  !inv ? 0 : inv.items.reduce((sum, s) => sum + (s.weight || 0), 0)

/** Grams to a display string. ox_inventory stores weight as integer grams. */
export const formatWeight = (grams: number): string => `${(grams / 1000).toFixed(1)}KG`

export const countOf = (inv: Inventory | null): number =>
  !inv ? 0 : inv.items.reduce((n, s) => n + (s.name ? 1 : 0), 0)

/**
 * The image URL for a slot.
 *
 * Mirrors ox_inventory/web/src/helpers/index.ts:140-162 exactly, INCLUDING that
 * the item name is used VERBATIM and never lowercased. Weapons are keyed
 * uppercase, so lowercasing here would blank every weapon in the grid. That is
 * the same trap AUDIT 21.3 records on the Lua side.
 */
export function itemImage(
  slot: Slot | undefined,
  items: Record<string, ItemData>,
  imagepath: string,
): string | undefined {
  if (!slot || !slot.name) return undefined

  const meta = slot.metadata
  if (meta) {
    if (meta.imageurl) return String(meta.imageurl)
    if (meta.image) return `${imagepath}/${meta.image}.png`
  }

  const data = items[slot.name]
  if (data && data.image) return data.image

  return `${imagepath}/${slot.name}.png`
}

export const labelOf = (slot: Slot | undefined, items: Record<string, ItemData>): string => {
  if (!slot || !slot.name) return ''
  const data = items[slot.name]
  return (slot.metadata && slot.metadata.label) || (data && data.label) || slot.name
}
