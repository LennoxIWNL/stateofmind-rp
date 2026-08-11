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
import { ThrowCharge } from './components/Throw'
import { Basket, type BasketLine } from './components/Shop'
import { NearbyGive, type NearbyPlayer } from './components/Nearby'
import { StatusStrip, type Status } from './components/StatusStrip'
import { Tooltip } from './components/Tooltip'

type Tab = 'inventory' | 'clothes'

export function App() {
  const { state, dispatch } = useInventoryState()
  const [visible, setVisible] = useState(false)
  const [tab, setTab] = useState<Tab>('inventory')
  const [drag, setDrag] = useState<DragState | null>(null)
  const [menu, setMenu] = useState<MenuTarget | null>(null)
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [hotbar, setHotbar] = useState(false)
  const [throwing, setThrowing] = useState<Slot | null>(null)
  const [basket, setBasket] = useState<BasketLine[]>([])
  const [nearby, setNearby] = useState<NearbyPlayer[]>([])
  const [status, setStatus] = useState<Status | null>(null)
  const [hover, setHover] = useState<{ slot: Slot; x: number; y: number } | null>(null)
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
    setThrowing(null)
    setHover(null)
    setTab('inventory')
    // The basket is staging, and the page is destroyed on close. Surviving a
    // reopen is a client Lua job keyed by shop id, not this component's.
    setBasket([])
  })

  useNuiEvent(INBOUND.toggleHotbar, () => setHotbar((on) => !on))

  // NOT part of ox_inventory's contract. Pushed by som_bridge.lua, which is a
  // client script and can read the ped. See components/StatusStrip.
  useNuiEvent<Status>('somStatus', (data) => setStatus(data))

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

  // The bridge only polls condition while something is looking at it.
  useEffect(() => {
    void fetchNui('somInventoryOpen', { open: visible })
  }, [visible])

  // The basket survives a close because it lives in the bridge keyed by shop
  // id, not here: this page is destroyed when the inventory closes.
  const shopId = state.right && (state.right.type === 'shop' || state.right.type === 'crafting')
    ? state.right.id
    : null

  useEffect(() => {
    if (!shopId) return
    let alive = true
    void fetchNui<BasketLine[]>('somBasketLoad', { shop: shopId }, []).then((lines) => {
      if (alive && Array.isArray(lines)) setBasket(lines)
    })
    return () => {
      alive = false
    }
  }, [shopId])

  useEffect(() => {
    if (!shopId) return
    void fetchNui('somBasketSave', { shop: shopId, lines: basket })
  }, [shopId, basket])

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

  /**
   * Checkout replays the basket through ox_inventory's OWN buyItem, one line at
   * a time. So the server re-prices and re-validates every line exactly as it
   * does for a stock drag-to-buy, and a doctored basket buys nothing extra.
   *
   * Sequential rather than parallel on purpose: ox_inventory holds a per-slot
   * mutex, and firing every line at once is the shape that trips it.
   */
  const checkout = useCallback(
    async (_account: 'bank' | 'cash') => {
      const shop = state.right
      if (!shop) return

      const empties = state.left.items.filter((s) => !s.name).map((s) => s.slot)
      let next = 0

      for (const line of basket) {
        const target = empties[next++]
        if (target === undefined) break
        await buy({ type: shop.type, slot: line.slot }, { type: 'player', slot: target }, line.count)
      }

      setBasket([])
    },
    [basket, buy, state.left.items, state.right],
  )

  const addToBasket = useCallback((line: BasketLine) => {
    setBasket((lines) => {
      const found = lines.find((l) => l.slot === line.slot)
      if (found) return lines.map((l) => (l.slot === line.slot ? { ...l, count: l.count + line.count } : l))
      return [...lines, line]
    })
  }, [])

  const giveTo = useCallback((slot: Slot, target: number, count: number) => {
    void fetchNui('somGiveTo', { slot: slot.slot, target, count })
  }, [])

  // Nearby players, refreshed while a drag is live. Read only: this decides
  // what to highlight, never whether the give is allowed.
  useEffect(() => {
    if (!visible || !drag) {
      setNearby([])
      return
    }
    let alive = true
    const poll = async () => {
      const list = await fetchNui<NearbyPlayer[]>('somNearbyPlayers', {}, [])
      if (alive) setNearby(Array.isArray(list) ? list : [])
    }
    void poll()
    const id = setInterval(poll, 700)
    return () => {
      alive = false
      clearInterval(id)
    }
  }, [visible, drag])

  const isShopSide = state.right?.type === 'shop' || state.right?.type === 'crafting'

  const leftWeightMax = state.left?.maxWeight || 0

  const value = useMemo(
    () => ({ state, swap, useSlot, giveSlot, buy, setMenu, drag, setDrag, isShopSide, addToBasket, setHover }),
    [state, swap, useSlot, giveSlot, buy, drag, isShopSide, addToBasket],
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

        <StatusStrip status={status} />
      </div>

      {isShopSide && (
        <Basket
          lines={basket}
          state={state}
          shopType={state.right!.type}
          onChange={setBasket}
          onCheckout={checkout}
        />
      )}

      {menu && (
        <SlotContextMenu
          target={menu}
          state={state}
          onClose={() => setMenu(null)}
          onUse={useSlot}
          onGive={giveSlot}
          onSwap={swap}
          onThrow={setThrowing}
        />
      )}

      {throwing && (
        <ThrowCharge slot={throwing} state={state} onDone={() => setThrowing(null)} />
      )}

      {drag && nearby.length > 0 && (
        <NearbyGive
          nearby={nearby}
          onGive={(target) => {
            if (drag) giveTo(drag.item, target, drag.count)
            setDrag(null)
          }}
        />
      )}

      {hover && !drag && <Tooltip slot={hover.slot} state={state} x={hover.x} y={hover.y} />}

      <ItemNotifications list={notifications} state={state} />
    </div>
  )
}
