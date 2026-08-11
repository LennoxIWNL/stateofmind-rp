import { useEffect, useRef, useState } from 'react'

/**
 * The NUI bridge.
 *
 * Two directions, and they are not symmetrical:
 *
 *   Lua to page     SendNUIMessage({ action, ... })  arrives as a window
 *                   'message' event. Listened to with useNuiEvent.
 *   Page to Lua     fetch to https://<resource>/<callback>, answered by
 *                   RegisterNUICallback. Called with fetchNui.
 *
 * Nothing here decides anything. Every SOM NUI is a renderer: the Lua side
 * owns the state and the server owns the truth, so a page that is edited buys
 * a nicer looking screen and no additional permissions.
 */

/**
 * The resource this page is served from.
 *
 * Derived from the hostname rather than hardcoded, so one app can be pointed
 * at a different resource without a code change. Falls back to a sentinel in a
 * browser, where the hostname is localhost and there is no NUI to answer.
 */
export const RESOURCE_NAME: string =
  typeof window !== 'undefined' && window.location.hostname.startsWith('cfx-nui-')
    ? window.location.hostname.replace('cfx-nui-', '')
    : 'som-dev'

export const IS_BROWSER: boolean = RESOURCE_NAME === 'som-dev'

export interface NuiMessage<T = unknown> {
  action: string
  data?: T
}

/**
 * Calls a RegisterNUICallback on the Lua side.
 *
 * NEVER throws. A NUI callback that rejects leaves the calling component in
 * whatever half-updated state it was in, and in a browser there is no callback
 * at all, so a rejection would make every screen unusable in dev. Callers get
 * the fallback instead and can decide what that means.
 */
export async function fetchNui<T = unknown>(
  callback: string,
  data: unknown = {},
  fallback?: T,
): Promise<T> {
  if (IS_BROWSER) return fallback as T

  try {
    const response = await fetch(`https://${RESOURCE_NAME}/${callback}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    })

    if (!response.ok) return fallback as T

    // A callback that answers cb(1) sends a bare number, and a callback that
    // answers nothing sends an empty body. Both are valid and neither is JSON.
    const text = await response.text()
    if (!text) return fallback as T

    try {
      return JSON.parse(text) as T
    } catch {
      return fallback as T
    }
  } catch {
    return fallback as T
  }
}

/**
 * Subscribes to one SendNUIMessage action.
 *
 * The handler is held in a ref so the listener is attached once for the life of
 * the component. Without that, every render that produced a new inline handler
 * would tear the listener down and build another, and a message arriving in
 * that gap would be dropped.
 */
export function useNuiEvent<T = unknown>(
  action: string,
  handler: (data: T) => void,
): void {
  const saved = useRef(handler)
  saved.current = handler

  useEffect(() => {
    const listener = (event: MessageEvent<NuiMessage<T>>) => {
      const message = event.data
      if (!message || typeof message.action !== 'string') return
      if (message.action !== action) return

      // Some senders put the payload in `data`, others spread it onto the
      // message itself. Both shapes exist in this codebase already, so both
      // are accepted rather than forcing a sweep of the Lua.
      saved.current((message.data !== undefined ? message.data : message) as T)
    }

    window.addEventListener('message', listener)
    return () => window.removeEventListener('message', listener)
  }, [action])
}

export interface VisibilityOptions {
  /** Action that shows the page. Defaults to 'open'. */
  showAction?: string
  /** Action that hides it. Defaults to 'close'. */
  hideAction?: string
  /** NUI callback told when the page closes itself. Defaults to 'close'. */
  closeCallback?: string
  /** Whether Escape closes. Some screens must not be dismissable. */
  escapeCloses?: boolean
}

/**
 * Show/hide plus the Escape key, which every full screen NUI needs and every
 * one of them otherwise reimplements slightly differently.
 *
 * Escape tells LUA and lets Lua decide. It does not hide the page locally:
 * focus is owned by the Lua side, and a page that hid itself while Lua still
 * held the cursor would leave the player unable to move with nothing on screen
 * to click.
 */
export function useNuiVisibility(options: VisibilityOptions = {}) {
  const {
    showAction = 'open',
    hideAction = 'close',
    closeCallback = 'close',
    escapeCloses = true,
  } = options

  const [visible, setVisible] = useState(false)

  useNuiEvent(showAction, () => setVisible(true))
  useNuiEvent(hideAction, () => setVisible(false))

  useEffect(() => {
    if (!visible || !escapeCloses) return

    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      void fetchNui(closeCallback)
    }

    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [visible, escapeCloses, closeCallback])

  return { visible, setVisible }
}

/**
 * Fakes an inbound SendNUIMessage so a screen can be developed in a browser.
 *
 * Guarded on IS_BROWSER, so leaving a call to this in shipped code is inert in
 * game rather than a way to inject state into a live UI.
 */
export function debugData<T>(messages: NuiMessage<T>[], delay = 0): void {
  if (!IS_BROWSER) return

  for (const message of messages) {
    setTimeout(() => {
      window.dispatchEvent(new MessageEvent('message', { data: message }))
    }, delay)
  }
}
