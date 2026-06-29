# Lennox Door Creator v1.0.0

> Premium door creation & management tool for ox_doorlock — Created by **Lennox**

---

## Features

- **Single Door Creation** — Walk up to any door, aim at it, and register it with full configuration
- **Bulk Door Registration** — Select all doors in a radius with visual marker, register them all at once
- **Building System** — Group doors by building, apply shared permissions across all doors
- **Template System** — Save door configs as templates, export/import shareable codes
- **Import Wizard** — Migrate from qb-doorlock, nui_doorlock, or custom JSON
- **Automatic Backups** — Scheduled snapshots with restore capability
- **Advanced Logging** — Full audit trail with Discord webhook support
- **Modern NUI** — Dark glass-themed React UI with customizable accent color
- **Framework Support** — QBCore, ESX, and Standalone (ACE perms)
- **Fence & Gate Support** — Detects doors, gates, fences, shutters, barriers, and cell doors

---

## Requirements

| Resource | Version | Required |
|----------|---------|----------|
| `oxmysql` | 2.7+ | Yes |
| `ox_lib` | 3.0+ | Yes |
| `ox_doorlock` | 1.10+ | Yes |
| `qb-core` OR `es_extended` | Any | Optional (Standalone works with ACE) |

---

## Installation

1. **Download** and extract `Lennox-DoorCreator` into your resources folder
2. **Add** to `server.cfg`:
   ```
   ensure Lennox-DoorCreator
   ```
   Make sure it starts **after** `oxmysql`, `ox_lib`, and `ox_doorlock`.

3. **Run SQL** — Execute `sql/lennox_doorcreator.sql` in your database to create the required tables.

4. **Configure** — Edit `config.lua` to set your preferences. The default configuration works out of the box with ox_doorlock.

5. **Discord Logging** (optional) — Copy `secrets.lua.example` to `secrets.lua` and add your webhook URL. Set `Config.LogToDiscord = true`.

6. **Restart** your server.

---

## Configuration

### General
| Option | Default | Description |
|--------|---------|-------------|
| `Config.Debug` | `false` | Enable debug prints |
| `Config.Command` | `'doorcreator'` | Chat command to open UI |
| `Config.CommandAliases` | `{'dc', 'doors'}` | Additional command aliases |
| `Config.Keybind` | `'F7'` | Keybind to open UI (`false` to disable) |
| `Config.AdminOnly` | `true` | Restrict to admins only |

### Framework
| Option | Default | Description |
|--------|---------|-------------|
| `Config.Framework` | `'auto'` | `'auto'`, `'qb'`, `'esx'`, or `'standalone'` |

### Permissions
| Option | Default | Description |
|--------|---------|-------------|
| `Config.AdminAces` | `{'qbcore.god', 'command', 'group.admin'}` | ACE permissions for admin access |
| `Config.AdminIdentifiers` | `{}` | License/Steam/Discord identifiers for admin access |

### UI Theme
| Option | Default | Description |
|--------|---------|-------------|
| `Config.ThemeColor` | `'#6366f1'` | Primary accent color (hex) |
| `Config.UIScale` | `1.0` | UI scale multiplier |

### Creator Settings
| Option | Default | Description |
|--------|---------|-------------|
| `Config.RaycastDistance` | `10.0` | Door selector ray reach |
| `Config.DefaultLockState` | `1` | Default lock state (0=unlocked, 1=locked) |
| `Config.DefaultMaxDistance` | `2.0` | Default interaction distance |
| `Config.DefaultDoorRate` | `1.0` | Default door animation speed |

### Bulk Selection
| Option | Default | Description |
|--------|---------|-------------|
| `Config.BulkDefaultRadius` | `10.0` | Default scan radius |
| `Config.BulkMaxRadius` | `50.0` | Maximum radius |
| `Config.MaxBulkDoors` | `100` | Max doors per bulk operation |

### Backups
| Option | Default | Description |
|--------|---------|-------------|
| `Config.AutoBackup` | `true` | Enable auto-backups |
| `Config.BackupInterval` | `21600000` | Backup interval in ms (6 hours) |
| `Config.MaxBackups` | `10` | Max stored backups |

### Logging
| Option | Default | Description |
|--------|---------|-------------|
| `Config.LogToDiscord` | `false` | Send logs to Discord webhook |
| `Config.LogRetention` | `30` | Days to keep logs |

---

## Commands

| Command | Description |
|---------|-------------|
| `/doorcreator` | Open the door creator UI |
| `/dc` | Alias for `/doorcreator` |
| `/dc backup` | Create a manual backup |
| `/dc restore [id]` | Restore a backup by ID |
| `/dc stats` | Show door/building/template counts |
| `/dc delete [doorId]` | Quick-delete a door by ID |
| `/dc tp [doorId]` | Teleport to a door location |

All commands require admin permissions.

---

## Template Sharing

1. Open the **Templates** page in the UI
2. Click the copy icon on any template to get the export code
3. Share the code with others (via Discord, forums, etc.)
4. To import: click **Import Template**, paste the code, and confirm

Templates contain door configuration data (permissions, settings) but not coordinates — they're portable between servers.

---

## Import Guide

### From ox_doorlock
Select "ox_doorlock" in the import wizard. All existing doors from your database will be loaded for management.

### From qb-doorlock
1. Open the import wizard and select "qb-doorlock"
2. Copy the contents of your `qb-doorlock/configs/*.lua` file(s)
3. Paste into the text area and click "Preview Import"
4. Review the detected doors, fix any warnings
5. Click "Import" to insert them into ox_doorlock

### From Custom JSON
Provide a JSON array of door objects. The importer will map common field names automatically.

---

## Backup & Restore

- **Auto-backups** run on resource start and every 6 hours (configurable)
- **Manual backups** can be created from the UI or via `/dc backup`
- **Restore** replaces ALL current door data — a pre-restore auto-backup is created first
- Backups include both ox_doorlock doors and Lennox buildings
- Old backups are automatically cleaned up when the limit is reached

---

## FAQ

**Q: Doors aren't working after creation?**
A: New doors are synced via `ox_doorlock:editDoor`. If this doesn't work for new entries in your ox_doorlock version, restart the `ox_doorlock` resource.

**Q: The UI doesn't open?**
A: Make sure you have admin permissions configured in `config.lua`. Check the F8 console for errors.

**Q: Can I use this without a framework?**
A: Yes — set `Config.Framework = 'standalone'` and use ACE permissions for admin access.

**Q: How do I change the theme color?**
A: Set `Config.ThemeColor` in `config.lua`, or change it live from the Settings page in the UI.

---

## Credits

Created by **Lennox**

---

*Lennox Door Creator v1.0.0 — Premium FiveM Resource*
