import { useEffect, useState } from 'react'
import { type ActionResult, Empty, Row, callApp } from '@som/phone-sdk'

interface Vehicle { plate: string; model: string; garage: string; state: 'out' | 'garaged' | 'impounded' }

const STATE: Record<Vehicle['state'], string> = { out: 'Out on the road', garaged: 'Stored', impounded: 'Impounded' }

export function Garage() {
  const [vehicles, setVehicles] = useState<Vehicle[] | null>(null)

  useEffect(() => { void callApp<ActionResult & { vehicles?: Vehicle[] }>('garage', 'list').then((r) => setVehicles(r.vehicles || [])) }, [])

  if (!vehicles) return <div className="app-view__body"><Empty icon="car" text="Loading" /></div>
  if (vehicles.length === 0) return <div className="app-view__body"><Empty icon="car" text="No vehicles" /></div>

  return (
    <div className="app-view__body">
      <div className="list">
        {vehicles.map((v) => (
          <Row key={v.plate} title={`${v.model.toUpperCase()}  ${v.plate}`} sub={v.state === 'garaged' ? `${STATE[v.state]} at ${v.garage}` : STATE[v.state]} />
        ))}
      </div>
    </div>
  )
}
