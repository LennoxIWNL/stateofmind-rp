# Gang & Business Management Phone Apps

## Goal
Two NPWD phone apps for State of Mind RP:
1. **Gang App** — visible only when player is in a gang (`gang.name ~= 'none'`)
2. **Business App** — visible only when player is a job boss (`job.isboss == true`)

Both allow managing members live (no relog) with SOM pink branding.

## Features (both apps share the same pattern)

### Roster View
- List all online + offline members with name, rank, and online status
- Search/filter by name

### Hire / Recruit
- Hire nearby player (select from nearby list) or by server ID
- Player gets the gang/job assigned live via `SetGang` / `SetJob`
- New member gets a notification

### Fire / Remove
- Remove a member from the gang/job (sets them back to `none` / `unemployed`)
- Confirmation prompt before firing
- Player gets notified they were removed

### Promote / Demote
- Change a member's grade level
- Dropdown of available ranks
- Live update via `SetGang` / `SetJob` + client event push

### Custom Ranks (stretch goal)
- Boss can rename rank labels (e.g. "Recruit" to "Prospect")
- Stored in a new database table: `gang_custom_ranks` / `job_custom_ranks`
- Schema: `id, gang_or_job_name, grade_level, custom_label, created_by`
- Falls back to `gangs.lua` / `jobs.lua` defaults if no custom label set

## Technical Approach

### Option A — NPWD App (preferred)
- React/TypeScript frontend inside npwd's app system
- Register app via npwd's app API with conditional visibility
- Server-side: net events for roster, hire, fire, promote
- Requires: React build toolchain, npwd app registration

### Option B — Standalone NUI (simpler)
- Separate resource with HTML/CSS/JS panel (like som-jobsetup)
- Triggered by command (`/gangmenu`, `/bossmenu`) or keybind
- Not inside the phone UI, but same functionality
- Easier to build, no React needed

## QBCore Integration Points

### Gang operations (server-side)
```lua
-- Set a player's gang
Player.Functions.SetGang(gangName, gradeLevel)
-- Triggers: QBCore:Client:OnGangUpdate (live, no relog)

-- Get all players with a specific gang
for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
    local p = QBCore.Functions.GetPlayer(pid)
    if p.PlayerData.gang.name == gangName then ... end
end
```

### Job operations (server-side)
```lua
-- Set a player's job
Player.Functions.SetJob(jobName, gradeLevel)
-- Triggers: QBCore:Client:OnJobUpdate (live, no relog)
```

### Offline members
- Query database directly: `SELECT citizenid, charinfo, gang, job FROM players WHERE gang LIKE '%gangname%'`
- Can only modify offline players via `QBCore.Player.SaveOffline`

## Available Gangs (from gangs.lua)
| Name | Label | Grades |
|---|---|---|
| lostmc | The Lost MC | 0-3 (Recruit, Enforcer, Shot Caller, Boss) |
| ballas | Ballas | 0-3 |
| vagos | Vagos | 0-3 |
| cartel | Cartel | 0-3 |
| families | Families | 0-3 |
| triads | Triads | 0-3 |

## Available Boss Jobs (from jobs.lua, isboss = true at highest grade)
| Name | Label | Boss Grade |
|---|---|---|
| police | Law Enforcement | 4 (Chief) |
| ambulance | EMS | 4 (Chief) |
| burgershot | Burger Shot | 1 (Employer) |
| mechanic | Mechanic | needs checking |
| realestate | Real Estate | needs checking |
| cardealer | Car Dealer | needs checking |

## Database Tables Needed (for custom ranks)
```sql
CREATE TABLE IF NOT EXISTS `som_custom_ranks` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `type` ENUM('gang', 'job') NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `custom_label` VARCHAR(50) NOT NULL,
    `created_by` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_rank` (`type`, `name`, `grade`)
);
```

## UI Design
- SOM pink branding (#FF1493)
- Dark panel matching som-jobsetup style
- Tabs: Roster | Hire | Settings
- Member cards with name, rank badge, online indicator
- Confirm modals for destructive actions (fire/demote)

## Files Needed
```
som-gangboss-app/
  fxmanifest.lua
  config.lua
  server/main.lua        -- roster queries, hire/fire/promote/rank logic
  client/main.lua        -- NUI open/close, callbacks
  html/index.html        -- UI (or React build if NPWD route)
```

## Notes
- Player's phone number is in the `players` table (`phone_number` column)
- npwd is the active phone system (not qb-phone)
- ox_lib is available for notifications and callbacks
- qb-management already has partial hire/fire logic in `sv_boss.lua` and `sv_gang.lua` that could be referenced
