/**
 * som-inventory.
 *
 * A replacement renderer for ox_inventory's NUI. Read src/contract.ts before
 * changing anything here: the message contract it speaks is not versioned
 * upstream, and that file is the only record of it.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { fetchNui, useNuiEvent } from '@som/ui-kit'
import {
  INBOUND,
  OUTBOUND,
  type InboundInit,
  type InboundItemNotify,
  type InboundRefreshSlots,
  type InboundSetupInventory,
  type InventoryType,
  type Slot,
  type SwapPayload,
} from './contract'
import { useInventoryState } from './state'
import { InventoryPanel, type DragState } from './components/Inventory'
import { SlotContextMenu, type MenuTarget } from './components/ContextMenu'
import { Hotbar } from './components/Hotbar'
import { Clothing } from './components/Clothing'
import { ItemNotifications, type Notification } from './components/Notifications'

type Tab = 'inventory' | 'clothes'

export function App() {
  const { state, dispatch } = useInventoryState()
  const [visible, setVisible] = useState(false)
  const [tab, setTab] = useState<Tab>('inventory')
  const [drag, setDrag] = useState<DragState | null>(null)
  const [menu, setMenu] = useState<MenuTarget | null>(null)
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [hotbar, setHotbar] = useState(false)
  const notifyId = useRef(0)

  // -------------------------------------------------------------------------
  // Inbound
  // -------------------------------------------------------------------------

  useNuiEvent<InboundInit>(INBOUND.init, (data) => {
    dispatch({
      type: 'init',
      locale: data.locale,
      items: data.items,
      left: data.leftInventory,
      imagepath: data.imagepath,
    })
  })

  // setupInventory ALSO opens. There is no separate open message, and the
  // `setInventoryVisible` the stock app listens for is never sent by any Lua in
  // ox_inventory. Waiting for it would mean the inventory never opens.
  useNuiEvent<InboundSetupInventory>(INBOUND.setupInventory, (data) => {
    dispatch({ type: 'setup', data })
    setVisible(true)
  })

  useNuiEvent<InboundRefreshSlots>(INBOUND.refreshSlots, (data) => {
    dispatch({ type: 'refresh', data })
  })

  useNuiEvent<Array<{ metadata: string; value: string }>>(INBOUND.displayMetadata, (data) => {
    dispatch({ type: 'metadata', data })
  })

  useNuiEvent(INBOUND.closeInventory, () => {
    setVisible(false)
    setDrag(null)
    setMenu(null)
    setTab('inventory')
  })

  useNuiEvent(INBOUND.toggleHotbar, () => setHotbar((on) => !on))

  useNuiEvent<InboundItemNotify>(INBOUND.itemNotify, (payload) => {
    // A TUPLE, not an object: [item, text, count?].
    if (!Array.isArray(payload)) return
    const [item, text, count] = payload
    if (!item) return
    notifyId.current += 1
    const entry: Notification = { id: notifyId.current, item, text, count }
    setNotifications((list) => [...list, entry])
    setTimeout(() => {
      setNotifications((list) => list.filter((n) => n.id !== entry.id))
    }, 3000)
  })

  // ox_inventory answers this with `init`. Without it the page never receives
  // the item catalogue and every slot renders nameless.
  useEffect(() => {
    void fetchNui(OUTBOUND.uiLoaded, {})
  }, [])

  // -------------------------------------------------------------------------
  // Outbound
  // -------------------------------------------------------------------------

  const close = useCallback(() => {
    // Tell Lua and let Lua decide. Hiding locally while Lua still holds NUI
    // focus leaves the player unable to move with nothing on screen to click.
    void fetchNui(OUTBOUND.exit, {})
  }, [])

  useEffect(() => {
    if (!visible) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [visible, close])

  /**
   * The one path every move, split, stack and drop goes through.
   *
   * Renders optimistically so the item lands under the cursor immediately, then
   * defers entirely: a false answer is repaired by asking for the truth rather
   * than by trying to undo the guess, because the server may have changed more
   * than the two slots we touched.
   */
  const swap = useCallback(
    async (from: { type: InventoryType; slot: number }, to: { type: InventoryType | 'newdrop'; slot: number }, count: number) => {
      if (count <= 0) return

      if (to.type !== 'newdrop') {
        dispatch({ type: 'localSwap', from, to: to as { type: InventoryType; slot: number }, count })
      }

      const payload: SwapPayload = {
        fromSlot: from.slot,
        fromType: from.type,
        toSlot: to.slot,
        toType: to.type,
        count,
      }

      const ok = await fetchNui<boolean | number>(OUTBOUND.swapItems, payload, false)
      if (ok === false) {
        // ox_inventory pushes a refreshSlots of its own on a refusal in most
        // paths. Asking again is the cheap way to be right in the ones where it
        // does not.
        void fetchNui(OUTBOUND.uiLoaded, {})
      }
    },
    [dispatch],
  )

  const useSlot = useCallback((slot: Slot) => {
    if (!slot.name) return
    void fetchNui(OUTBOUND.useItem, { name: slot.name, slot: slot.slot })
  }, [])

  const giveSlot = useCallback((slot: Slot) => {
    if (!slot.name) return
    void fetchNui(OUTBOUND.giveItem, { name: slot.name, slot: slot.slot })
  }, [])

  const buy = useCallback(
    async (from: { type: InventoryType; slot: number }, to: { type: InventoryType; slot: number }, count: number) => {
      const payload: SwapPayload = {
        fromSlot: from.slot,
        fromType: from.type,
        toSlot: to.slot,
        toType: to.type,
        count,
      }
      const callback = from.type === 'crafting' ? OUTBOUND.craftItem : OUTBOUND.buyItem
      await fetchNui<boolean>(callback, payload, false)
    },
    [],
  )

  const isShopSide = state.right?.type === 'shop' || state.right?.type === 'crafting'

  const leftWeightMax = state.left?.maxWeight || 0

  const value = useMemo(
    () => ({ state, swap, useSlot, giveSlot, buy, setMenu, drag, setDrag, isShopSide }),
    [state, swap, useSlot, giveSlot, buy, drag, isShopSide],
  )

  if (!visible) {
    return <Hotbar open={hotbar} state={state} />
  }

  return (
    <div className="som-inv" onContextMenu={(e) => e.preventDefault()}>
      {/* Secondary panel is LEFT, main panel is RIGHT, per the reference. */}
      {state.right && (
        <InventoryPanel
          side="secondary"
          inventory={state.right}
          ctx={value}
        />
      )}

      <div className="som-inv__main">
        <div className="som-inv__tabs">
          <button
            className={`som-inv__tab ${tab === 'inventory' ? 'is-active' : ''}`}
            onClick={() => setTab('inventory')}
          >
            Inventory
          </button>
          <button
            className={`som-inv__tab ${tab === 'clothes' ? 'is-active' : ''}`}
            onClick={() => setTab('clothes')}
          >
            Clothes
          </button>
          <button className="som-inv__esc" onClick={close}>
            ESC
          </button>
        </div>

        {tab === 'inventory' ? (
          <InventoryPanel side="primary" inventory={state.left} ctx={value} />
        ) : (
          <Clothing weight={leftWeightMax} />
        )}
      </div>

      {menu && (
        <SlotContextMenu
          target={menu}
          state={state}
          onClose={() => setMenu(null)}
          onUse={useSlot}
          onGive={giveSlot}
          onSwap={swap}
        />
      )}

      <ItemNotifications list={notifications} state={state} />
    </div>
  )
}
