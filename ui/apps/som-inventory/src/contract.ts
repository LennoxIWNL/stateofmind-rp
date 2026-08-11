/**
 * ox_inventory's NUI contract.
 *
 * ============================================================================
 * READ THIS BEFORE CHANGING ANYTHING IN THIS APP.
 *
 * PINNED TO ox_inventory v2.45.0. Enumerated by reading, 2026-08-11, from
 * `[standalone]/ox_inventory/web/src` and every `.lua` in that resource.
 *
 * This app is a REPLACEMENT RENDERER, not a fork. ox_inventory's Lua is stock
 * and stays upgradeable. The only edit to that resource is `ui_page` and one
 * `files{}` entry in its fxmanifest, and reverting is putting those two back.
 *
 * THE CONTRACT IS NOT VERSIONED UPSTREAM. There is no handshake and no version
 * field in any message. If an ox_inventory upgrade changes a payload shape,
 * this app will render wrong or blank with nothing in any console to say why.
 * This file is the only thing that makes that diagnosable: re-enumerate against
 * it after any upgrade.
 * ============================================================================
 *
 * WHY THE BUILD LANDS INSIDE ox_inventory (`web/som/`) RATHER THAN IN A som-*
 * RESOURCE, WHICH LOOKS BACKWARDS AND IS NOT:
 *
 * `fetchNui` posts to `https://<origin-resource>/<callback>`, and the origin is
 * whichever resource served the page. A `RegisterNUICallback` only ever answers
 * for the resource that owns the frame. So a page served from `som-inventory`
 * would post to `som-inventory`, and all ELEVEN of ox_inventory's callbacks
 * below would go unanswered: no item could be moved, used, split or bought.
 * There is no forwarding trick, because the callbacks are bound to the frame.
 *
 * Serving from ox_inventory's own origin is what makes the stock Lua work
 * untouched. The SOURCE still lives here, in git, under `ui/apps/som-inventory`.
 * Only the build output lands over there.
 */

// ---------------------------------------------------------------------------
// Types, mirrored from ox_inventory/web/src/typings
// ---------------------------------------------------------------------------

export type Slot = {
  slot: number
  name?: string
  count?: number
  weight?: number
  metadata?: Record<string, any>
  durability?: number
}

export type SlotWithItem = Slot & {
  name: string
  count: number
  weight: number
  durability?: number
  price?: number
  currency?: string
  ingredients?: Record<string, number>
  duration?: number
  image?: string
  grade?: number | number[]
}

/** ox_inventory's own four. `crafting` is included for completeness; we render it as a shop. */
export const INVENTORY_TYPES = ['player', 'shop', 'container', 'crafting'] as const
export type InventoryType = (typeof INVENTORY_TYPES)[number] | string

export type Inventory = {
  id: string
  type: InventoryType
  slots: number
  items: Slot[]
  maxWeight?: number
  label?: string
  groups?: Record<string, number>
}

export type ItemData = {
  name: string
  label: string
  stack: boolean
  usable: boolean
  close: boolean
  count: number
  description?: string
  buttons?: string[]
  ammoName?: string
  image?: string
}

// ---------------------------------------------------------------------------
// INBOUND. Lua -> page, via SendNUIMessage({ action, data }).
//
// Seven actions, and that is the whole of it.
// ---------------------------------------------------------------------------

export type InboundInit = {
  locale: Record<string, string>
  items: Record<string, ItemData>
  leftInventory: Inventory
  imagepath: string
}

/**
 * ALSO OPENS THE UI. There is no separate open message.
 *
 * The stock React app listens for `setInventoryVisible`, and NOTHING IN
 * ox_inventory's LUA EVER SENDS IT. Verified by grepping every .lua in the
 * resource: zero hits. It is a dead listener. Do not wait for it, or the
 * inventory never opens.
 */
export type InboundSetupInventory = {
  leftInventory?: Inventory
  rightInventory?: Inventory
}

