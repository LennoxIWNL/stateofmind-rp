/**
 * som-hud.
 *
 * A HUD and a layout editor. The HUD half is a renderer with no inbound
 * surface; the editor half accepts LAYOUT ONLY, never a value, which is the
 * property that keeps this resource unable to lie about anything that matters.
 *
 * See src/contract.ts for the payload shapes and [som]/som-hud/client for the
 * Lua that sends them.
 */

import { useCallback, useRef, useState } from 'react'
import { fetchNui, useNuiEvent } from '@som/ui-kit'
import {
  DEFAULT_LAYOUT,
  INBOUND,
  OUTBOUND,
  type Layout,
  type PanelId,
  type Player,
  type Status,
  type Vehicle,
  type World,
} from './contract'
import {
  Aviation, Compass, Condition, Location, Session, SpeedoDigital, SpeedoRing,
} from './components/Panels'
import { Editor } from './components/Editor'

export function App() {
  const [visible, setVisible] = useState(false)
  const [editing, setEditing] = useState(false)
  const [layout, setLayout] = useState<Layout>(DEFAULT_LAYOUT)
  const [status, setStatus] = useState<Status | null>(null)
  const [vehicle, setVehicle] = useState<Vehicle>({ inVehicle: false })
  const [world, setWorld] = useState<World | null>(null)
  const [player, setPlayer] = useState<Player | null>(null)

  useNuiEvent<{ value: boolean }>(INBOUND.visible, (d) => setVisible(d?.value === true))
  useNuiEvent<Status>(INBOUND.status, setStatus)
  useNuiEvent<Vehicle>(INBOUND.vehicle, setVehicle)
  useNuiEvent<World>(INBOUND.world, setWorld)
  useNuiEvent<Player>(INBOUND.player, setPlayer)
  useNuiEvent<{ on: boolean }>(INBOUND.seatbelt, (d) =>
    setVehicle((v) => ({ ...v, seatbelt: d?.on === true })))

  // The Lua is the source of truth for the layout. `false` means nothing saved,
  // which is the default rather than an error.
  useNuiEvent<{ layout: Layout | false }>(INBOUND.layout, (d) => {
    setLayout(d?.layout ? { ...DEFAULT_LAYOUT, ...d.layout } : DEFAULT_LAYOUT)
  })

  useNuiEvent<{ editing: boolean }>(INBOUND.edit, (d) => setEditing(d?.editing === true))

  /**
   * PERSIST. Called by the editor's Save button and by nothing else.
   *
   * Dragging a panel calls setLayout directly instead. It used to call this,
   * which meant every pointermove posted hudSaveLayout, and the Lua closes the
   * editor on save: the editor shut itself the instant you started dragging,
   * and reopening resumed a drag that had never ended so it shut again.
   */
  const save = useCallback((next: Layout) => {
    setLayout(next)
    void fetchNui(OUTBOUND.saveLayout, { layout: next })
  }, [])

  // Everything renders while editing, whatever the game says, so a panel can be
  // placed without needing to be in a car or underwater to see it.
  const show = visible || editing

  return (
    <div className={`hud ${editing ? 'is-editing' : ''} ${show ? '' : 'is-hidden'}`}>
      <Panel id="status" layout={layout} editing={editing} onChange={setLayout}>
        <Condition status={editing ? PREVIEW_STATUS : status} player={editing ? PREVIEW_PLAYER : player} />
      </Panel>

      {/* Speedometer and aviation are the same slot on the screen but never
          both at once: an aircraft has no gear to show and a car has no pitch.
          The Lua decides which by vehicle class, so the page does not guess. */}
      {(editing || (vehicle.inVehicle && !vehicle.air)) && (
        <Panel id="speedo" layout={layout} editing={editing} onChange={setLayout}>
          {layout.speedoStyle === 'ring'
            ? <SpeedoRing vehicle={editing ? PREVIEW_VEHICLE : vehicle} />
            : <SpeedoDigital vehicle={editing ? PREVIEW_VEHICLE : vehicle} />}
        </Panel>
      )}

      {(editing || (vehicle.inVehicle && vehicle.air)) && (
        <Panel id="aviation" layout={layout} editing={editing} onChange={setLayout}>
          <Aviation vehicle={editing ? PREVIEW_AIR : vehicle} />
        </Panel>
      )}

      <Panel id="compass" layout={layout} editing={editing} onChange={setLayout}>
        <Compass world={editing ? PREVIEW_WORLD : world} minimal={layout.compassStyle === 'minimal'} />
      </Panel>

      {/* Street names ride with the minimap: in a vehicle only. On foot you can
          see the street you are standing on, and the pair of them cluttered the
          corner permanently for information nobody was reading. */}
      {(editing || vehicle.inVehicle) && (
        <Panel id="location" layout={layout} editing={editing} onChange={setLayout}>
          <Location world={editing ? PREVIEW_WORLD : world} />
        </Panel>
      )}

      <Panel id="session" layout={layout} editing={editing} onChange={setLayout}>
        <Session player={editing ? PREVIEW_PLAYER : player} />
      </Panel>

      {editing && <Editor layout={layout} onChange={setLayout} onSave={save} />}
    </div>
  )
}

