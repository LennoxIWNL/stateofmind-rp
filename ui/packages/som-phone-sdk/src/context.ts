import { createContext, useContext } from 'react'

export interface PhoneApi {
  /** A short message at the bottom of the screen. */
  toast: (text: string, isError?: boolean) => void
  /** Back to the home screen. */
  home: () => void
  /** Open another app, optionally with a number to start on. */
  open: (appId: string, arg?: string) => void
  /** Set the unread count shown on an app's tile. */
  badge: (appId: string, count: number) => void
}

export const PhoneContext = createContext<PhoneApi>({
  toast: () => {},
  home: () => {},
  open: () => {},
  badge: () => {},
})

export const usePhone = () => useContext(PhoneContext)
