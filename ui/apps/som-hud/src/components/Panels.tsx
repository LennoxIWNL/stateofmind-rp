/**
 * The HUD panels.
 *
 * Layout and structure from the reference sheets. Colour is tokens only, with
 * ONE deliberate exception documented in app.css: the five condition icons keep
 * distinguishing hues, because they are read simultaneously and at a glance,
 * and telling them apart matters more there than accent discipline.
 *
 * Every panel is subtractive: anything at a resting value stands down rather
 * than sitting full. A gauge that is always at 100% is noise, and noise teaches
 * players to stop reading the row it sits in.
 */

import { useEffect, useRef, useState } from 'react'
import type { Player, Status, Vehicle, VoiceState, World } from '../contract'

// ---------------------------------------------------------------------------
// Condition
// ---------------------------------------------------------------------------

/*
 * LUCIDE, not hand-drawn. The drawn ones looked drawn, and the owner said so.
 *
 * Worth recording what the survey actually found, because the obvious plan was
 * wrong: there is no FiveM HUD with its own icon artwork to borrow. ps-hud,
 * g4_hud and whoisLoku/fivem-hud ship ZERO svg files between them because they
 * use Font Awesome. Code1616/fivem-gta-hud's files are literally named
 * heart-svgrepo-com.svg and brain-svgrepo-com.svg, straight off SVGRepo.
 * qb-hud has NO LICENCE AT ALL, so it is all rights reserved and not usable
 * whatever it contains.
 *
 * So every one of those HUDs is already using a public icon set. Copying from
 * them would be laundering the same icons through a GPL repo and taking the
 * GPL with it. Going to the source is cleaner, better drawn and better
 * licensed.
 *
 * Lucide is ISC: use, copy and modify freely, attribution only, no copyleft.
 * Path data below is copied verbatim from lucide-icons/lucide so it is real
 * rather than approximated, and every icon sits on the same 24x24 grid at the
 * same 2px stroke, which is the thing hand-drawing could never hold.
 *
 * Multi-element icons are why this is an array of paths rather than one string.
 */
const ICONS: Record<string, string[]> = {
  // heart
  health: [
    'M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5',
  ],
  // shield-half
  armour: [
    'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z',
    'M12 22V2',
  ],
  // beef, which reads as food at 16px far better than a plate or cutlery does
  hunger: [
    'M16.4 13.7A6.5 6.5 0 1 0 6.28 6.6c-1.1 3.13-.78 3.9-3.18 6.08A3 3 0 0 0 5 18c4 0 8.4-1.8 11.4-4.3',
    'm18.5 6 2.19 4.5a6.48 6.48 0 0 1-2.29 7.2C15.4 20.2 11 22 7 22a3 3 0 0 1-2.68-1.66L2.4 16.5',
  ],
  // droplet
  thirst: [
    'M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z',
  ],
  // wind
  oxygen: [
    'M12.8 19.6A2 2 0 1 0 14 16H2',
    'M17.5 8a2.5 2.5 0 1 1 2 4H2',
    'M9.8 4.4A2 2 0 1 1 11 8H2',
  ],
  // brain
  stress: [
    'M12 18V5',
    'M15 13a4.17 4.17 0 0 1-3-4 4.17 4.17 0 0 1-3 4',
    'M17.598 6.5A3 3 0 1 0 12 5a3 3 0 1 0-5.598 1.5',
    'M17.997 5.125a4 4 0 0 1 2.526 5.77',
    'M18 18a4 4 0 0 0 2-7.464',
    'M19.967 17.483A4 4 0 1 1 12 18a4 4 0 1 1-7.967-.517',
    'M6 18a4 4 0 0 1-2-7.464',
    'M6.003 5.125a4 4 0 0 0-2.526 5.77',
  ],
  // mic
  voice: ['M12 19v3', 'M19 10v2a7 7 0 0 1-14 0v-2'],
}

/** The rect in `mic` cannot be expressed as a path, so it is drawn separately. */
function Glyph({ name }: { name: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" strokeLinecap="round" strokeLinejoin="round">
      {(ICONS[name] ?? []).map((d) => (
        <path key={d} d={d} />
      ))}
      {name === 'voice' && <rect x="9" y="2" width="6" height="13" rx="3" />}
    </svg>
  )
}

