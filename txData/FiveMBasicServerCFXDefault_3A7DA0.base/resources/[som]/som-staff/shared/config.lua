Config = {
    -- The gate is off unless `set som_whitelist 1` is in server.cfg, so a dev
    -- or beta server is not locked by accident.
    whitelistConvar = 'som_whitelist',
    deniedMessage = 'You are not on the whitelist. Apply in our Discord.',
    -- Identifier kinds that may be listed. A licence is the normal one.
    identifierKinds = { license = true, license2 = true, discord = true, steam = true },

    reportMax = 200,
    reportCooldown = 60,   -- seconds between reports for one character
    listMax = 30,

    -- Resources whose content can be placed in game (see som-core/server/placements.lua).
    placeable = { ['som-turf'] = true, ['som-outdoors'] = true, ['som-heists'] = true, ['som-mechanic'] = true, ['som-launder'] = true, ['som-shops'] = true, ['som-fuel'] = true, ['som-ems'] = true, ['som-dmv'] = true, ['som-welcome'] = true, ['som-boosting'] = true, ['som-burglary'] = true },
    placeableList = { 'som-turf', 'som-outdoors', 'som-heists', 'som-mechanic', 'som-launder', 'som-shops', 'som-fuel', 'som-ems', 'som-dmv', 'som-welcome', 'som-boosting', 'som-burglary' },

    -- A disconnect during a scene is logged for staff to judge; nothing is punished.
    combatLog = {
        callRadius = 150.0, callWindow = 180, policeRadius = 40.0,
        cooldown = 300,     -- one row per character per this many seconds
        repeatCount = 3,    -- rows in 24 hours that mark a repeat
        listMax = 10,
    },
}
