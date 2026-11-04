import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Empty, Icon, Row, Section, callApp, digits, usePhone } from '@som/phone-sdk'

interface Contact { number: string; name: string }

export function Contacts() {
  const { toast, open } = usePhone()
  const [contacts, setContacts] = useState<Contact[] | null>(null)
  const [form, setForm] = useState({ name: '', number: '' })

  const load = useCallback(async () => {
    const res = await callApp<{ contacts?: Contact[] }>('contacts', 'list')
    setContacts(res.contacts || [])
  }, [])
  useEffect(() => { void load() }, [load])

  const save = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('contacts', 'save', { name: form.name, number: form.number })
    if (!res.success) return toast(String(res.error || 'Could not save'), true)
    setForm({ name: '', number: '' })
    await load()
  }

  const remove = async (number: string) => {
    await callApp('contacts', 'remove', { number })
    await load()
  }

  const call = async (number: string) => {
    const res = await callApp('phone', 'dial', { number })
    if (!res.success) toast(String(res.error || 'Could not call'), true)
  }

  if (!contacts) return <div className="app-view__body"><Empty icon="contacts" text="Loading" /></div>

  return (
    <div className="app-view__body">
      {contacts.length === 0 ? <Empty icon="contacts" text="No contacts yet" /> : (
        <div className="list">
          {contacts.map((c) => (
            <Row key={c.number} title={c.name} sub={c.number}
              actions={<>
                <button type="button" className="btn btn--primary btn--sm" aria-label={`Call ${c.name}`} onClick={() => call(c.number)}><Icon name="phone" /></button>
                <button type="button" className="btn btn--sm" aria-label={`Message ${c.name}`} onClick={() => open('messages', c.number)}><Icon name="message" /></button>
                <button type="button" className="btn btn--danger btn--sm" aria-label={`Delete ${c.name}`} onClick={() => remove(c.number)}>Delete</button>
              </>}
            />
          ))}
        </div>
      )}

      <Section>Add a contact</Section>
      <form className="form" onSubmit={save}>
        <div className="field">
          <label className="field__label" htmlFor="contact-name">Name</label>
          <input id="contact-name" className="input" maxLength={32} autoComplete="off" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </div>
        <div className="field">
          <label className="field__label" htmlFor="contact-number">Number</label>
          <input id="contact-number" className="input input--mono" inputMode="numeric" maxLength={8} autoComplete="off" placeholder="5550001"
            value={form.number} onChange={(e) => setForm({ ...form, number: digits(e.target.value) })} />
        </div>
        <button className="btn btn--primary" type="submit">Save</button>
      </form>
    </div>
  )
}
