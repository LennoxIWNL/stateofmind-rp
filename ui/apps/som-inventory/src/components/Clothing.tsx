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

/*
 * A glyph per slot.
 *
 * The rails were labelled boxes, which is what made the tab read as unfinished
 * next to the reference: every clothing UI worth copying shows the GARMENT, so
 * the slot is recognisable before you read it. Drawn here rather than sourced,
 * so they share one stroke weight and need no licence.
 *
 * Keyed by the som-appearance component/prop id, since that is what the server
 * speaks. Anything unmapped falls back to its label alone.
 */
const SLOT_ICONS: Record<string, string> = {
  // components
  'component-11': 'M8 6l-4 3 2 4 2-1v8h8v-8l2 1 2-4-4-3-4 2z',              // top
  'component-8':  'M9 5l3 2 3-2 2 2-2 3v9H9v-9L7 7z',                        // undershirt
  'component-4':  'M8 4h8l1 16h-4l-1-9-1 9H7z',                              // legs
  'component-6':  'M5 15h6l3 3h5v2H5z',                                      // shoes
  'component-3':  'M7 5l5 2 5-2 2 5-3 1v8H8v-8l-3-1z',                       // arms
  'component-7':  'M8 4l4 5 4-5 2 2-4 6-2 7-2-7-4-6z',                       // neck
  'component-1':  'M4 9a8 5 0 0 1 16 0v3a8 6 0 0 1-16 0zM9 10h2M13 10h2',    // mask
  'component-5':  'M8 7h8l2 12H6zM10 7V5h4v2',                               // bag
  'component-9':  'M12 3l7 3v6c0 4.5-3 8.3-7 11-4-2.7-7-6.5-7-11V6z',        // armour
  'component-10': 'M5 8h14v8H5zM9 8v8M15 8v8',                               // decals
  // props
  'prop-0': 'M6 13a6 6 0 0 1 12 0zM3 13h18v2H3z',                            // hat
  'prop-1': 'M3 10h7v4H3zM14 10h7v4h-7zM10 12h4',                            // glasses
  'prop-2': 'M12 5a3 3 0 0 1 3 3v3a3 3 0 0 1-6 0V8a3 3 0 0 1 3-3zM12 14v5',  // earrings
  'prop-6': 'M9 4h6v3H9zM9 17h6v3H9zM7 7h10v10H7z',                          // watch
  'prop-7': 'M5 12a7 5 0 0 1 14 0 7 5 0 0 1-14 0zM12 7v10',                  // bracelet
}

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

  /*
   * The camera lives exactly as long as this tab is mounted.
   *
   * Tying it to the component rather than to the inventory being open is what
   * makes switching tabs put the camera away: the player looking at their
   * pockets should be looking at the world, not at their own face.
   *
   * The Lua side ALSO drops the camera when the page reports itself closed,
   * because a cleanup that only runs on unmount is one abrupt teardown away
   * from stranding a scripted camera, and a stranded camera means the player
   * cannot see.
   */
  useEffect(() => {
    void fetchNui('somClothingPreview', { active: true })
    return () => {
      void fetchNui('somClothingPreview', { active: false })
    }
  }, [])

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
          {SLOT_ICONS[`${slot.kind}-${slot.id}`] ? (
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d={SLOT_ICONS[`${slot.kind}-${slot.id}`]} />
            </svg>
          ) : (
            <span className="som-clothing__slot-label">{slot.label}</span>
          )}
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
            {/*
              A HOLE, not a picture.

              The drawn silhouette that used to be here was replaced twice and
              looked drawn both times. The inventories whose clothing screens
              actually look right are not rendering an illustration at all:
              they point a camera at the player's own ped and let the game draw
              it behind a transparent gap in the page.

              So this div is deliberately empty and deliberately transparent.
              The character in it is the real one, wearing the real clothes,
              which is also the only way this can ever show what a garment
              actually looks like on the player.
            */}
            <div className="som-clothing__figure">
              <div className="som-clothing__stage" aria-label="Character preview" role="img" />

              <div className="som-clothing__turn">
                <button
                  type="button"
                  className="som-clothing__turn-btn"
                  onClick={() => void fetchNui('somClothingRotate', { by: -35 })}
                  title="Turn left"
                >
                  ‹
                </button>
                <button
                  type="button"
                  className="som-clothing__turn-btn"
                  onClick={() => void fetchNui('somClothingRotate', { by: 35 })}
                  title="Turn right"
                >
                  ›
                </button>
              </div>
            </div>
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