/**
 * Two shapes down one action, which is the trap in this contract.
 *
 * `client.lua:956`  sends { items, itemCount }
 * `client.lua:1861` sends { items } only
 *
 * and `items` is EITHER one payload OR an array of them. Handle both or a
 * single-item refresh silently does nothing.
 */
export type ItemsPayload = {
  item: Slot
  inventory: InventoryType
}

export type InboundRefreshSlots = {
  items?: ItemsPayload | ItemsPayload[]
  itemCount?: Record<string, number>
  weightData?: { inventoryId: string; maxWeight: number }
}

/** A tuple, not an object. `[item, text, count?]`. */
export type InboundItemNotify = [item: SlotWithItem, text: string, count?: number]

export type InboundDisplayMetadata = Array<{ metadata: string; value: string }>

export const INBOUND = {
  /** { locale, items, leftInventory, imagepath } */
  init: 'init',
  /** { leftInventory?, rightInventory? }. Also opens. */
  setupInventory: 'setupInventory',
  /** { items?, itemCount?, weightData? } */
  refreshSlots: 'refreshSlots',
  /** Array<{ metadata, value }> */
  displayMetadata: 'displayMetadata',
  /** [item, text, count?] */
  itemNotify: 'itemNotify',
  /** no payload */
  closeInventory: 'closeInventory',
  /** no payload */
  toggleHotbar: 'toggleHotbar',
} as const

/**
 * NOT NUI MESSAGES, despite reading like them.
 *
 * `move`, `swap`, `stack` and `give` appear as `action = '...'` in
 * `modules/inventory/server.lua`. They are the SERVER HOOK payload's action
 * field (`TriggerEventHooks('swapItems', ...)`), on the far side of the
 * network from this page. Wiring a listener for them would never fire.
 */
export const NOT_NUI_ACTIONS = ['move', 'swap', 'stack', 'give'] as const

// ---------------------------------------------------------------------------
// OUTBOUND. page -> Lua, via fetch to https://ox_inventory/<name>.
//
// Eleven callbacks. Names are exact; there is no aliasing on the Lua side.
// ---------------------------------------------------------------------------

export type SwapPayload = {
  fromSlot: number
  fromType: InventoryType
  toSlot: number
  /** 'newdrop' creates a world drop. Refused server side in a vehicle or while falling. */
  toType: InventoryType | 'newdrop'
  count: number
}

export const OUTBOUND = {
  /** Fire once when the page is ready. ox_inventory answers with `init`. */
  uiLoaded: 'uiLoaded',
  /** SwapPayload -> boolean | number. THE move/split/stack/drop path. */
  swapItems: 'swapItems',
  /** { name, slot }. Uses the item. */
  useItem: 'useItem',
  /** { name, slot } */
  giveItem: 'giveItem',
  /** SwapPayload -> boolean */
  buyItem: 'buyItem',
  /** SwapPayload -> boolean */
  craftItem: 'craftItem',
  /** Closes and releases NUI focus. */
  exit: 'exit',
  /** { name } -> ItemData. For the tooltip. */
  getItemData: 'getItemData',
  /** { name, slot, index } for an item's config `buttons`. */
  useButton: 'useButton',
  /** { slot } */
  removeAmmo: 'removeAmmo',
  /** { slot, component } */
  removeComponent: 'removeComponent',
} as const

/**
 * EVERY ONE OF THESE IS A REQUEST, NOT AN INSTRUCTION.
 *
 * ox_inventory re-derives ownership rather than trusting the ids we send
 * (`swapItems` resolves the other inventory as whatever the SERVER recorded the
 * player as having open), holds a per-slot mutex, and distance-gates stashes
 * and drops. Those nine invariants are catalogued in AUDIT 6.5 and are the
 * strongest anti-dupe layer in the stack.
 *
 * So this page may render optimistically, but it must never treat its own
 * optimism as truth: the authority is the next `refreshSlots`. Anything this
 * app adds that has no stock path (throwing, clothing toggles, give-by-drag
 * targeting) gets a NEW som-inventory server event with its own validation,
 * never a client-side mutation.
 */
export const AUTHORITY_NOTE = 'server' as const
