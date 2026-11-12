export interface AppTile {
  id: string
  label: string
  icon: string
  colour: string
  order: number
}

export interface Theme {
  label: string
  accent: string
  perk?: string
}

export interface OpenData {
  apps: AppTile[]
  settings: { theme: string; wallpaper: string }
  themes: Record<string, Theme>
  owner: string
  number: string
  hasPasscode: boolean
  badges: Record<string, number>
}

export interface Banner {
  id: number
  title: string
  text: string
  icon: string
}
