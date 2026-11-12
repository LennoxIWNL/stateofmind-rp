import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Empty, Row, callApp, digits, usePhone } from '@som/phone-sdk'

interface Thread { other: string; name?: string | null; body?: string; mine?: boolean; unread: number }
interface Msg { id: number; mine: boolean; body: string }

export function Messages({ arg }: { arg?: string }) {
  const { toast, badge } = usePhone()
  const [open, setOpen] = useState<string | null>(arg || null)
  const [threads, setThreads] = useState<Thread[] | null>(null)
  const [msgs, setMsgs] = useState<Msg[]>([])
  const [title, setTitle] = useState('')
  const [text, setText] = useState('')
  const [newNumber, setNewNumber] = useState('')
  const end = useRef<HTMLDivElement>(null)

  const loadThreads = useCallback(async () => {
    const res = await callApp<{ threads?: Thread[] }>('messages', 'threads')
    const list = res.threads || []
    setThreads(list)
    badge('messages', list.reduce((n, t) => n + t.unread, 0))
  }, [badge])

  const loadThread = useCallback(async (number: string) => {
    const res = await callApp<{ messages?: Msg[]; name?: string | null; number?: string }>('messages', 'thread', { number })
    setMsgs(res.messages || [])
    setTitle(res.name || res.number || number)
  }, [])

  useEffect(() => { void (open ? loadThread(open) : loadThreads()) }, [open, loadThread, loadThreads])
  useEffect(() => { end.current?.scrollIntoView?.() }, [msgs])

  const send = async (e: FormEvent) => {
    e.preventDefault()
    if (!open || !text.trim()) return
    const res = await callApp('messages', 'send', { number: open, body: text })
    if (!res.success) return toast(String(res.error || 'Could not send'), true)
    setText('')
    await loadThread(open)
  }

  if (open) {
    return (
      <div className="app-view__body">
        <button type="button" className="back" onClick={() => setOpen(null)}>All messages</button>
        <h3 className="section">{title}</h3>
        <div className="chat" aria-live="polite">
          {msgs.map((m) => <div key={m.id} className={`bubble bubble--${m.mine ? 'mine' : 'theirs'}`}>{m.body}</div>)}
          <div ref={end} />
        </div>
        <form className="form form--inline" onSubmit={send}>
          <input className="input" aria-label="Message" maxLength={280} autoComplete="off" placeholder="Message" value={text} onChange={(e) => setText(e.target.value)} />
          <button className="btn btn--primary" type="submit">Send</button>
        </form>
      </div>
    )
  }

  if (!threads) return <div className="app-view__body"><Empty icon="message" text="Loading" /></div>

  return (
    <div className="app-view__body">
      {threads.length === 0 ? <Empty icon="message" text="No messages yet" /> : (
        <div className="list">
          {threads.map((t) => (
            <button key={t.other} type="button" className="rowbtn" onClick={() => setOpen(t.other)}>
              <Row title={t.name || t.other} sub={`${t.mine ? 'You: ' : ''}${t.body || ''}`}
                actions={t.unread ? <span className="pill">{t.unread}</span> : undefined} />
            </button>
          ))}
        </div>
      )}
      <form className="form form--inline" onSubmit={(e) => { e.preventDefault(); if (newNumber.length === 7) setOpen(newNumber) }}>
        <input className="input input--mono" aria-label="New message to number" inputMode="numeric" maxLength={8} placeholder="New message to 5550001"
          value={newNumber} onChange={(e) => setNewNumber(digits(e.target.value))} />
        <button className="btn btn--primary" type="submit">Start</button>
      </form>
    </div>
  )
}
