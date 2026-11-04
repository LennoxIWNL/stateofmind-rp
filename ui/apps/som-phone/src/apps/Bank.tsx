import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Empty, Icon, Row, Section, Segment, callApp, digits, money, usePhone } from '@som/phone-sdk'

interface Tx { id: number; account: string; amount: number; direction: string; label: string; created_at: string }
interface Bill { id: number; from_name: string; amount: number; reason: string }
interface Saved { account_no: string; label: string }
interface Overview {
  accountNo: string
  money: { bank: number; cash: number }
  history: Tx[]
  bills: Bill[]
  saved: Saved[]
}

function Picks({ saved, empty, onPick, current }: { saved: Saved[]; empty: string; onPick: (n: string) => void; current: string }) {
  if (!saved.length) return <div className="picks"><div className="picks__empty">{empty}</div></div>

  return (
    <div className="picks">
      {saved.map((s) => (
        <button key={s.account_no} type="button" className={`pick${current === s.account_no ? ' is-active' : ''}`} onClick={() => onPick(s.account_no)}>
          <span>{s.label}</span>
          <span className="pick__no">{s.account_no}</span>
        </button>
      ))}
    </div>
  )
}

export function Bank() {
  const { toast, badge } = usePhone()
  const [data, setData] = useState<Overview | null>(null)
  const [tab, setTab] = useState('history')
  const [bill, setBill] = useState({ account: '', amount: '', reason: '' })
  const [send, setSend] = useState({ account: '', amount: '' })

  const load = useCallback(async () => {
    const res = await callApp<Overview & { success: boolean }>('bank', 'overview')
    if (!res || !res.accountNo) return
    setData(res)
    badge('bank', (res.bills || []).length)
  }, [badge])

  useEffect(() => { void load() }, [load])

  if (!data) return <div className="app-view__body"><Empty icon="receipt" text="Loading" /></div>

  const share = async () => {
    const res = await callApp('bank', 'share')
    toast(res.success ? `Shared with ${res.shared} nearby` : String(res.error || 'Could not share'), !res.success)
  }

  const submitBill = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('bank', 'bill', { accountNo: digits(bill.account), amount: Number(digits(bill.amount)), reason: bill.reason })
    toast(res.success ? 'Bill sent' : String(res.error || 'Could not send'), !res.success)
    if (res.success) setBill({ account: '', amount: '', reason: '' })
  }

  const submitSend = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('bank', 'transfer', { accountNo: digits(send.account), amount: Number(digits(send.amount)) })
    toast(res.success ? 'Transfer sent' : String(res.error || 'Could not transfer'), !res.success)
    if (res.success) {
      setSend({ account: '', amount: '' })
      await load()
    }
  }

  const answer = async (action: 'pay' | 'decline', id: number) => {
    const res = await callApp('bank', action, { id })
    if (!res.success && action === 'pay') toast(String(res.error || 'Could not pay'), true)
    await load()
  }

  return (
    <div className="app-view__body">
      <div className="balance">
        <span className="balance__label">Available</span>
        <div className="balance__value">{money(data.money?.bank)}</div>
        <div className="balance__cash">{money(data.money?.cash)} in cash</div>
        <button className="account" type="button" onClick={share}>
          <span className="account__no">{data.accountNo || '--------'}</span>
          <span className="account__hint">Share nearby</span>
        </button>
      </div>

      <Segment
        active={tab}
        onChange={setTab}
        tabs={[{ id: 'history', label: 'Activity' }, { id: 'bills', label: 'Bills', count: data.bills.length }, { id: 'send', label: 'Send' }]}
      />

      {tab === 'history' && (
        data.history.length === 0 ? <Empty icon="receipt" text="No transactions yet" /> : (
          <div className="list">
            {data.history.map((t) => {
              const isIn = t.direction === 'credit'
              const when = new Date(t.created_at)
              return (
                <Row
                  key={t.id}
                  title={t.label || 'Transaction'}
                  sub={`${t.account}${Number.isNaN(when.getTime()) ? '' : ' · ' + when.toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}`}
                  glyph={<span className={`row__glyph row__glyph--${isIn ? 'in' : 'out'}`}><Icon name={isIn ? 'arrowDown' : 'arrowUp'} /></span>}
                  amount={<span className={`row__amount row__amount--${isIn ? 'in' : 'out'}`}>{isIn ? '+' : '-'}{money(t.amount)}</span>}
                />
              )
            })}
          </div>
        )
      )}

      {tab === 'bills' && (
        <>
          {data.bills.length === 0 ? <Empty icon="inbox" text="No outstanding bills" /> : (
            <div className="list">
              {data.bills.map((b) => (
                <Row
                  key={b.id}
                  title={b.reason}
                  sub={`${b.from_name} · ${money(b.amount)}`}
                  actions={<>
                    <button type="button" className="btn btn--primary btn--sm" onClick={() => answer('pay', b.id)}>Pay</button>
                    <button type="button" className="btn btn--danger btn--sm" onClick={() => answer('decline', b.id)}>Decline</button>
                  </>}
                />
              ))}
            </div>
          )}

          <Section>Bill someone</Section>
          <form className="form" onSubmit={submitBill}>
            <div className="field">
              <label className="field__label" htmlFor="bill-account">Account number</label>
              <input id="bill-account" className="input input--mono" inputMode="numeric" maxLength={24} autoComplete="off" placeholder="00000000"
                value={bill.account} onChange={(e) => setBill({ ...bill, account: digits(e.target.value) })} />
              <Picks saved={data.saved} current={bill.account} empty="Nobody has shared their account with you recently" onPick={(n) => setBill({ ...bill, account: n })} />
            </div>
            <div className="field">
              <label className="field__label" htmlFor="bill-amount">Amount</label>
              <div className="amount">
                <span className="amount__sign">$</span>
                <input id="bill-amount" className="input input--amount" inputMode="numeric" autoComplete="off" placeholder="0"
                  value={bill.amount} onChange={(e) => setBill({ ...bill, amount: digits(e.target.value) })} />
              </div>
            </div>
            <div className="field">
              <label className="field__label" htmlFor="bill-reason">Reason</label>
              <input id="bill-reason" className="input" maxLength={128} placeholder="What is this for?"
                value={bill.reason} onChange={(e) => setBill({ ...bill, reason: e.target.value })} />
            </div>
            <button className="btn btn--primary" type="submit">Send bill</button>
          </form>
        </>
      )}

      {tab === 'send' && (
        <>
          <form className="form" onSubmit={submitSend}>
            <div className="field">
              <label className="field__label" htmlFor="send-account">Account number</label>
              <input id="send-account" className="input input--mono" inputMode="numeric" maxLength={24} autoComplete="off" placeholder="00000000"
                value={send.account} onChange={(e) => setSend({ ...send, account: digits(e.target.value) })} />
              <Picks saved={data.saved} current={send.account} empty="No saved accounts. Type any number to send." onPick={(n) => setSend({ ...send, account: n })} />
            </div>
            <div className="field">
              <label className="field__label" htmlFor="send-amount">Amount</label>
              <div className="amount">
                <span className="amount__sign">$</span>
                <input id="send-amount" className="input input--amount" inputMode="numeric" autoComplete="off" placeholder="0"
                  value={send.amount} onChange={(e) => setSend({ ...send, amount: digits(e.target.value) })} />
              </div>
            </div>
            <button className="btn btn--primary" type="submit">Transfer</button>
          </form>
          <p className="hint">Send to any account number. Transfers are instant and cannot be reversed, so a bill is safer for both sides when you are owed money.</p>
        </>
      )}
    </div>
  )
}
