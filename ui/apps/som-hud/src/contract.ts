/**
 * som-hud's payload contract.
 *
 * Unlike ox_inventory's, BOTH SIDES OF THIS ARE OURS, so there is nobody else
 * to break it. That is not a reason to leave it undocumented: the Lua sends
 * flat payloads compared field by field for change suppression, and a nested
 * value added here would be compared by identity and so would send on every
 * tick forever. Keep every payload flat.
 *
 * Lua: [som]/som-hud/client/main.lua, seatbelt.lua, editor.lua
 */

// ---------------------------------------------------------------------------
// Inbound. Lua -> page.
// ---------------------------------------------------------------------------

export type Status = {
  health: number
  armour: number
  hunger: number
  thirst: number
  /** Counts UP from zero, unlike the others. */
  stress: number
  /** Only meaningful underwater; 100 elsewhere. */
  oxygen: number
  underwater: boolean
}

export type Vehicle = {
  inVehicle: boolean
  class?: number
  air?: boolean
  bike?: boolean
  speed?: number
  unit?: string
  gear?: number
  /** 0-100, from GetVehicleCurrentRpm. */
  rpm?: number
  engine?: number
  warn?: boolean
  seatbelt?: boolean
  /** null until a fuel resource exists. The gauge renders inert, never pinned. */
  fuel?: number | null
  electric?: boolean
  /** Air only. */
  pitch?: number
  roll?: number
  altitude?: number
}

export type World = {
  heading: number
  street: string
  /** Empty mid-block; only set at a junction. */
  crossing: string
  zone: string
}

export type Player = {
  cash: number
  bank: number
  job: string
  jobGrade: string
  gang: string
  onduty: boolean
  hour: number
  minute: number
  players: number
  voiceMode: string
  talking: boolean
  radio: number | false
}

export const INBOUND = {
  visible: 'hud:visible',
  status: 'hud:status',
  vehicle: 'hud:vehicle',
  world: 'hud:world',
  heading: 'hud:heading',
  voice: 'hud:voice',
  player: 'hud:player',
  seatbelt: 'hud:seatbelt',
  layout: 'hud:layout',
  edit: 'hud:edit',
} as const

// ---------------------------------------------------------------------------
// Outbound. page -> Lua. LAYOUT ONLY, never a value.
// ---------------------------------------------------------------------------

export const OUTBOUND = {
  saveLayout: 'hudSaveLayout',
  resetLayout: 'hudResetLayout',
  closeEditor: 'hudCloseEditor',
  exportLayout: 'hudExportLayout',
  importLayout: 'hudImportLayout',
} as const

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/** Every movable panel. The id is the persistence key, so renaming one orphans a saved layout. */
/*
 * Money, job and gang are NOT here and are not coming back.
 *
 * Owner's call and it is stronger than a default: cash and bank permanently on
 * screen turn money into a scoreboard, and the job and gang chips restate
 * something the player already knows. Leaving them as a toggle would just be
 * the same clutter one click away, so the panels are gone.
 *
 * Voice is not a panel either. It belongs in the condition row as an icon,
 * beside the other things about the player's body, rather than as a separate
 * chip repeating what pma-voice already draws.
 */
export const PANELS = [
  'status',
  'speedo',
  'aviation',
  'compass',
  'location',
  'session',
] as const

export type PanelId = (typeof PANELS)[number]

export type PanelState = {
  /** Percent of viewport, so a layout survives a resolution change. */
  x: number
  y: number
  scale: number
  on: boolean
}

export type Layout = Record<PanelId, PanelState> & {
  speedoStyle: 'digital' | 'ring' | 'analog'
  compassStyle: 'primary' | 'minimal'
}

/**
 * Percent-based, deliberately. Storing pixels means a layout built on an
 * ultrawide puts half the HUD off screen on a laptop, and the export/import
 * feature makes moving between machines a normal thing to do.
 */
export const DEFAULT_LAYOUT: Layout = {
  /* BOTTOM LEFT, not bottom centre. The inventory hotbar owns the centre and
   * the two were sitting on top of each other. */
  status:    { x: 14, y: 94, scale: 1, on: true },
  speedo:    { x: 88, y: 86, scale: 1, on: true },
  aviation:  { x: 12, y: 12, scale: 1, on: true },
  compass:   { x: 50, y: 3,  scale: 1, on: true },
  location:  { x: 3,  y: 82, scale: 1, on: true },
  session:   { x: 95, y: 4,  scale: 1, on: true },
  speedoStyle: 'digital',
  compassStyle: 'primary',
}

export const PANEL_LABELS: Record<PanelId, string> = {
  status: 'Condition',
  speedo: 'Speedometer',
  aviation: 'Aviation',
  compass: 'Compass',
  location: 'Location',
  session: 'Players & time',
}

/**
 * Voice, on its own channel and in its own state.
 *
 * Deliberately NOT part of Player. It updates at 150ms while Player updates at
 * 2000ms, and merging the two meant a voice message arriving before the first
 * player payload was thrown away.
 */
export type VoiceState = {
  voiceMode: string
  talking: boolean
  radio: number | false
}