// ---------------------------------------------------------------------------
// A movable, scalable panel
// ---------------------------------------------------------------------------

type PanelProps = {
  id: PanelId
  layout: Layout
  editing: boolean
  onChange: (next: Layout) => void
  children: React.ReactNode
}

function Panel({ id, layout, editing, onChange, children }: PanelProps) {
  const state = layout[id]
  const ref = useRef<HTMLDivElement>(null)
  const drag = useRef<{ dx: number; dy: number } | null>(null)

  if (!state || (!state.on && !editing)) return null

  /**
   * Positions are PERCENTAGES of the viewport, converted at the moment of the
   * drag. Storing pixels would put half the HUD off screen the first time
   * somebody with an ultrawide sends their layout to somebody with a laptop,
   * and export/import makes that a normal thing to do.
   */
  const onPointerDown = (e: React.PointerEvent) => {
    if (!editing) return
    e.preventDefault()
    e.stopPropagation()

    const rect = ref.current?.getBoundingClientRect()
    if (!rect) return

    drag.current = {
      dx: e.clientX - (rect.left + rect.width / 2),
      dy: e.clientY - (rect.top + rect.height / 2),
    }
    ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
  }

  const onPointerMove = (e: React.PointerEvent) => {
    if (!editing || !drag.current) return

    const x = ((e.clientX - drag.current.dx) / window.innerWidth) * 100
    const y = ((e.clientY - drag.current.dy) / window.innerHeight) * 100

    onChange({
      ...layout,
      [id]: { ...state, x: clamp(x, 2, 98), y: clamp(y, 2, 98) },
    })
  }

  const onPointerUp = () => { drag.current = null }

  const onWheel = (e: React.WheelEvent) => {
    if (!editing) return
    const scale = clamp(state.scale + (e.deltaY < 0 ? 0.05 : -0.05), 0.5, 2)
    onChange({ ...layout, [id]: { ...state, scale } })
  }

  return (
    <div
      ref={ref}
      className={`hud-panel ${editing ? 'is-movable' : ''} ${state.on ? '' : 'is-off'}`}
      style={{
        left: `${state.x}%`,
        top: `${state.y}%`,
        transform: `translate(-50%, -50%) scale(${state.scale})`,
      }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onWheel={onWheel}
    >
      {children}
      {editing && <span className="hud-panel__handle" aria-hidden="true" />}
    </div>
  )
}

const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n))

// ---------------------------------------------------------------------------
// Editor previews
//
// Real values are whatever the player happens to have. Placing a panel needs
// something in it, and a speedometer reading 0 in a parked car gives no sense
// of the width the number will take at speed.
// ---------------------------------------------------------------------------

const PREVIEW_STATUS: Status = {
  health: 82, armour: 40, hunger: 64, thirst: 55, stress: 22, oxygen: 70, underwater: true,
}

const PREVIEW_VEHICLE: Vehicle = {
  inVehicle: true, speed: 125, unit: 'MPH', gear: 5, rpm: 70,
  engine: 88, warn: false, seatbelt: true, fuel: null,
}

const PREVIEW_AIR: Vehicle = {
  inVehicle: true, air: true, speed: 110, unit: 'MPH', gear: 127,
  pitch: 6, roll: 12, altitude: 340, fuel: null,
}

const PREVIEW_WORLD: World = {
  heading: 315, street: 'Palomino Avenue', crossing: 'Prosperity Street', zone: 'La Puerta',
}

const PREVIEW_PLAYER: Player = {
  cash: 4983, bank: 213940, job: 'Police Officer', jobGrade: 'Sergeant',
  gang: '', onduty: true, hour: 11, minute: 39, players: 1,
  voiceMode: 'Normal', talking: false, radio: false,
}
