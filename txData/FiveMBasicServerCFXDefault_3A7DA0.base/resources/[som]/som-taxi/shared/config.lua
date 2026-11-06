Config = {
    job = 'taxi',
    business = 'downtowncab',
    vehicles = { 'taxi' },     -- models the meter will run in

    baseFare = 20,
    perKm = 60,
    perWaitMinute = 10,
    maxFare = 1500,

    -- Share of the fare the company pays the driver. The server clamps it to 0.5,
    -- so a trip can never pay out more than it took in.
    commission = 0.2,
    hourlyCommissionCap = 1500,

    -- A trip shorter than this charges nothing, so two characters cannot cycle
    -- money with a few steps of driving.
    minMeters = 400,

    maxStepMeters = 80.0,      -- distance counted in one second; more is a teleport
    passengerDistance = 15.0,  -- how close a passenger who just got out must be
    offerSeconds = 30,
}
