/**
 * The throw charge bar.
 *
 * Hold to charge, release to throw. The bar is the only thing this component
 * owns; the throw itself is a request. The server re-reads the slot, re-reads
 * the player's position, clamps the power and decides where the item lands, so
 * a page that reported a full charge on a tap gains a longer throw and nothing
 * else. See som-inventory/server/main.lua.
 */

import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '@som/ui-kit'
import type { Slot } from '../contract'
import { itemImage, labelOf, type State } from '../state'

/** Time to reach full charge. Long enough to be a decision, short enough not to be a chore. */
const CHARGE_MS = 1100

type Props = {
  slot: Slot
  state: State
  onDone: () => void
}

export function ThrowCharge({ slot, state, onDone }: Props) {
  const [power, setPower] = useState(0)
  const start = useRef<number>(performance.now())
  const raf = useRef<number>(0)
  const released = useRef(false)

  useEffect(() => {
    const tick = () => {
      const elapsed = performance.now() - start.current
      setPower(Math.min(1, elapsed / CHARGE_MS))
      raf.current = requestAnimationFrame(tick)
    }
    raf.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf.current)
  }, [])

  useEffect(() => {
    const release = () => {
      if (released.current) return
      released.current = true

      const elapsed = performance.now() - start.current
      const finalPower = Math.min(1, elapsed / CHARGE_MS)

      void fetchNui('somThrow', { slot: slot.slot, power: finalPower })
      onDone()
    }

    // Pointer OR key, because the charge can be started from the context menu
    // button and finished with the mouse already moved off it.
    window.addEventListener('pointerup', release)
    window.addEventListener('keyup', release)
    return () => {
      window.removeEventListener('pointerup', release)
      window.removeEventListener('keyup', release)
    }
  }, [slot.slot, onDone])

  const image = itemImage(slot, state.items, state.imagepath)

  return (
    <div className="som-throw">
      <div className="som-throw__item">
        {image && <img src={image} alt="" draggable={false} />}
        <span>{labelOf(slot, state.items)}</span>
      </div>

      <div className="som-throw__bar">
        <span style={{ width: `${power * 100}%` }} />
      </div>

      {/*
        A trajectory read as a number rather than drawn as an arc. The arc in
        the reference is drawn in the world, which is a client Lua concern: the
        page cannot see the world and has no camera to project against.
      */}
      <div className="som-throw__hint">
        Release to throw &middot; {Math.round(power * 100)}%
      </div>
    </div>
  )
}