/**
 * The voice hex, which ANNOUNCES A RANGE CHANGE rather than only recording it.
 *
 * Cycling range used to change a tooltip nobody had open. The range is now
 * named on screen for a moment when it changes, and the hex pulses, because a
 * control whose only feedback is hidden behind a hover is indistinguishable
 * from one that did not fire. That is exactly how it was reported.
 *
 * The label hides itself again, so this stays a notification rather than
 * another permanent readout.
 */
function Voice({ voice }: { voice: VoiceState }) {
  const [announce, setAnnounce] = useState(false)
  const first = useRef(true)

  useEffect(() => {
    // Not on mount. Announcing the range the moment the HUD appears would fire
    // on every spawn, which is noise rather than a change.
    if (first.current) {
      first.current = false
      return
    }

    setAnnounce(true)
    const t = setTimeout(() => setAnnounce(false), 1600)
    return () => clearTimeout(t)
  }, [voice.voiceMode])

  return (
    <div
      className={`hud-hex hud-hex--voice ${voice.talking ? 'is-live' : ''} ${announce ? 'is-announcing' : ''}`}
      title={`Voice: ${voice.voiceMode}${voice.radio ? ` / radio ${voice.radio}` : ''}`}
    >
      <span className="hud-hex__fill" style={{ height: voice.talking ? '100%' : '0%' }} />
      <Glyph name="voice" />
      {announce && <span className="hud-hex__label">{voice.voiceMode}</span>}
    </div>
  )
}

type Ring = { key: string; value: number; show: boolean }

