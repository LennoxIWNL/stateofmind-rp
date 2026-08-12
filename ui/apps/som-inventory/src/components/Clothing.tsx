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
            <div className="som-clothing__figure">
            {/*
              An actual body, drawn here rather than left as a gradient box.
              The reference centres a figure between the two rails and without
              one the tab reads as a panel that failed to load. Single path,
              one stroke, so it inherits the accent and needs no asset.
            */}
            <svg viewBox="0 0 120 260" role="img" aria-label="Character silhouette">
              {/* Anatomical proportions rather than a stick figure: head one
                  eighth of the height, shoulders three heads wide, waist at the
                  midpoint. The old one was two boxes and a circle and looked
                  it. Filled with a soft gradient so it reads as a body under
                  the rails rather than as an outline drawing. */}
              <defs>
                <linearGradient id="somBody" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--som-surface)" stopOpacity="0.95" />
                  <stop offset="100%" stopColor="var(--som-bg-deep)" stopOpacity="0.95" />
                </linearGradient>
              </defs>
              <g fill="url(#somBody)" stroke="var(--som-pink-a45)" strokeWidth="1.2">
                <ellipse cx="60" cy="26" rx="15" ry="18" />
                <path d="M55 43h10v9l-5 3-5-3z" />
                <path d="M60 52c-11 0-19 4-24 11l-7 34 10 4 8-24v37h26v-37l8 24 10-4-7-34c-5-7-13-11-24-11z" />
                <path d="M29 63l-8 36 9 3 8-31z" />
                <path d="M91 63l8 36-9 3-8-31z" />
                <path d="M25 100c-3 8-4 16-3 22l9-1 4-19z" />
                <path d="M95 100c3 8 4 16 3 22l-9-1-4-19z" />
                <path d="M43 114h34l-3 56h-11l-4-38-4 38H46z" />
                <path d="M43 170h13l3 62H45z" />
                <path d="M64 170h13l-2 62H62z" />
                <path d="M43 232h16v7H41z" />
                <path d="M61 232h16v7H59z" />
              </g>
            </svg>
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
