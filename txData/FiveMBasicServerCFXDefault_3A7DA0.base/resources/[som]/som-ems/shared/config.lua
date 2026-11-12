Config = {
    job = 'ambulance',
    business = 'ems',
    distance = 3.0,         -- medic to patient
    cooldownSeconds = 60,   -- per patient, so one body is not farmed

    -- The kit is consumed on a successful revive and the patient is billed the
    -- price for the service (paid to the EMS business account). The server
    -- rejects a finish that comes sooner than `seconds` after the start.
    staleSeconds = 120,     -- a started treatment that is never finished expires

    -- Free kit issue from the department (som-economy's departmentIssue), capped
    -- by what the medic already carries. Ships disabled until placed.
    locker = { enabled = false, label = 'EMS supply locker', coords = nil, distance = 2.5, item = 'firstaid', max = 3 },

    -- Hospital transport. Ships closed until the desk and bed are placed. The
    -- patient pays `fee` at admission (into the ems account) and the medic is
    -- paid from that account, never more than `payShare` of the fee.
    hospital = {
        enabled = false, label = 'Pillbox Hill Medical Center',
        desk = vec3(298.60, -584.60, 43.26), bed = nil,
        distance = 3.0,         -- medic to desk
        vehicleDistance = 15.0, -- ambulance to desk
        loadDistance = 5.0,     -- medic to ambulance
        vehicles = { 'ambulance' },
        seats = { 1, 2 },
        fee = 250, payShare = 0.6, minDownSeconds = 30, bedSeconds = 8,
        bedAnim = { dict = 'missarmenian2', clip = 'drunk_loop' },
    },

    revive = { item = 'firstaid', count = 1, price = 600, seconds = 15 },
}
