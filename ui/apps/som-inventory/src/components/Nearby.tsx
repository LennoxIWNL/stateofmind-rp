/**
 * Drag-to-give: the nearby-player targets that appear while a drag is live.
 *
 * The list is READ ONLY and client-derived. It answers "who could I drop this
 * on", which is a rendering question. Whether the give is allowed is decided
 * again by som-inventory's server event against the server's own view of both
 * positions, so a client that lies to this list only lies to itself about what
 * to draw.
 */

export type NearbyPlayer = {
  /** SERVER id. The local player index is meaningless across the network. */
  id: number
  name: string
  distance: number
}

type Props = {
  nearby: NearbyPlayer[]
  onGive: (target: number) => void
}

export function NearbyGive({ nearby, onGive }: Props) {
  return (
    <div className="som-nearby">
      <div className="som-nearby__title">Drop on a person to give</div>
      {nearby.map((p) => (
        <button
          key={p.id}
          className="som-nearby__target"
          // pointerup, not click: the drag is already holding the pointer down,
          // so a click never arrives. This is the release landing on a target.
          onPointerUp={() => onGive(p.id)}
        >
          <span className="som-nearby__name">{p.name}</span>
          <span className="som-nearby__dist">{p.distance}m</span>
        </button>
      ))}
    </div>
  )
}
