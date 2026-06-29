export interface Coords {
  x: number;
  y: number;
  z: number;
}

export interface DoorData {
  auto: boolean;
  autolock: number;
  coords: Coords;
  heading: number;
  model: number;
  doors: DoorEntry[] | null;
  characters: string[];
  groups: Record<string, number>;
  items: string[];
  lockpick: boolean;
  hideUi: boolean;
  holdOpen: boolean;
  lockSound: string;
  unlockSound: string;
  maxDistance: number;
  doorRate: number;
  state: number;
  passcode: string | null;
  lockpickDifficulty: string[] | null;
}

export interface DoorEntry {
  coords: Coords;
  heading: number;
  model: number;
}

export interface DoorListItem {
  id: number;
  name: string;
  model: number;
  coords: Coords;
  heading: number;
  state: number;
  groups: Record<string, number>;
  isDoor: boolean;
  category: string;
}

export interface DoorFull {
  id: number;
  name: string;
  data: DoorData;
}

export interface Building {
  id: number;
  name: string;
  description: string;
  doors: number[];
  permissions: Record<string, unknown>;
  metadata: Record<string, unknown>;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface Template {
  id: number;
  name: string;
  description: string;
  type: 'single' | 'building';
  data?: DoorData;
  author: string;
  version: string;
  export_code: string;
  created_at: string;
}

export interface Backup {
  id: number;
  name: string;
  type: 'auto' | 'manual';
  door_count: number;
  building_count: number;
  created_by: string;
  created_at: string;
}

export interface LogEntry {
  id: number;
  action: string;
  door_id: number | null;
  building_id: number | null;
  player_name: string;
  player_identifier: string;
  details: string;
  created_at: string;
}

export interface JobInfo {
  name: string;
  label: string;
  grades: { grade: number; name: string }[];
}

export interface InitData {
  doors: DoorListItem[];
  buildings: Building[];
  jobs: JobInfo[];
  gangs: JobInfo[];
  theme: string;
  framework: string;
}

export interface DetectedDoor {
  model: number;
  modelName: string;
  category: string;
  coords: Coords;
  heading: number;
  distance?: number;
  selected?: boolean;
  entity?: number;
}

export interface BulkUpdateData {
  entities: DetectedDoor[];
  radius: number;
  count: number;
}

export interface ApiResponse {
  ok: boolean;
  message?: string;
  id?: number;
  success?: number;
  failed?: number;
}

export type NotificationType = 'success' | 'error' | 'info' | 'warning';

export interface Notification {
  id: string;
  type: NotificationType;
  message: string;
}

export type Page =
  | 'dashboard'
  | 'creator'
  | 'bulk'
  | 'buildings'
  | 'templates'
  | 'import'
  | 'backups'
  | 'logs'
  | 'settings';
