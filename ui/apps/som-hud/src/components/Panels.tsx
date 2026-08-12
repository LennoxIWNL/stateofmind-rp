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

import type { Player, Status, Vehicle, World } from '../contract'

// ---------------------------------------------------------------------------
// Condition
// ---------------------------------------------------------------------------

const ICONS: Record<string, string> = {
  health: 'M12 21s-7-4.4-7-9.5A4.5 4.5 0 0 1 12 8a4.5 4.5 0 0 1 7 3.5C19 16.6 12 21 12 21z',
  armour: 'M12 2l7 3v6c0 4.5-3 8.3-7 11-4-2.7-7-6.5-7-11V5l7-3z',
  hunger: 'M6 4h9a4 4 0 0 1 0 8H6zM6 12h12v6a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2z',
  thirst: 'M12 3s6 6.4 6 10.2A6 6 0 0 1 6 13.2C6 9.4 12 3 12 3z',
  oxygen: 'M12 3a4 4 0 0 1 4 4v6a4 4 0 0 1-8 0V7a4 4 0 0 1 4-4zM8 17h8',
  stress: 'M4 12h4l2-5 3 10 2-5h5',
  voice: 'M12 3a3 3 0 0 1 3 3v6a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3zM5 11a7 7 0 0 0 14 0M12 18v3',
}

function Glyph({ name }: { name: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d={ICONS[name]} />
    </svg>
  )
}

type Ring = { key: string; value: number; show: boolean }

export function Condition({
  status,
  player,
}: {
  status: Status | null
  player: Player | null
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
      {player && (
        <div
          className={`hud-hex hud-hex--voice ${player.talking ? 'is-live' : ''}`}
          title={`Voice: ${player.voiceMode}${player.radio ? ` / radio ${player.radio}` : ''}`}
        >
          <span className="hud-hex__fill" style={{ height: player.talking ? '100%' : '0%' }} />
          <Glyph name="voice" />
        </div>
      )}
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

export function Compass({ world, minimal }: { world: World | null; minimal: boolean }) {
  if (!world) return null

  const heading = world.heading
  // A window either side of the current heading, wrapped, so the tape reads as
  // continuous rather than snapping at north.
  const span = minimal ? 60 : 90
  const ticks: Array<{ deg: number; offset: number; label: string }> = []

  for (let d = -span; d <= span; d += 15) {
    const deg = (((heading + d) % 360) + 360) % 360
    const cardinal = CARDINALS.find(([c]) => c === deg)
    ticks.push({
      deg,
      offset: ((d + span) / (span * 2)) * 100,
      label: cardinal ? cardinal[1] : String(deg),
    })
  }

  return (
    <div className={`hud-compass ${minimal ? 'is-minimal' : ''}`}>
      <span className="hud-compass__pointer" aria-hidden="true" />
      <div className="hud-compass__tape">
        {ticks.map((t, i) => (
          <span
            key={`${t.deg}-${i}`}
            className={`hud-compass__tick ${CARDINALS.some(([c]) => c === t.deg) ? 'is-cardinal' : ''}`}
            style={{ left: `${t.offset}%` }}
          >
            <b>{t.label}</b>
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

