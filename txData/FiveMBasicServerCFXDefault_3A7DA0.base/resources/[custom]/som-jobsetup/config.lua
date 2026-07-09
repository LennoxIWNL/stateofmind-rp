Config = {}

Config.Command = 'jobsetup'

Config.AdminAce = 'command.jobsetup'

Config.TargetDistance = 2.0

Config.MarkerDrawDistance = 25.0
Config.MarkerUseDistance = 1.5

Config.Marker = {
    type = 1,
    size = vec3(1.5, 1.5, 1.0),
    color = { r = 255, g = 20, b = 147, a = 120 },
}

Config.Types = {
    garage = {
        label = 'Job Garage',
        blip = { sprite = 357, color = 49, scale = 0.7 },
        ped = 's_m_y_dealer_01',
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

Config.Jobs = {
    'police',
    'ambulance',
    'mechanic',
    'taxi',
    'realestate',
    'cardealer',
}

Config.JobConfigs = {
    ['qb-policejob'] = {
        label = 'Police - qb-policejob',
        file  = 'config.lua',
        restart = true,
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
        label = 'Ambulance - qb-ambulancejob',
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
