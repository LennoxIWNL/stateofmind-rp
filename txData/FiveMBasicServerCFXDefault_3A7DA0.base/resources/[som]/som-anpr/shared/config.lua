Config = {
    job = 'police',
    range = 80.0,                 -- cruiser to scanned vehicle, read server side
    cams = { front = true, rear = true },

    -- Only these models count as a police reader. Anything else is ignored.
    vehicles = { 'police', 'police2', 'police3', 'police4', 'policeb', 'pranger', 'fbi', 'fbi2', 'pitbullbb', 'sheriff', 'sheriff2' },

    minInterval = 250,            -- ms between scan events accepted from one player, before any work is done
    officerCooldown = 300,        -- seconds before the same officer is told about the same plate again
    plateCooldown = 300,          -- seconds between dispatch calls for the same plate
    callsPerMinute = 6,           -- dispatch calls from this resource overall, so a street of hot cars cannot flood the board
}
