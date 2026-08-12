/**
 * The loading screen.
 *
 * Feature set follows the reference: a background, music with a volume the
 * player controls, real progress, tabbed content and a way to hide the lot.
 * Written fresh rather than copied, because the reference is a paid escrowed
 * asset licensed to the owner and not to this repo.
 *
 * The one rule shaping everything below: this is the first thing anyone sees
 * of the server, and it is shown to a player who is ALREADY WAITING. So it
 * never blocks on anything, every fetch has a fallback, and nothing here can
 * fail in a way that leaves a blank screen.
 */

import { useEffect, useMemo, useRef, useState } from 'react'
import { FALLBACK, type LoadingConfig, type LoadMessage } from './contract'

type Tab = 'news' | 'events' | 'gallery' | 'keybinds'

const TAB_LABELS: Record<Tab, string> = {
  news: 'News',
  events: 'Events',
  gallery: 'Gallery',
  keybinds: 'Keybinds',
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

function useLoadProgress() {
  const [pct, setPct] = useState(0)

  useEffect(() => {
    function onMessage(e: MessageEvent<LoadMessage>) {
      const data = e.data
      if (!data || data.eventName !== 'loadProgress') return
      if (typeof data.loadFraction !== 'number') return

      const next = Math.max(0, Math.min(1, data.loadFraction)) * 100

      /*
       * HIGH-WATER MARK, not the raw value.
       *
       * loadFraction restarts as the game moves between load phases, so the
       * raw number genuinely does go down. A bar that slides backwards reads
       * as something having gone wrong, and the player cannot tell the
       * difference between that and a crash. Monotonic is a small lie that
       * tells the truth about the thing being asked: is this still going.
       */
      setPct((prev) => (next > prev ? next : prev))
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  return pct
}

// ---------------------------------------------------------------------------
// Audio
// ---------------------------------------------------------------------------

function useMusic(cfg: LoadingConfig) {
  const audio = useRef<HTMLAudioElement | null>(null)
  const [track, setTrack] = useState(0)
  const [playing, setPlaying] = useState(false)

  // Volume persists across joins. Someone who muted this once should not have
  // to mute it every single time they connect.
  const [volume, setVolume] = useState(() => {
    const stored = window.localStorage.getItem('som:loading:volume')
    const parsed = stored == null ? NaN : Number(stored)
    return Number.isFinite(parsed) ? Math.max(0, Math.min(1, parsed)) : cfg.audio.defaultVolume
  })

  useEffect(() => {
    window.localStorage.setItem('som:loading:volume', String(volume))
    if (audio.current) audio.current.volume = volume
  }, [volume])

  const tracks = cfg.audio.tracks
  const current = tracks[track]

  useEffect(() => {
    if (!cfg.audio.enabled || !current) return

    const el = new Audio(current.file)
    el.volume = volume
    el.addEventListener('ended', () => setTrack((t) => (t + 1) % tracks.length))

    /*
     * play() REJECTS when autoplay is blocked, and an unhandled rejection here
     * would surface as a console error on a page nobody has devtools open for.
     * A loading screen without music is fine; one that throws is not.
     */
    el.play().then(
      () => setPlaying(true),
      () => setPlaying(false),
    )

    audio.current = el
    return () => {
      el.pause()
      el.src = ''
      audio.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cfg.audio.enabled, current?.file, tracks.length])

  function toggle() {
    const el = audio.current
    if (!el) return
    if (el.paused) el.play().then(() => setPlaying(true), () => {})
    else {
      el.pause()
      setPlaying(false)
    }
  }

  return {
    track: current,
    playing,
    volume,
    setVolume,
    toggle,
    skip: () => setTrack((t) => (t + 1) % Math.max(1, tracks.length)),
    hasMusic: cfg.audio.enabled && tracks.length > 0,
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

export function App() {
  const [cfg, setCfg] = useState<LoadingConfig>(FALLBACK)
  const [tab, setTab] = useState<Tab>('news')
  const [hidden, setHidden] = useState(false)
  const [lightbox, setLightbox] = useState<string | null>(null)
  const pct = useLoadProgress()
  const music = useMusic(cfg)

  // config.json is fetched RELATIVE, from the resource that served this page.
  // No Lua involved, so it survives the client not existing yet.
  useEffect(() => {
    let live = true
    fetch('../config.json')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((json) => {
        if (!live) return
        // Merged over the fallback rather than replacing it, so a config that
        // omits a key renders that section empty instead of crashing on it.
        setCfg({ ...FALLBACK, ...json, server: { ...FALLBACK.server, ...json.server } })
      })
      .catch(() => {})
    return () => {
      live = false
    }
  }, [])

  const tabs = useMemo(
    () => (Object.keys(TAB_LABELS) as Tab[]).filter((t) => cfg.tabs[t] !== false),
    [cfg.tabs],
  )

  // If the config turns off whichever tab is selected, fall to the first one
  // still enabled rather than rendering an empty panel with no active tab.
  useEffect(() => {
    const first = tabs[0]
    if (first && !tabs.includes(tab)) setTab(first)
  }, [tabs, tab])

  return (
    <div className={`load ${hidden ? 'is-hidden' : ''}`}>
      <Background cfg={cfg} />

      <div className="load__scrim" />

      <div className="load__ui">
        <header className="load__head">
          <div className="load__brand">
            <span className="load__mark" aria-hidden="true" />
            <div>
              <h1 className="load__name">{cfg.server.name}</h1>
              {cfg.server.tagline && <p className="load__tagline">{cfg.server.tagline}</p>}
            </div>
          </div>

          <nav className="load__links">
            {cfg.links.map((l) => (
              <a key={l.url} className="load__link" href={l.url} target="_blank" rel="noreferrer">
                {l.label}
              </a>
            ))}
            <button type="button" className="load__link" onClick={() => setHidden(true)}>
              Hide UI
            </button>
          </nav>
        </header>

        <main className="load__body">
          <div className="load__tabs">
            {tabs.map((t) => (
              <button
                key={t}
                type="button"
                className={`load__tab ${tab === t ? 'is-active' : ''}`}
                onClick={() => setTab(t)}
              >
                {TAB_LABELS[t]}
              </button>
            ))}
          </div>

          <div className="load__panel">
            <Panel tab={tab} cfg={cfg} onImage={setLightbox} />
          </div>
        </main>

        <footer className="load__foot">
          {music.hasMusic && (
            <div className="load__music">
              <button type="button" className="load__icon" onClick={music.toggle}
                title={music.playing ? 'Pause' : 'Play'}>
                {music.playing ? '❚❚' : '▶'}
              </button>
              <button type="button" className="load__icon" onClick={music.skip} title="Next track">
                ▶▶
              </button>

              <div className="load__track">
                <span className="load__track-title">{music.track?.title ?? ''}</span>
                {music.track?.artist && <span className="load__track-artist">{music.track.artist}</span>}
              </div>

              <input
                className="load__volume"
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={music.volume}
                onChange={(e) => music.setVolume(Number(e.target.value))}
                title={`Volume ${Math.round(music.volume * 100)}%`}
              />
            </div>
          )}

          <div className="load__progress">
            <div className="load__progress-head">
              <span>Loading</span>
              <span className="load__pct">{Math.round(pct)}%</span>
            </div>
            <div className="load__bar">
              <span className="load__bar-fill" style={{ width: `${pct}%` }} />
            </div>
          </div>
        </footer>
      </div>

      {hidden && (
        <button type="button" className="load__show" onClick={() => setHidden(false)}>
          Show UI
        </button>
      )}

      {lightbox && (
        <div className="load__lightbox" onClick={() => setLightbox(null)} role="presentation">
          <img src={lightbox} alt="" />
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

function Background({ cfg }: { cfg: LoadingConfig }) {
  const { type, file } = cfg.background

  if (type === 'video' && file) {
    return (
      <video
        className="load__bg"
        src={file}
        autoPlay
        loop
        muted
        playsInline
        // A video that fails to load leaves the element transparent, which is
        // why the gradient lives on the container underneath rather than here.
      />
    )
  }

  if (type === 'image' && file) {
    return <div className="load__bg" style={{ backgroundImage: `url(${file})` }} />
  }

  return null
}

// ---------------------------------------------------------------------------
// Panels
// ---------------------------------------------------------------------------

function Panel({
  tab,
  cfg,
  onImage,
}: {
  tab: Tab
  cfg: LoadingConfig
  onImage: (src: string) => void
}) {
  if (tab === 'keybinds') {
    if (!cfg.keybinds.length) return <Empty>No keybinds listed yet.</Empty>
    return (
      <div className="load__keys">
        {cfg.keybinds.map((k) => (
          <div key={`${k.key}-${k.action}`} className="load__key">
            <kbd>{k.key}</kbd>
            <span>{k.action}</span>
          </div>
        ))}
      </div>
    )
  }

  if (tab === 'gallery') {
    if (!cfg.gallery.length) return <Empty>Nothing in the gallery yet.</Empty>
    return (
      <div className="load__gallery">
        {cfg.gallery.map((src) => (
          <button key={src} type="button" className="load__shot" onClick={() => onImage(src)}>
            <img src={src} alt="" loading="lazy" />
          </button>
        ))}
      </div>
    )
  }

  const entries = tab === 'news' ? cfg.news : cfg.events
  if (!entries.length) return <Empty>Nothing posted yet.</Empty>

  return (
    <div className="load__entries">
      {entries.map((e) => (
        <article key={e.title} className="load__entry">
          {e.image && (
            <button type="button" className="load__entry-shot" onClick={() => onImage(e.image!)}>
              <img src={e.image} alt="" loading="lazy" />
            </button>
          )}
          <div className="load__entry-text">
            <div className="load__entry-head">
              <h2>{e.title}</h2>
              {e.date && <time>{e.date}</time>}
            </div>
            <p>{e.description}</p>
          </div>
        </article>
      ))}
    </div>
  )
}

function Empty({ children }: { children: React.ReactNode }) {
  return <div className="load__empty">{children}</div>
}
