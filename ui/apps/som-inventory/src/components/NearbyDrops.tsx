/**
 * The `ITEMS DROPPED NEARBY` section.
 *
 * Shows THAT drops are nearby, not what is in them, and that limit is
 * deliberate rather than a shortcut. Knowing the contents of a container you
 * have not opened is not something the stock inventory grants, and reading it
 * out here would be a new capability rather than a new surface.
 *
 * Opening one goes through ox_inventory's own `openNearbyInventory`, so the
 * distance and access rules that apply to walking up to a drop apply here too.
 */

import { useEffect, useState } from 'react'
import { fetchNui } from '@som/ui-kit'

type Drop = { id: string; distance: number }

export function NearbyDrops({ active }: { active: boolean }) {
  const [drops, setDrops] = useState<Drop[]>([])

  useEffect(() => {
    if (!active) {
      setDrops([])
      return
    }

    let alive = true
    const poll = async () => {
      const list = await fetchNui<Drop[]>('somNearbyDrops', {}, [])
      if (alive) setDrops(Array.isArray(list) ? list : [])
    }

    void poll()
    const id = setInterval(poll, 1000)
    return () => {
      alive = false
      clearInterval(id)
    }
  }, [active])

  if (!drops.length) return null

  return (
    <div className="som-drops">
      <div className="som-drops__title">Items dropped nearby</div>
      <div className="som-drops__list">
        {drops.map((d) => (
          <button
            key={d.id}
            className="som-drops__item"
            onClick={() => void fetchNui('somOpenNearbyDrop', {})}
          >
            <span className="som-drops__bag" aria-hidden="true" />
            <span className="som-drops__dist">{d.distance}m</span>
          </button>
        ))}
      </div>
    </div>
  )
}
