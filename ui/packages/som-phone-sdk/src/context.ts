import { createContext, useContext } from 'react'

export interface PhoneApi {
  /** A short message at the bottom of the screen. */
  toast: (text: string, isError?: boolean) => void
  /** Back to the home screen. */
  home: () => void
  /** Set the unread count shown on an app's tile. */
  badge: (appId: string, count: number) => void
}

export const PhoneContext = createContext<PhoneApi>({
  toast: () => {},
  home: () => {},
  badge: () => {},
})

export const usePhone = () => useContext(PhoneContext)
