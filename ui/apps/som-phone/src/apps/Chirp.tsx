import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { type ActionResult, Empty, Icon, Section, callApp, usePhone } from '@som/phone-sdk'

interface Post {
  id: number
  handle: string
  colour?: string | null
  business?: string | null
  body: string
  image?: string | null
  likes: number
  replies: number
  reply_to?: number | null
  mine: boolean
  liked: boolean
}
interface Me { handle: string; colour?: string | null; business?: string | null }

function Compose({ me, replyTo, onDone }: { me: Me; replyTo?: number; onDone: () => void }) {
  const { toast } = usePhone()
  const [body, setBody] = useState('')
  const [asBusiness, setAsBusiness] = useState(false)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!body.trim()) return
    const res = await callApp('chirp', 'post', { body, replyTo, asBusiness })
    if (!res.success) return toast(String(res.error || 'Could not post'), true)
    setBody('')
    onDone()
  }

  return (
    <form className="form" onSubmit={submit}>
      <textarea className="input input--area" aria-label={replyTo ? 'Reply' : 'New post'} maxLength={280} rows={2}
        placeholder={replyTo ? 'Reply' : `What is happening, @${me.handle}?`} value={body} onChange={(e) => setBody(e.target.value)} />
      <div className="form--inline">
        {me.business && (
          <label className="check">
            <input type="checkbox" checked={asBusiness} onChange={(e) => setAsBusiness(e.target.checked)} /> As {me.business}
          </label>
        )}
        <span className="muted">{280 - body.length}</span>
        <button className="btn btn--primary" type="submit">{replyTo ? 'Reply' : 'Post'}</button>
      </div>
    </form>
  )
}

function Card({ post, onLike, onOpen, onRemove, onReport }: {
  post: Post
  onLike: () => void
  onOpen?: () => void
  onRemove: () => void
  onReport: () => void
}) {
  return (
    <article className="post">
      <header className="post__head">
        <strong style={post.colour ? { color: post.colour } : undefined}>@{post.handle}</strong>
        {post.business && <span className="pill">{post.business}</span>}
      </header>
      <p className="post__body">{post.body}</p>
      {post.image && <img className="post__image" src={post.image} alt="" loading="lazy" referrerPolicy="no-referrer" />}
      <footer className="post__foot">
        <button type="button" className={`link${post.liked ? ' is-on' : ''}`} onClick={onLike} aria-pressed={post.liked}>
          <Icon name="heart" /> {post.likes}
        </button>
        {onOpen && <button type="button" className="link" onClick={onOpen}><Icon name="message" /> {post.replies}</button>}
        {post.mine
          ? <button type="button" className="link" onClick={onRemove}>Delete</button>
          : <button type="button" className="link" onClick={onReport}>Report</button>}
      </footer>
    </article>
  )
}

export function Chirp() {
  const { toast } = usePhone()
  const [posts, setPosts] = useState<Post[] | null>(null)
  const [me, setMe] = useState<Me | null>(null)
  const [open, setOpen] = useState<number | null>(null)
  const [handle, setHandle] = useState('')
  const [editing, setEditing] = useState(false)

  const load = useCallback(async () => {
    const res = open
      ? await callApp<ActionResult & { posts?: Post[] }>('chirp', 'thread', { id: open })
      : await callApp<ActionResult & { posts?: Post[]; me?: Me }>('chirp', 'feed')
    if (open && !res.success) { setOpen(null); return }
    setPosts(res.posts || [])
    if (res.me) setMe(res.me as Me)
  }, [open])

  useEffect(() => { void load() }, [load])

  const act = async (action: string, payload: Record<string, unknown>, done?: string) => {
    const res = await callApp('chirp', action, payload)
    if (!res.success && res.success !== undefined) return toast(String(res.error || 'Not allowed'), true)
    if (done) toast(done)
    await load()
  }

  const rename = async (e: FormEvent) => {
    e.preventDefault()
    const res = await callApp('chirp', 'setHandle', { handle })
    if (!res.success) return toast(String(res.error || 'Could not change'), true)
    setEditing(false)
    setHandle('')
    await load()
  }

  if (!posts || !me) return <div className="app-view__body"><Empty icon="twitter" text="Loading" /></div>

  const root = open ? posts.find((p) => p.id === open) : null
  const cards = (list: Post[], link: boolean) => list.map((p) => (
    <Card key={p.id} post={p}
      onLike={() => void act('like', { id: p.id })}
      onOpen={link ? () => setOpen(p.id) : undefined}
      onRemove={() => void act('remove', { id: p.id }, 'Deleted')}
      onReport={() => void act('report', { id: p.id, reason: 'reported from the phone' }, 'Reported')} />
  ))

  if (open) {
    return (
      <div className="app-view__body">
        <button type="button" className="back" onClick={() => setOpen(null)}>Feed</button>
        {root && cards([root], false)}
        <Section>Replies</Section>
        {cards(posts.filter((p) => p.id !== open), false)}
        <Compose me={me} replyTo={open} onDone={() => void load()} />
      </div>
    )
  }

  return (
    <div className="app-view__body">
      <div className="profile">
        <strong style={me.colour ? { color: me.colour } : undefined}>@{me.handle}</strong>
        <button type="button" className="link" onClick={() => setEditing(!editing)}>{editing ? 'Cancel' : 'Change handle'}</button>
      </div>
      {editing && (
        <form className="form form--inline" onSubmit={rename}>
          <input className="input" aria-label="New handle" maxLength={16} placeholder="new_handle" value={handle} onChange={(e) => setHandle(e.target.value)} />
          <button className="btn btn--primary" type="submit">Save</button>
        </form>
      )}
      <Compose me={me} onDone={() => void load()} />
      {posts.length === 0 ? <Empty icon="twitter" text="Nothing posted yet" /> : <div className="posts">{cards(posts, true)}</div>}
    </div>
  )
}
