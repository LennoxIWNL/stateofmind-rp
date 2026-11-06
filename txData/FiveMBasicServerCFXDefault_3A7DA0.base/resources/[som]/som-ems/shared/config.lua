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

    revive = { item = 'firstaid', count = 1, price = 600, seconds = 15 },
}
