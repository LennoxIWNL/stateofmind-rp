import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { type ActionResult, Empty, Row, callApp, usePhone } from '@som/phone-sdk'

interface Note { id: number; title: string; body: string }

export function Notes() {
  const { toast } = usePhone()
  const [notes, setNotes] = useState<Note[] | null>(null)
  const [editing, setEditing] = useState<Note | 'new' | null>(null)
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')

  const load = useCallback(async () => {
    const res = await callApp<ActionResult & { notes?: Note[] }>('notes', 'list')
    setNotes(res.notes || [])
  }, [])

  useEffect(() => { void load() }, [load])

  const open = (note: Note | 'new') => {
    setEditing(note)
    setTitle(note === 'new' ? '' : note.title)
    setBody(note === 'new' ? '' : note.body)
  }

  const save = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('notes', 'save', { id: editing !== 'new' && editing ? editing.id : undefined, title, body })
    if (!res.success) return toast(String(res.error || 'Could not save'), true)
    setEditing(null)
    await load()
  }

  const remove = async () => {
    if (!editing || editing === 'new') return
    const res = await callApp('notes', 'remove', { id: editing.id })
    if (!res.success) return toast(String(res.error || 'Could not delete'), true)
    setEditing(null)
    await load()
  }

  if (editing) {
    return (
      <div className="app-view__body">
        <button type="button" className="back" onClick={() => setEditing(null)}>Notes</button>
        <form className="form" onSubmit={save}>
          <input className="input" aria-label="Title" maxLength={40} placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} />
          <textarea className="input input--area" aria-label="Note" maxLength={2000} rows={9} placeholder="Write here" value={body} onChange={(e) => setBody(e.target.value)} />
          <div className="form--inline">
            {editing !== 'new' && <button type="button" className="link" onClick={() => void remove()}>Delete</button>}
            <button className="btn btn--primary" type="submit">Save</button>
          </div>
        </form>
      </div>
    )
  }

  if (!notes) return <div className="app-view__body"><Empty icon="note" text="Loading" /></div>

  return (
    <div className="app-view__body">
      <button type="button" className="btn btn--primary" onClick={() => open('new')}>New note</button>
      {notes.length === 0 ? <Empty icon="note" text="No notes yet" /> : (
        <div className="list">
          {notes.map((n) => (
            <button key={n.id} type="button" className="rowbtn" onClick={() => open(n)}>
              <Row title={n.title} sub={n.body.split('\n')[0]} />
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
