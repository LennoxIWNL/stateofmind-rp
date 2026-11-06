Config = {
    job = 'ambulance',
    business = 'ems',
    distance = 3.0,         -- medic to patient
    cooldownSeconds = 60,   -- per patient, so one body is not farmed

    -- The kit is consumed on a successful revive and the patient is billed the
    -- price for the service (paid to the EMS business account). The server
    -- rejects a finish that comes sooner than `seconds` after the start.
    revive = { item = 'firstaid', count = 1, price = 600, seconds = 15 },
}