export function Condition({
  status,
  voice,
}: {
  status: Status | null
  voice: VoiceState | null
}) {
  if (!status) return null

  /*
   * Hunger and thirst are ALWAYS shown now.
   *
   * They used to hide above 90%, on the subtractive reasoning that a full gauge
   * is noise. That was wrong for these two specifically: they are the only
   * things here a player is expected to act on before they become a problem, so
   * a row that shows them only once they are already low gives no warning at
   * all. Armour still stands down at zero, and oxygen and stress still only
   * appear when they mean something, because those genuinely are exceptions.
   */
  const rings: Ring[] = [
    { key: 'health', value: status.health, show: true },
    { key: 'armour', value: status.armour, show: status.armour > 0 },
    { key: 'hunger', value: status.hunger, show: true },
    { key: 'thirst', value: status.thirst, show: true },
    { key: 'oxygen', value: status.oxygen, show: status.underwater },
    { key: 'stress', value: status.stress, show: status.stress >= 10 },
  ]

  return (
    <div className="hud-condition">
      {rings
        .filter((r) => r.show)
        .map((r) => (
          <div
            key={r.key}
            className={`hud-hex hud-hex--${r.key} ${r.value <= 15 ? 'is-critical' : r.value <= 35 ? 'is-low' : ''}`}
            title={`${r.key} ${r.value}%`}
          >
            {/* The fill is a clip from the bottom, so the hexagon empties like
                a vessel rather than a bar sitting inside a shape. */}
            <span className="hud-hex__fill" style={{ height: `${r.value}%` }} />
            <Glyph name={r.key} />
          </div>
        ))}

      {/*
        Voice sits with the body, not in a chip of its own.
        Full when transmitting, outline when not, and the range is a title
        rather than a label: it is a thing you check, not a thing you read.
      */}
      {voice && <Voice voice={voice} />}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Speedometers
// ---------------------------------------------------------------------------

function Segments({ value, count = 5 }: { value: number; count?: number }) {
  const lit = Math.round((Math.min(100, Math.max(0, value)) / 100) * count)
  return (
    <span className="hud-segments">
      {Array.from({ length: count }, (_, i) => (
        <i key={i} className={i < lit ? 'is-on' : ''} />
      ))}
    </span>
  )
}

export function SpeedoDigital({ vehicle }: { vehicle: Vehicle }) {
  return (
    <div className="hud-speedo hud-speedo--digital">
      <div className="hud-speedo__row">
        <span className="hud-speedo__gear">{vehicle.gear ?? 0}</span>
        <span className="hud-speedo__value">{vehicle.speed ?? 0}</span>
      </div>

      <div className="hud-speedo__bars">
        {/* Engine condition as the left bar, RPM as the right blocks. Fuel sits
            between them and is INERT until a fuel resource exists: rendering it
            pinned at a number would teach the player to ignore the whole HUD. */}
        <span className="hud-speedo__engine">
          <span style={{ width: `${vehicle.engine ?? 100}%` }} className={vehicle.warn ? 'is-warn' : ''} />
        </span>
        <Segments value={vehicle.rpm ?? 0} />
      </div>

      <div className="hud-speedo__meta">
        <span>{vehicle.unit ?? 'MPH'}</span>
        {vehicle.fuel == null ? (
          <span className="hud-speedo__nofuel" title="No fuel resource installed">FUEL --</span>
        ) : (
          <span>FUEL {Math.round(vehicle.fuel)}%</span>
        )}
        {vehicle.seatbelt && <span className="hud-speedo__belt">BELT</span>}
      </div>
    </div>
  )
}

export function SpeedoRing({ vehicle }: { vehicle: Vehicle }) {
  const speed = vehicle.speed ?? 0
  // Sweeps 270 degrees, leaving a gap at the bottom for the readout, which is
  // what every dial in the reference does.
  const pct = Math.min(1, speed / 200)
  const dash = 2 * Math.PI * 42
  const offset = dash * (1 - pct * 0.75)

  return (
    <div className="hud-speedo hud-speedo--ring">
      <svg viewBox="0 0 100 100">
        <circle className="hud-ring__track" cx="50" cy="50" r="42" transform="rotate(135 50 50)"
          strokeDasharray={`${dash * 0.75} ${dash}`} />
        <circle className="hud-ring__fill" cx="50" cy="50" r="42" transform="rotate(135 50 50)"
          strokeDasharray={dash} strokeDashoffset={offset} />
      </svg>

      <div className="hud-ring__centre">
        <span className="hud-ring__value">{speed}</span>
        <span className="hud-ring__unit">{vehicle.unit ?? 'MPH'}</span>
      </div>

      <span className="hud-ring__gear">{vehicle.gear ?? 0}</span>
      {vehicle.seatbelt && <span className="hud-ring__belt">BELT</span>}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Aviation. Auto-activates on a plane or helicopter and clears on exit.
// ---------------------------------------------------------------------------

export function Aviation({ vehicle }: { vehicle: Vehicle }) {
  const tiles: Array<[string, number | string]> = [
    ['PITCH', vehicle.pitch ?? 0],
    ['FUEL', vehicle.fuel == null ? '--' : Math.round(vehicle.fuel)],
    ['ROLL', vehicle.roll ?? 0],
    ['ALT', vehicle.altitude ?? 0],
    ['HEAD', vehicle.gear ?? 0],
    [vehicle.unit ?? 'MPH', vehicle.speed ?? 0],
  ]

  return (
    <div className="hud-aviation">
      {tiles.map(([label, value]) => (
        <div key={label} className="hud-aviation__tile">
          {/* The leading zero is lighter than the digits, as in the reference:
              it holds the width so the tile does not jump between 9 and 10. */}
          <span className="hud-aviation__value">
            <i>0</i>
            {String(value).padStart(2, '0').slice(-2)}
          </span>
          <span className="hud-aviation__label">{label}</span>
        </div>
      ))}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Compass
// ---------------------------------------------------------------------------

const CARDINALS: Array<[number, string]> = [
  [0, 'N'], [45, 'NE'], [90, 'E'], [135, 'SE'],
  [180, 'S'], [225, 'SW'], [270, 'W'], [315, 'NW'],
]

/**
 * Eases the compass toward the reported bearing instead of snapping to it.
 *
 * Messages arrive every 60ms; a monitor draws every 16ms. Rendering the raw
 * value means three identical frames then a step, which is exactly the "numbers
 * just jump" being reported. This runs on requestAnimationFrame so the tape
 * moves on every frame the display actually has.
 *
 * THE WRAP IS THE WHOLE DIFFICULTY. Going from 350 to 10 degrees is a 20 degree
 * turn to the right, not a 340 degree spin to the left. Interpolating the
 * numbers directly makes the compass whirl backwards every time the player
 * crosses north, so the delta is normalised into -180..180 first and the
 * accumulator is allowed to run outside 0..360, then wrapped only for display.
 */
function useSmoothHeading(target: number) {
  const [shown, setShown] = useState(target)
  const current = useRef(target)
  const goal = useRef(target)

  goal.current = target

  useEffect(() => {
    let frame = 0

    const tick = () => {
      let delta = goal.current - current.current
      delta = ((((delta + 180) % 360) + 360) % 360) - 180

      if (Math.abs(delta) < 0.05) {
        current.current = goal.current
      } else {
        // Proportional, so a big turn starts fast and settles rather than
        // arriving at a constant speed, which reads as mechanical.
        current.current += delta * 0.18
      }

      setShown(((current.current % 360) + 360) % 360)
      frame = requestAnimationFrame(tick)
    }

    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [])

  return shown
}

export function Compass({ world, minimal }: { world: World | null; minimal: boolean }) {
  // Called before the early return: a hook cannot sit behind a condition.
  const heading = useSmoothHeading(world?.heading ?? 0)

  if (!world) return null
  // A window either side of the current heading, wrapped, so the tape reads as
  // continuous rather than snapping at north.
  const span = minimal ? 60 : 90
  const ticks: Array<{ deg: number; offset: number; label: string }> = []

  /*
   * A LABEL ONLY AT THE EIGHT CARDINALS. Everything else is a bare tick.
   *
   * Every tick used to print its bearing, so thirteen three-digit numbers were
   * competing for about 360 pixels and the strip came out as an unreadable band
   * of digits. A compass is glanced at, and what is wanted from a glance is
   * which way is north, not that the bearing 45 degrees to the right is 285.
   *
   * Ticks every 15 degrees still give the tape its sense of motion; they just
   * stop shouting numbers. The exact bearing is a separate readout at the
   * pointer, where there is room for it and where the eye already is.
   */
  for (let d = -span; d <= span; d += 15) {
    const deg = (((heading + d) % 360) + 360) % 360

    // Nearest 15 degree step, so a cardinal is matched despite the heading
    // being a float from the interpolator.
    const snapped = Math.round(deg / 15) * 15 % 360
    const cardinal = CARDINALS.find(([c]) => c === snapped)

    ticks.push({
      deg,
      offset: ((d + span) / (span * 2)) * 100,
      label: cardinal ? cardinal[1] : '',
    })
  }

  return (
    <div className={`hud-compass ${minimal ? 'is-minimal' : ''}`}>
      <span className="hud-compass__pointer" aria-hidden="true" />
      <span className="hud-compass__bearing">{Math.round(heading).toString().padStart(3, '0')}</span>
      <div className="hud-compass__tape">
        {ticks.map((t, i) => (
          <span
            key={`${t.deg}-${i}`}
            className={`hud-compass__tick ${CARDINALS.some(([c]) => c === t.deg) ? 'is-cardinal' : ''}`}
            style={{ left: `${t.offset}%` }}
          >
            {t.label ? <b>{t.label}</b> : null}
            <i />
          </span>
        ))}
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Location, money, session, voice, identity
// ---------------------------------------------------------------------------

export function Location({ world }: { world: World | null }) {
  if (!world || !world.street) return null

  return (
    <div className="hud-location">
      <span className="hud-location__pin" aria-hidden="true" />
      <div>
        <div className="hud-location__street">
          {world.street}
          {/* Only at a junction. Mid-block the second hash is zero, which is
              what stops a stale crossing name hanging around. */}
          {world.crossing ? ` / ${world.crossing}` : ''}
        </div>
        <div className="hud-location__zone">{world.zone || 'Current location'}</div>
      </div>
    </div>
  )
}

export function Session({ player }: { player: Player | null }) {
  if (!player) return null
  const time = `${String(player.hour).padStart(2, '0')}:${String(player.minute).padStart(2, '0')}`
  return (
    <div className="hud-chips">
      <span className="hud-chip">{player.players} <i>#</i></span>
      <span className="hud-chip">{time}</span>
    </div>
  )
}

