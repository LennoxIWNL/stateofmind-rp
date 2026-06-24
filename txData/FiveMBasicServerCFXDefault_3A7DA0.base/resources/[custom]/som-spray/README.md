# som-spray — Graffiti Spray System

Renamed from `rcore_spray`. Players can spray custom text on walls using spray cans.

## How It Works

### Items Required
| Item | Purpose |
|------|---------|
| `spray` | Consumable — used to place a spray (1 consumed per spray) |
| `spray_remover` | Useable item — removes the closest spray within range |

Both items need to be in `qb-core/shared/items.lua` and their images in the inventory HTML.

### Player Flow
1. Player types `/spray <word>` (max 9 characters)
2. If they have a `spray` item, a WarMenu opens with options:
   - **Font** — 8 graffiti fonts (Next Custom, Dripping Marker, Docallisme, Fat Wandals, Sister Spray, Pricedown, Chalet, Sign Painter)
   - **Color** — 21 colors (white, red, pink, blue, yellow, green, orange, brown, purple, grey, black — most have 2 shades)
   - **Size** — scalable from 60% to 200%
3. Player aims at a flat wall — a live preview shows the spray in position
4. Confirming triggers a 20-second progress bar with spray-can animation + particle effects
5. Spray persists in the database and is visible to all players within 100m

### Spray Removal
- Use `spray_remover` item → triggers a 30-second removal progress bar
- Removes the closest spray at the player's position

### Persistence
- Sprays stored in MySQL table `sprays` (position, rotation, scale, text, font, color, interior flag)
- Auto-cleanup: sprays older than **2 days** (`SPRAY_PERSIST_DAYS`) are deleted on server start
- All sprays are synced to all connected clients on spawn

### Blacklist
Offensive words are blocked server-side (configurable in `config.lua` → `Config.Blacklist`).

### Config (config.lua)
| Key | Default | Description |
|-----|---------|-------------|
| `SPRAY_PERSIST_DAYS` | 2 | Days before auto-delete |
| `SPRAY_PROGRESSBAR_DURATION` | 20000 | ms to spray |
| `SPRAY_REMOVE_DURATION` | 30000 | ms to remove |

### SQL Setup
Run `spray.sql` to create the `sprays` table if it doesn't exist.

---

# Gang System (QBCore Built-in)

The gang system is part of **qb-core** itself — there is no separate gang resource. Gangs are defined in `qb-core/shared/gangs.lua` and managed through QBCore's player data system.

## Defined Gangs

| Gang Key | Label | Grades |
|----------|-------|--------|
| `none` | No Gang | Unaffiliated |
| `lostmc` | The Lost MC | Recruit → Enforcer → Shot Caller → Boss |
| `ballas` | Ballas | Recruit → Enforcer → Shot Caller → Boss |
| `vagos` | Vagos | Recruit → Enforcer → Shot Caller → Boss |
| `cartel` | Cartel | Recruit → Enforcer → Shot Caller → Boss |
| `families` | Families | Recruit → Enforcer → Shot Caller → Boss |
| `triads` | Triads | Recruit → Enforcer → Shot Caller → Boss |

All gangs have 4 grades (0-3). Grade 3 (`Boss`) has `isboss = true`, which grants access to the gang boss menu.

## How Gangs Work

### Assignment
- Admin command: `/setgang [id] [gang] [grade]` — sets a player's gang
- Player command: `/gang` — shows your current gang info
- Code: `Player.Functions.SetGang(gangName, gradeLevel)`

### Gang Boss Menu (qb-management)
- Boss-grade members can access a management menu at configured locations
- **Withdraw/deposit** from the gang's shared bank account (stored in `management_funds` table with `type = "gang"`)
- Gang menu locations are in `qb-management/client/cl_config.lua` → `Config.GangMenus`
- **Currently all gang menu coords are set to `vector3(0, 0, 0)`** — these need to be configured with real locations for each gang's HQ

### Gang Finances (qb-management exports)
| Export | Description |
|--------|-------------|
| `AddGangMoney(gang, amount)` | Add money to gang account |
| `RemoveGangMoney(gang, amount)` | Remove money from gang account |
| `GetGangAccount(gang)` | Get gang balance |

### Runtime Management (qb-core exports)
| Export | Description |
|--------|-------------|
| `AddGang(name, data)` | Register a new gang at runtime |
| `RemoveGang(name)` | Remove a gang |
| `UpdateGang(name, data)` | Update gang data |

### Traphouse (qb-traphouse)
Gangs can take over a traphouse location for $5,000. The traphouse:
- Has an enter point and interior interaction point
- Uses a PIN code system for access (default: 1234)
- Allows selling items from an allowed list (metals, electronics, drugs, etc.) for cash rewards
- Can be contested by other gangs

**Current traphouse location:** near `-1202.21, -1308.48, 4.92`

## Adding a New Gang

1. Add the gang definition to `qb-core/shared/gangs.lua`
2. (Optional) Add a gang menu location in `qb-management/client/cl_config.lua`
3. (Optional) Add a gang fund row in the `management_funds` database table
4. Use `/setgang` to assign players

## TODO
- Gang menu locations (`Config.GangMenus`) all point to `vector3(0,0,0)` — need real HQ coords
- Gang menu zones (`Config.GangMenuZones`) are empty — need to be set up for qb-target interaction
- No turf/territory system beyond the single traphouse
