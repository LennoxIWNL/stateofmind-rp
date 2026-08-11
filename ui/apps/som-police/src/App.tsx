import { useCallback, useMemo, useState } from 'react'
import {
  Button,
  Card,
  IconTile,
  Meter,
  StatusBadge,
  Stepper,
  Tabs,
  fetchNui,
  useNuiEvent,
} from '@som/ui-kit'
import type {
  ArmouryData,
  CartLine,
  CertsData,
  CheckoutResult,
  PaymentOption,
  StockEntry,
} from './types'

/**
 * The armoury, as a shop.
 *
 * Nothing here is an authority. The server filters the stock list by rank and
 * certification before it is ever sent, re-resolves every price from config at
 * checkout, and refuses anything it does not stock. The cart is a convenience
 * for the officer and is re-priced line by line on the way out, so editing this
 * file buys a nicer basket and no cheaper rifles.
 */

const money = (n: number) => `$${Number(n || 0).toLocaleString('en-US')}`

/** ox_inventory's own art, so an item looks the same here as in the bag. */
const artFor = (item: string) => `nui://ox_inventory/web/images/${item}.png`

type View = 'none' | 'armoury' | 'certs'

export function App() {
  const [view, setView] = useState<View>('none')
  const [data, setData] = useState<ArmouryData | null>(null)
  const [certs, setCerts] = useState<CertsData | null>(null)

  const [cart, setCart] = useState<CartLine[]>([])
  const [tab, setTab] = useState('issue')
  const [account, setAccount] = useState<string>('')
  const [busy, setBusy] = useState(false)
  const [receipt, setReceipt] = useState<string>('')

  const stock = useMemo(
    () => (tab === 'issue' ? (data?.issue ?? []) : (data?.personal ?? [])),
    [data, tab],
  )

  const byItem = useMemo(() => {
    const map = new Map<string, StockEntry>()
    for (const entry of [...(data?.issue ?? []), ...(data?.personal ?? [])]) map.set(entry.item, entry)
    return map
  }, [data])

  const total = useMemo(
    () => cart.reduce((sum, line) => sum + (byItem.get(line.item)?.price ?? 0) * line.count, 0),
    [cart, byItem],
  )

  const selected: PaymentOption | undefined = data?.payment.find((p) => p.account === account)

  /**
   * Cart changes are mirrored to Lua immediately rather than on close.
   *
   * Closing is not the only way to leave: the resource can restart, the player
   * can die, or the panel can be closed by something other than the button. A
   * cart that only saved on a clean exit would lose itself in every one of
   * those cases, which is precisely when losing it is most annoying.
   */
  const commit = useCallback((next: CartLine[]) => {
    setCart(next)
    void fetchNui('cartSet', { cart: next })
  }, [])

  const add = useCallback(
    (entry: StockEntry) => {
      const existing = cart.find((line) => line.item === entry.item)

      commit(
        existing
          ? cart.map((line) =>
              line.item === entry.item ? { ...line, count: line.count + 1 } : line,
            )
          : [...cart, { item: entry.item, count: 1 }],
      )

      setReceipt('')
    },
    [cart, commit],
  )

  const setCount = useCallback(
    (item: string, count: number) => {
      commit(
        count <= 0
          ? cart.filter((line) => line.item !== item)
          : cart.map((line) => (line.item === item ? { ...line, count } : line)),
      )
    },
    [cart, commit],
  )

  const checkout = useCallback(async () => {
    if (!cart.length || busy) return

    setBusy(true)

    const result = await fetchNui<CheckoutResult>(
      'checkout',
      { account },
      { success: false, error: 'no response', drawn: 0, failed: 0, spent: 0 },
    )

    setBusy(false)

    if (!result.success && result.error) {
      setReceipt(result.error)
      return
    }

    // Only the lines that could not be filled are kept, so a partly successful
    // checkout leaves the basket holding exactly what still needs sorting out
    // rather than everything or nothing.
    commit(result.remaining ?? [])

    setReceipt(
      result.failed > 0
        ? `Drew ${result.drawn}, ${result.failed} could not be filled`
        : result.spent > 0
          ? `Drew ${result.drawn} for ${money(result.spent)}`
          : `Drew ${result.drawn} from department issue`,
    )
  }, [cart, account, busy, commit])

  useNuiEvent<ArmouryData>('open', (payload) => {
    setData(payload)
    setCart(payload.cart ?? [])
    setReceipt('')

    // Default to an account that actually holds something, so an officer with
    // an empty wallet and a full bank is not told everything is unaffordable.
    const options = payload.payment ?? []
    setAccount((options.find((p) => p.balance > 0) ?? options[0])?.account ?? '')

    setTab(payload.issue?.length ? 'issue' : 'personal')
    setView('armoury')
  })

  useNuiEvent<ArmouryData>('refresh', (payload) => {
    setData((prev) => (prev ? { ...prev, ...payload } : payload))
  })

  useNuiEvent<CertsData>('certs', (payload) => {
    setCerts(payload)
    setView('certs')
  })

  useNuiEvent('close', () => setView('none'))

  const close = () => {
    setView('none')
    void fetchNui('close')
  }

  if (view === 'none') return null

  if (view === 'certs') {
    const held = certs?.certifications.filter((c) => c.held).length ?? 0
    const all = certs?.certifications.length ?? 0

    return (
      <div className="som-root shell">
        <Card
          className="certs"
          title={
            <div className="head">
              <span className="head__badge">{certs?.badge || 'LSPD'}</span>
              <div>
                <div className="head__title">Certifications</div>
                <div className="head__sub">{certs?.name || 'Officer'}</div>
              </div>
            </div>
          }
          aside={<span className="som-num head__count">{held}/{all}</span>}
          footer={
            <>
              <span className="hint">Granted by command staff through the MDT</span>
              <Button variant="ghost" onClick={close}>Close</Button>
            </>
          }
        >
          <div className="certs__list">
            {(certs?.certifications ?? []).map((cert) => (
              <div key={cert.label} className={`cert${cert.held ? ' is-held' : ''}`}>
                <span className="cert__mark">{cert.held ? '✓' : '✕'}</span>
                <div>
                  <span className="cert__label">{cert.label}</span>
                  <span className="cert__desc">
                    {cert.held ? (cert.description || '') : 'Not certified'}
                  </span>
                </div>
              </div>
            ))}
            {!all && <p className="empty">No certifications defined.</p>}
          </div>
        </Card>
      </div>
    )
  }

  return (
    <div className="som-root shell shell--shop">
      {/* Left: the goods. */}
      <Card
        className="shop"
        title={
          <div className="head">
            <span className="head__badge">LSPD</span>
            <div>
              <div className="head__title">Armoury</div>
              <div className="head__sub">{data?.label || 'Mission Row'}</div>
            </div>
          </div>
        }
        aside={
          <div className="wallet">
            {(data?.payment ?? []).map((option) => (
              <span key={option.account} className="wallet__chip">
                <span className="wallet__label">{option.label}</span>
                <span className="som-num wallet__value">{money(option.balance)}</span>
              </span>
            ))}
          </div>
        }
        footer={
          <>
            <span className="hint">{receipt || 'Click an item to add it to the basket'}</span>
            <Button variant="ghost" onClick={close}>Close</Button>
          </>
        }
      >
        <Tabs
          items={[
            { id: 'issue', label: 'Department issue', count: data?.issue.length },
            { id: 'personal', label: 'Personal', count: data?.personal.length },
          ]}
          active={tab}
          onChange={setTab}
        />

        <div className="grid">
          {stock.map((entry) => {
            const free = entry.price <= 0
            const unaffordable = !free && (!selected || selected.balance < entry.price)

            return (
              <IconTile
                key={entry.item}
                src={artFor(entry.item)}
                label={entry.label}
                count={entry.count}
                corner={free ? 'Issued' : money(entry.price)}
                tone={unaffordable ? 'blocked' : free ? 'rare' : 'common'}
                onClick={() => { if (!unaffordable) add(entry) }}
              />
            )
          })}

          {!stock.length && <p className="empty">Nothing stocked for you here.</p>}
        </div>
      </Card>

      {/* Right: the basket. */}
      <Card
        className="basket"
        title="Basket"
        aside={<StatusBadge tone={cart.length ? 'accent' : 'neutral'}>{cart.length}</StatusBadge>}
        footer={
          <div className="basket__foot">
            <div className="basket__total">
              <span>Total</span>
              <span className="som-num">{money(total)}</span>
            </div>

            <div className="basket__pay">
              {(data?.payment ?? []).map((option) => (
                <Button
                  key={option.account}
                  variant={option.account === account ? 'primary' : 'ghost'}
                  block
                  disabled={!cart.length}
                  busy={busy && option.account === account}
                  onClick={() => {
                    setAccount(option.account)
                    // Picking the account IS the confirmation, matching the
                    // reference: two buttons rather than a toggle plus a
                    // confirm, so paying is one decision and one click.
                    void checkout()
                  }}
                >
                  {option.label}
                </Button>
              ))}
            </div>

            <Button variant="danger" block disabled={!cart.length || busy} onClick={() => commit([])}>
              Clear
            </Button>
          </div>
        }
      >
        {cart.map((line) => {
          const entry = byItem.get(line.item)
          if (!entry) return null

          return (
            <div key={line.item} className="line">
              <img className="line__art" src={artFor(line.item)} alt="" onError={(e) => e.currentTarget.remove()} />

              <div className="line__body">
                <span className="line__name">{entry.label}</span>
                <span className="som-num line__price">
                  {entry.price > 0 ? money(entry.price * line.count) : 'Issued'}
                </span>
              </div>

              <Stepper value={line.count} onChange={(next) => setCount(line.item, next)} min={0} max={99} />
            </div>
          )
        })}

        {!cart.length && <p className="empty">Basket is empty.</p>}

        {selected && total > 0 && (
          <div className="basket__after">
            <span>{selected.label} after</span>
            <Meter
              value={Math.max(0, selected.balance - total)}
              max={Math.max(selected.balance, 1)}
              tone={selected.balance < total ? 'danger' : 'accent'}
            />
            <span className="som-num">{money(Math.max(0, selected.balance - total))}</span>
          </div>
        )}
      </Card>
    </div>
  )
}
