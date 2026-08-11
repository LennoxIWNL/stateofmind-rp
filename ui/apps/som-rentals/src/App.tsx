import { useState } from 'react'
import { Button, Card, StatusBadge, fetchNui, useNuiEvent } from '@som/ui-kit'

/**
 * The rental counter.
 *
 * Same card grid as the armoury, with the item icon replaced by a vehicle shot
 * and the cart button replaced by Rent: a rental is one decision about one
 * vehicle, so there is nothing to accumulate and a basket would be ceremony.
 *
 * Renting is still the server's call. som-rentals:server:rent re-resolves the
 * model against the location's own list, prices it, and takes the deposit, so
 * this posts a model name and an account and nothing else.
 */

interface RentalVehicle {
  model: string
  label: string
  class?: string
  price: number
}

interface PaymentOption {
  account: string
  label: string
  balance: number
}

interface CatalogueData {
  label?: string
  vehicles: RentalVehicle[]
  payment?: PaymentOption[]
  deposit?: number
}

const money = (n: number) => `$${Number(n || 0).toLocaleString('en-US')}`

/**
 * Vehicle art.
 *
 * Served from som-assets so it is one folder for the whole server rather than a
 * copy per resource. Missing files are expected while the pack is incomplete
 * and are handled by hiding the image, which leaves the plate-style fallback
 * underneath rather than a broken-image glyph.
 */
const artFor = (model: string) => `https://cfx-nui-som-assets/img/vehicles/${model}.png`

export function App() {
  const [data, setData] = useState<CatalogueData | null>(null)
  const [account, setAccount] = useState('')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')

  useNuiEvent<CatalogueData>('open', (payload) => {
    setData(payload)
    setError('')

    const options = payload.payment ?? []
    setAccount((options.find((p) => p.balance > 0) ?? options[0])?.account ?? '')
  })

  useNuiEvent('close', () => setData(null))

  const close = () => {
    setData(null)
    void fetchNui('close')
  }

  const rent = async (vehicle: RentalVehicle) => {
    if (busy) return

    setBusy(vehicle.model)
    setError('')

    const res = await fetchNui<{ success: boolean; error?: string }>(
      'rent',
      { model: vehicle.model, account },
      { success: false, error: 'no response' },
    )

    setBusy('')

    // Success closes the panel from the Lua side, so there is nothing to do
    // here but surface a refusal.
    if (!res.success) setError(res.error || 'Could not rent that')
  }

  if (!data) return null

  const selected = data.payment?.find((p) => p.account === account)

  return (
    <div className="som-root shell">
      <Card
        className="rentals"
        title={
          <div>
            <div className="head__title">{data.label || 'Vehicle Rental'}</div>
            <div className="head__sub">Deposit refunded on return</div>
          </div>
        }
        aside={
          <div className="pay">
            {(data.payment ?? []).map((option) => (
              <Button
                key={option.account}
                variant={option.account === account ? 'primary' : 'ghost'}
                onClick={() => setAccount(option.account)}
              >
                {option.label}
                <span className="som-num pay__value">{money(option.balance)}</span>
              </Button>
            ))}
          </div>
        }
        footer={
          <>
            <span className="hint">
              {error || (data.deposit ? `Deposit ${money(data.deposit)}, refunded on return` : '')}
            </span>
            <Button variant="ghost" onClick={close}>Close</Button>
          </>
        }
      >
        <div className="grid">
          {data.vehicles.map((vehicle) => {
            const unaffordable = !selected || selected.balance < vehicle.price

            return (
              <article key={vehicle.model} className={`veh${unaffordable ? ' is-blocked' : ''}`}>
                <div className="veh__art">
                  <img
                    src={artFor(vehicle.model)}
                    alt=""
                    loading="lazy"
                    onError={(event) => event.currentTarget.remove()}
                  />
                  {/* Sits under the image and shows through when it is absent.
                      A plate reads as deliberate where a broken icon does not. */}
                  <span className="veh__plate som-num">{vehicle.model.toUpperCase()}</span>
                </div>

                <div className="veh__body">
                  <span className="veh__name">{vehicle.label}</span>
                  {vehicle.class && <StatusBadge tone="neutral">{vehicle.class}</StatusBadge>}
                </div>

                <div className="veh__foot">
                  <span className="som-num veh__price">{money(vehicle.price)}</span>
                  <Button
                    variant={unaffordable ? 'ghost' : 'primary'}
                    disabled={unaffordable}
                    busy={busy === vehicle.model}
                    onClick={() => rent(vehicle)}
                  >
                    Rent
                  </Button>
                </div>
              </article>
            )
          })}

          {!data.vehicles.length && <p className="empty">Nothing available here.</p>}
        </div>
      </Card>
    </div>
  )
}
