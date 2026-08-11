/** Shapes the Lua side sends. Mirrors som-police's server responses exactly. */

export interface StockEntry {
  item: string
  label: string
  count: number
  price: number
  /** Certification gate. The server has already filtered on it; this is display only. */
  cert?: string
}

export interface PaymentOption {
  account: string
  label: string
  balance: number
}

export interface ArmouryData {
  label: string
  issue: StockEntry[]
  personal: StockEntry[]
  payment: PaymentOption[]
  /** Restored from the Lua side, so a cart survives closing the panel. */
  cart?: CartLine[]
}

export interface CartLine {
  item: string
  count: number
}

export interface Certification {
  label: string
  description?: string
  held: boolean
}

export interface CertsData {
  name?: string
  badge?: string
  certifications: Certification[]
}

/** What checkout returns. Per line, because each line is validated on its own. */
export interface CheckoutResult {
  success: boolean
  error?: string
  drawn: number
  failed: number
  spent: number
  /** Lines that could not be filled, so the cart keeps exactly those. */
  remaining?: CartLine[]
}
