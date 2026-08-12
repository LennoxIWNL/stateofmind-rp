/**
 * The loadscreen contract.
 *
 * A loadscreen is NOT an ordinary NUI page and the differences matter:
 *
 * 1. There is no fetchNui. The page cannot call back into Lua, because during
 *    the loadscreen there is no client to answer. Everything here is one way:
 *    the game posts progress in, and the page only ever renders it.
 *
 * 2. It is dismissed by the CLIENT, not by the page. client.lua waits for
 *    NetworkIsSessionStarted and calls ShutdownLoadingScreen plus
 *    ShutdownLoadingScreenNui. loadscreen_manual_shutdown 'yes' in the manifest
 *    is what hands that responsibility over; without it the game tears the page
 *    down on its own schedule and the outro never plays.
 *
 * 3. Content is fetched from the resource over HTTP rather than pushed. The
 *    page can read its own resource's files through a relative fetch, which is
 *    how config.json arrives without any Lua involvement.
 *
 * THE PROGRESS EVENT
 *
 * The game posts window messages during load. loadProgress is the only one
 * worth rendering: loadFraction runs 0 to 1. The others (startInitFunction,
 * onLogLine, onDataFileEntry and friends) fire in bursts of hundreds and are
 * useful for a developer log, not for a player who wants to know how long is
 * left, so they are deliberately not listened for.
 *
 * loadFraction is NOT MONOTONIC. It restarts as the game moves between load
 * phases, which is why the bar clamps to its own high-water mark: a progress
 * bar that goes backwards reads as a crash.
 */

export type LoadMessage = {
  eventName?: string
  loadFraction?: number
}

export type NewsEntry = {
  title: string
  description: string
  image?: string
  date?: string
}

export type Keybind = {
  key: string
  action: string
}

export type Track = {
  title: string
  artist?: string
  file: string
}

export type LoadingConfig = {
  server: {
    name: string
    tagline?: string
  }
  background: {
    type: 'image' | 'video' | 'gradient'
    file?: string
  }
  audio: {
    enabled: boolean
    defaultVolume: number
    tracks: Track[]
  }
  links: Array<{ label: string; url: string }>
  tabs: {
    news?: boolean
    events?: boolean
    gallery?: boolean
    keybinds?: boolean
  }
  news: NewsEntry[]
  events: NewsEntry[]
  gallery: string[]
  keybinds: Keybind[]
}

/**
 * The fallback.
 *
 * A loading screen that renders nothing because a fetch failed is worse than
 * one with placeholder copy, because the failure happens before the player has
 * any way to report it. Every field the page reads has a value here.
 */
export const FALLBACK: LoadingConfig = {
  server: { name: 'State of Mind', tagline: 'Los Santos, seriously' },
  background: { type: 'gradient' },
  audio: { enabled: false, defaultVolume: 0.15, tracks: [] },
  links: [],
  tabs: { news: true, events: true, gallery: true, keybinds: true },
  news: [],
  events: [],
  gallery: [],
  keybinds: [],
}
