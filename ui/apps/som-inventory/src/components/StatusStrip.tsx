/**
 * The bottom status strip.
 *
 * The data for this is NOT in ox_inventory's NUI contract: none of its seven
 * inbound messages carry player condition. It arrives on a `somStatus` message
 * pushed by som_bridge.lua, which is a client script and can read the ped.
 *
 * The bridge does two things this component depends on and should not have to
 * redo: it normalises health out of GTA's 100-to-200 range, and it sends only on
 * change. Do not add a poll here.
 */

export type Status = {
  health: number
  armour: number
  hunger: number
  thirst: number
}

const BARS: Array<{ key: keyof Status; label: string; tone: string }> = [
  { key: 'health', label: 'Health', tone: 'health' },
  { key: 'armour', label: 'Armour', tone: 'armour' },
  { key: 'hunger', label: 'Hunger', tone: 'hunger' },
  { key: 'thirst', label: 'Thirst', tone: 'thirst' },
]

export function StatusStrip({ status }: { status: Status | null }) {
  if (!status) return null

  return (
    <div className="som-status">
      {BARS.map(({ key, label, tone }) => {
        const value = Math.max(0, Math.min(100, status[key] ?? 0))

        // Armour at zero stands down rather than showing an empty bar, the same
        // subtractive rule som-hud already uses: a permanently empty gauge is
        // noise that teaches the player to stop reading the row.
        if (key === 'armour' && value === 0) return null

        return (
          <div key={key} className={`som-status__item som-status__item--${tone}`} title={label}>
            <span className="som-status__value">{value}%</span>
            <span className="som-status__bar">
              <span style={{ width: `${value}%` }} />
            </span>
          </div>
        )
      })}
    </div>
  )
}
