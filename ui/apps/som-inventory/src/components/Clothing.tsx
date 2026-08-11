/**
 * The clothing tab: silhouette centred, slot rails down both edges.
 *
 * WIRED, through som-appearance rather than through ox_inventory.
 *
 * ox_inventory's NUI contract has no worn-clothing surface at all, so none of
 * this could come from it. It comes from som-appearance, which owns
 * som_characters.appearance and is the only writer of it. Removing a garment
 * moves it into a `hidden` map there and sets the live component nude, so the
 * original is never overwritten and putting it back on is a move rather than a
 * guess. See som-appearance/server/wardrobe.lua.
 *
 * This component decides nothing: the server re-reads the stored record, checks
 * the component against its own allow list, and refuses anything not on it.
 */

import { useCallback, useEffect, useState } from 'react'
import { fetchNui } from '@som/ui-kit'
import { formatWeight } from '../state'

type WardrobeSlot = {
  kind: 'component' | 'prop'
  id: number
  label: string
  group: string
  /** True when the garment is currently taken off. */
  off: boolean
}

type WardrobeState = {
  success: boolean
  slots?: WardrobeSlot[]
  error?: string
}

export function Clothing({ weight }: { weight: number }) {
  const [slots, setSlots] = useState<WardrobeSlot[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    const res = await fetchNui<WardrobeState>('somWardrobeState', {}, { success: false })
    if (res?.success && res.slots) {
      setSlots(res.slots)
      setError(null)
    } else {
      setSlots(null)
      setError(res?.error || 'Clothing is unavailable')
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  /**
   * Re-reads after every change rather than flipping the local flag.
   *
   * The server may have refused, and a rail that shows a jacket off when it is
   * still on is worse than one that takes a moment to catch up.
   */
  const act = useCallback(
    async (action: string, slot?: WardrobeSlot) => {
      await fetchNui('somWardrobe', {
        action,
        kind: slot?.kind,
        id: slot?.id,
      })
      setTimeout(() => void load(), 250)
    },
    [load],
  )

  const left = slots ? slots.filter((_, i) => i % 2 === 0) : []
  const right = slots ? slots.filter((_, i) => i % 2 === 1) : []

  const renderRail = (list: WardrobeSlot[]) => (
    <div className="som-clothing__rail">
      {list.map((slot) => (
        <button
          key={`${slot.kind}-${slot.id}`}
          className={`som-clothing__slot ${slot.off ? 'is-off' : 'is-on'}`}
          title={slot.off ? `Wear ${slot.label}` : `Remove ${slot.label}`}
          onClick={() => void act(slot.off ? 'wear' : 'remove', slot)}
        >
          <span className="som-clothing__slot-label">{slot.label}</span>
        </button>
      ))}
    </div>
  )

  return (
    <section className="som-panel som-panel--primary som-clothing">
      <header className="som-panel__head">
        <span className="som-panel__icon" aria-hidden="true" />
        <h2 className="som-panel__title">Clothing</h2>
        <div className="som-panel__weight">
          <span className="som-panel__kg">{weight ? formatWeight(weight) : ''}</span>
        </div>
      </header>

      {error && <p className="som-clothing__note">{error}</p>}

      {slots && (
        <>
          <div className="som-clothing__body">
            {renderRail(left)}
            <div className="som-clothing__figure" role="img" aria-label="Character silhouette" />
            {renderRail(right)}
          </div>

          <div className="som-clothing__footer">
            <button className="som-btn som-btn--drop" onClick={() => void act('removeAll')}>
              Remove all clothes
            </button>
            <button className="som-btn som-btn--give" onClick={() => void act('wearAll')}>
              Wear all clothes
            </button>
          </div>
        </>
      )}
    </section>
  )
}
