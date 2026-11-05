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
    placeable = { ['som-turf'] = true, ['som-outdoors'] = true, ['som-heists'] = true, ['som-mechanic'] = true, ['som-launder'] = true },
    placeableList = { 'som-turf', 'som-outdoors', 'som-heists', 'som-mechanic', 'som-launder' },
}
