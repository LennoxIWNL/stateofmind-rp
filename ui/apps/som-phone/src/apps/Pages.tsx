import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { type ActionResult, Empty, Row, Section, Segment, callApp, digits, usePhone } from '@som/phone-sdk'

interface Advert {
  id: number
  handle: string
  category: string
  title: string
  body: string
  price?: string | null
  number?: string | null
  business?: string | null
  mine: boolean
}
interface Person { firstname: string; lastname: string; phone: string }

const LABELS: Record<string, string> = {
  for_sale: 'For sale', wanted: 'Wanted', services: 'Services', business: 'Business', property: 'Property', vehicles: 'Vehicles', other: 'Other',
}
const label = (c: string) => LABELS[c] || c

function Yellow() {
  const { toast } = usePhone()
  const [adverts, setAdverts] = useState<Advert[] | null>(null)
  const [categories, setCategories] = useState<string[]>([])
  const [business, setBusiness] = useState<string | null>(null)
  const [filter, setFilter] = useState('')
  const [writing, setWriting] = useState(false)
  const [contact, setContact] = useState<number | null>(null)
  const [message, setMessage] = useState('')
  const [form, setForm] = useState({ category: 'for_sale', title: '', body: '', price: '', showNumber: false, asBusiness: false })

  const load = useCallback(async () => {
    const res = await callApp<{ adverts?: Advert[]; categories?: string[]; business?: string | null }>('pages', 'adverts', filter ? { category: filter } : {})
    setAdverts(res.adverts || [])
    setCategories(res.categories || [])
    setBusiness(res.business || null)
  }, [filter])

  useEffect(() => { void load() }, [load])

  const post = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('pages', 'post', form)
    if (!res.success) return toast(String(res.error || 'Could not post'), true)
    setWriting(false)
    setForm({ ...form, title: '', body: '', price: '' })
    await load()
  }

  const send = async (e: FormEvent) => {
    e.preventDefault()
    if (contact === null) return
    const res = await callApp('pages', 'contact', { id: contact, body: message })
    if (!res.success) return toast(String(res.error || 'Could not send'), true)
    toast('Sent')
    setContact(null)
    setMessage('')
  }

  const remove = async (id: number) => {
    const res = await callApp('pages', 'remove', { id })
    if (!res.success) return toast(String(res.error || 'Could not remove'), true)
    await load()
  }

  if (!adverts) return <Empty icon="inbox" text="Loading" />

  return (
    <>
      <select className="input" aria-label="Category" value={filter} onChange={(e) => setFilter(e.target.value)}>
        <option value="">All categories</option>
        {categories.map((c) => <option key={c} value={c}>{label(c)}</option>)}
      </select>
      <button type="button" className="btn btn--primary" onClick={() => setWriting(!writing)}>{writing ? 'Cancel' : 'Place an advert'}</button>

      {writing && (
        <form className="form" onSubmit={post}>
          <select className="input" aria-label="Advert category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            {categories.map((c) => <option key={c} value={c}>{label(c)}</option>)}
          </select>
          <input className="input" aria-label="Title" maxLength={48} placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <textarea className="input input--area" aria-label="Description" maxLength={280} rows={3} placeholder="Description" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
          <input className="input" aria-label="Price" maxLength={24} placeholder="Price (optional)" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
          <label className="check"><input type="checkbox" checked={form.showNumber} onChange={(e) => setForm({ ...form, showNumber: e.target.checked })} /> Show my number</label>
          {business && <label className="check"><input type="checkbox" checked={form.asBusiness} onChange={(e) => setForm({ ...form, asBusiness: e.target.checked })} /> As {business}</label>}
          <button className="btn btn--primary" type="submit">Publish</button>
        </form>
      )}

      {adverts.length === 0 ? <Empty icon="inbox" text="No adverts here" /> : (
        <div className="posts">
          {adverts.map((a) => (
            <article key={a.id} className="post">
              <header className="post__head">
                <strong>{a.title}</strong>
                <span className="pill">{label(a.category)}</span>
              </header>
              <p className="post__body">{a.body}</p>
              <p className="muted">{[a.price, a.business || `@${a.handle}`, a.number].filter(Boolean).join(' · ')}</p>
              <footer className="post__foot">
                {a.mine
                  ? <button type="button" className="link" onClick={() => void remove(a.id)}>Remove</button>
                  : <button type="button" className="link" onClick={() => setContact(contact === a.id ? null : a.id)}>Message</button>}
              </footer>
              {contact === a.id && (
                <form className="form form--inline" onSubmit={send}>
                  <input className="input" aria-label="Message" maxLength={280} placeholder="Message" value={message} onChange={(e) => setMessage(e.target.value)} />
                  <button className="btn btn--primary" type="submit">Send</button>
                </form>
              )}
            </article>
          ))}
        </div>
      )}
    </>
  )
}

function White() {
  const { toast } = usePhone()
  const [listed, setListed] = useState<boolean | null>(null)
  const [q, setQ] = useState('')
  const [people, setPeople] = useState<Person[] | null>(null)

  useEffect(() => { void callApp<{ listed?: boolean }>('pages', 'listing').then((r) => setListed(r.listed === true)) }, [])

  const toggle = async () => {
    const res = await callApp<ActionResult & { listed?: boolean }>('pages', 'list', { listed: !listed })
    if (res.success === false) return toast(String(res.error || 'Could not change'), true)
    setListed(res.listed === true)
  }

  const search = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp<ActionResult & { people?: Person[] }>('pages', 'search', { q })
    if (res.success === false) return toast(String(res.error || 'Search failed'), true)
    setPeople(res.people || [])
  }

  return (
    <>
      <label className="check">
        <input type="checkbox" checked={listed === true} disabled={listed === null} onChange={() => void toggle()} /> List my name and number
      </label>
      <form className="form form--inline" onSubmit={search}>
        <input className="input" aria-label="Search by name" maxLength={32} placeholder="Search by name" value={q} onChange={(e) => setQ(e.target.value)} />
        <button className="btn btn--primary" type="submit">Search</button>
      </form>
      {people && (people.length === 0 ? <Empty icon="inbox" text="No listing found" /> : (
        <div className="list">
          {people.map((p) => (
            <Row key={p.phone} title={`${p.firstname} ${p.lastname}`} sub={digits(p.phone).replace(/^(\d{3})(\d+)$/, '$1-$2')} />
          ))}
        </div>
      ))}
    </>
  )
}

export function Pages() {
  const [tab, setTab] = useState('yellow')
  return (
    <div className="app-view__body">
      <Segment tabs={[{ id: 'yellow', label: 'Adverts' }, { id: 'white', label: 'People' }]} active={tab} onChange={setTab} />
      <Section>{tab === 'yellow' ? 'Yellow pages' : 'White pages'}</Section>
      {tab === 'yellow' ? <Yellow /> : <White />}
    </div>
  )
}
