/**
 * The clothing tab: silhouette centred, slot rails down both edges.
 *
 * PRESENTATION ONLY FOR NOW, and deliberately so.
 *
 * ox_inventory's NUI contract has no clothing surface at all: none of its seven
 * inbound actions carry worn clothing and none of its eleven callbacks accept a
 * change to it. So there is nothing stock to render against and nothing stock to
 * call. Making the rail clickable would mean inventing state on the page, which
 * is exactly the authority this app must never take.
 *
 * Wiring it needs a som-inventory server event owning the worn state, plus a
 * bridge callback registered in ox_inventory so the page can reach it. Until
 * that exists the rail shows the slots and says it is not wired, which is
 * honest, rather than moving pixels that persist nothing.
 */

import { formatWeight } from '../state'

/** GTA component slots, in the order the rails read top to bottom. */
const LEFT_RAIL = [
  { id: 'hat', label: 'Hat' },
  { id: 'mask', label: 'Mask' },
  { id: 'glasses', label: 'Glasses' },
  { id: 'ears', label: 'Ears' },
  { id: 'neck', label: 'Neck' },
  { id: 'shirt', label: 'Shirt' },
]

const RIGHT_RAIL = [
  { id: 'bag', label: 'Bag' },
  { id: 'armour', label: 'Armour' },
  { id: 'watch', label: 'Watch' },
  { id: 'bracelet', label: 'Bracelet' },
  { id: 'pants', label: 'Pants' },
  { id: 'shoes', label: 'Shoes' },
]

export function Clothing({ weight }: { weight: number }) {
  const worn = 0

  return (
    <section className="som-panel som-panel--primary som-clothing">
      <header className="som-panel__head">
        <span className="som-panel__icon" aria-hidden="true" />
        <h2 className="som-panel__title">Clothing</h2>
        <div className="som-panel__weight">
          <span className="som-panel__kg">{formatWeight(worn)}</span>
          <span className="som-panel__bar">
            {Array.from({ length: 12 }, (_, i) => (
              <i key={i} />
            ))}
          </span>
          <span className="som-panel__kg">{weight ? formatWeight(weight) : ''}</span>
        </div>
      </header>

      <div className="som-clothing__body">
        <div className="som-clothing__rail">
          {LEFT_RAIL.map((s) => (
            <button key={s.id} className="som-clothing__slot" disabled title={`${s.label} (not wired)`}>
              <span className="som-clothing__slot-label">{s.label}</span>
            </button>
          ))}
        </div>

        <div className="som-clothing__figure" role="img" aria-label="Character silhouette" />

        <div className="som-clothing__rail">
          {RIGHT_RAIL.map((s) => (
            <button key={s.id} className="som-clothing__slot" disabled title={`${s.label} (not wired)`}>
              <span className="som-clothing__slot-label">{s.label}</span>
            </button>
          ))}
        </div>
      </div>

      <p className="som-clothing__note">
        Clothing is not wired yet. ox_inventory&rsquo;s NUI contract carries no worn
        state, so this needs a som-inventory server event before it can do anything.
      </p>

      <div className="som-clothing__footer">
        <button className="som-btn som-btn--drop" disabled>
          Remove all clothes
        </button>
        <button className="som-btn som-btn--give" disabled>
          Wear all clothes
        </button>
      </div>
    </section>
  )
}
