Config = {}

-- Command that opens the setup menu (admin only by default).
Config.Command = 'jobsetup'

-- Only players with this ace permission can open the menu / edit points.
-- group.admin already has command.* allowed in server.cfg.
Config.AdminAce = 'command.jobsetup'

-- Default interaction distance for qb-target zones.
Config.TargetDistance = 2.0

-- How close (m) you must be for a marker to draw / be usable.
Config.MarkerDrawDistance = 25.0
Config.MarkerUseDistance = 1.5

-- Default marker style (GTA marker type 1 = cylinder).
Config.Marker = {
    type = 1,
    size = vec3(1.5, 1.5, 1.0),
    color = { r = 255, g = 20, b = 147, a = 120 }, -- State of Mind pink
}

-- The interaction "types" you can create. Purely organisational + sensible
-- defaults per type (you can override everything per-point in the menu).
-- `action` is what fires when the player interacts with the point.
--   kind = 'event'        -> TriggerEvent(name, args)
--   kind = 'server_event' -> TriggerServerEvent(name, args)
--   kind = 'command'      -> ExecuteCommand(name)
--   kind = 'export'       -> exports[resource][name](args)
-- Leave action empty to make a point that is just a blip/marker/ped (no action).
Config.Types = {
    garage = {
        label = 'Job Garage',
        blip = { sprite = 357, color = 49, scale = 0.7 },
        ped = 's_m_y_dealer_01',        -- garage attendant entity (relocatable)
        targetIcon = 'fas fa-warehouse',
        targetLabel = 'Vehicle Garage',
    },
    duty = {
        label = 'Duty Point',
        blip = { sprite = 351, color = 3, scale = 0.6 },
        ped = nil,
        targetIcon = 'fas fa-clipboard-check',
        targetLabel = 'Toggle Duty',
    },
    armory = {
        label = 'Armory',
        blip = { sprite = 110, color = 1, scale = 0.6 },
        ped = nil,
        targetIcon = 'fas fa-gun',
        targetLabel = 'Open Armory',
    },
    stash = {
        label = 'Stash',
        blip = nil,
        ped = nil,
        targetIcon = 'fas fa-box-archive',
        targetLabel = 'Open Stash',
    },
    shop = {
        label = 'Shop / Ped',
        blip = nil,
        ped = 's_m_m_security_01',
        targetIcon = 'fas fa-shop',
        targetLabel = 'Interact',
    },
    target = {
        label = 'Generic 3rd-eye',
        blip = nil,
        ped = nil,
        targetIcon = 'fas fa-hand-pointer',
        targetLabel = 'Interact',
    },
    blip = {
        label = 'Map Blip only',
        blip = { sprite = 1, color = 0, scale = 0.7 },
        ped = nil,
    },
}

-- Jobs you commonly set up. The menu lets you type any job name too, this is
-- just the quick-pick list. Match these to your QBCore job names.
Config.Jobs = {
    'police',
    'ambulance',
    'mechanic',
    'taxi',
    'realestate',
    'cardealer',
}

-- ===========================================================================
--  JOB-CONFIG INJECTION
--  These describe job scripts whose Config.Locations som-jobsetup can write
--  coordinates INTO directly (so the REAL interaction relocates, not a copy).
--  Each location type lists its vector arity (3 = vector3, 4 = vector4) and,
--  for entries shaped like {coords = vector4(...), ...}, the `nested` key.
--  Restarting the resource after a write makes it take effect live.
-- ===========================================================================
Config.JobConfigs = {
    ['qb-policejob'] = {
        label = 'Police — qb-policejob',
        file  = 'config.lua',
        restart = true,                 -- offer to restart after writing
        locations = {
            duty        = { arity = 3, label = 'Duty toggle' },
            vehicle     = { arity = 4, label = 'Garage / vehicle spawn' },
            stash       = { arity = 3, label = 'Stash' },
            impound     = { arity = 4, label = 'Impound' },
            helicopter  = { arity = 4, label = 'Helicopter spawn' },
            armory      = { arity = 3, label = 'Armory' },
            trash       = { arity = 3, label = 'Trash' },
            fingerprint = { arity = 3, label = 'Fingerprint scanner' },
            evidence    = { arity = 3, label = 'Evidence locker' },
        },
    },
    ['qb-ambulancejob'] = {
        label = 'Ambulance — qb-ambulancejob',
        file  = 'config.lua',
        restart = true,
        locations = {
            checking = { arity = 4, label = 'Hospital check-in (front desk)' },
            duty     = { arity = 4, label = 'Duty toggle' },
            armory   = { arity = 4, label = 'Armory' },
            roof     = { arity = 4, label = 'Roof (heli)' },
            main     = { arity = 3, label = 'Main entrance point' },
            basement = { arity = 3, label = 'Basement point' },
            stash    = { arity = 3, label = 'Stash' },
            beds     = { arity = 4, nested = 'coords', label = 'Patient beds' },
            jailbeds = { arity = 4, nested = 'coords', label = 'Jail/prison beds' },
        },
    },
}
