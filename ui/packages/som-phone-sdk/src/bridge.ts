/**
 * The one door to the server. Every app action is (app, action, payload) and
 * the server decides whether it may, so there is no per-app callback here.
 */

const RESOURCE =
  typeof window !== 'undefined' && window.location.hostname.startsWith('cfx-nui-')
    ? window.location.hostname.replace('cfx-nui-', '')
    : 'som-phone'

export interface ActionResult {
  success: boolean
  error?: string
  locked?: boolean
  [key: string]: unknown
}

/** Never throws: a screen gets a failed result and decides what to show. */
export async function callApp<T extends object = ActionResult>(
  app: string,
  action: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  try {
    const response = await fetch(`https://${RESOURCE}/action`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({ app, action, payload }),
    })

    const text = await response.text()
    if (!text) return { success: false, error: 'No answer' } as unknown as T

    return JSON.parse(text) as T
  } catch {
    return { success: false, error: 'Connection failed' } as unknown as T
  }
}

/** Tells the game the player closed the phone, so it can drop focus and the prop. */
export function closePhone(): void {
  void fetch(`https://${RESOURCE}/close`, { method: 'POST', body: '{}' }).catch(() => {})
}

/** Buying a property is done by som-housing, which re-reads everything. */
export async function callHousing(body: Record<string, unknown>): Promise<ActionResult> {
  try {
    const response = await fetch(`https://${RESOURCE}/buyProperty`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body),
    })
    return JSON.parse(await response.text()) as ActionResult
  } catch {
    return { success: false, error: 'Connection failed' }
  }
}
