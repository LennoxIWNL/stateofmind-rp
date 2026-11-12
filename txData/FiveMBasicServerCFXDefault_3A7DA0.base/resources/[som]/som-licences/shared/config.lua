Config = {
    -- Closed list: the only licences this resource issues, checks or mirrors.
    types = {
        driver = { label = 'Driver licence', item = 'driver_license' },
        weapon = { label = 'Weapon licence', item = 'weaponlicense' },
    },

    -- One grade constant for every supervisory act: issuing a weapon licence,
    -- suspending, revoking and reinstating.
    approveGrade = 3,
    job = 'police',

    -- Ships disabled. Set coords, spawn and a route (LAUNCH-TODO.md).
    school = {
        enabled = false,
        coords = vec3(214.53, -1400.09, 30.58),  -- vec3 of the counter
        radius = 3.0,
        spawn = vec4(249.49, -1406.87, 30.56, 237.76),   -- vec4 where the test car appears
        model = 'asea',
        plate = 'LEARNER',
        fee = 400,     -- charged when the licence is issued, to the city treasury
    },

    theory = {
        questions = 10,
        pass = 8,
        retryMinutes = 30,
        maxMinutes = 15,
        practicalWindowMinutes = 20, -- how long a pass lets you start the drive
    },

    practical = {
        route = {},         -- list of vec3 checkpoints
        radius = 12.0,
        maxSpeed = 45.0,    -- m/s the server believes between two checkpoints
        speedLimit = 90.0,  -- km/h before a fault
        damageStep = 40.0,  -- body health lost in one tick that counts as a crash
        maxFaults = 3,
        leaveGraceSeconds = 15,
        maxMinutes = 12,
    },

    weapon = {
        fee = 5000,
        business = 'lspd',
        offerSeconds = 30,
    },

    police = {
        distance = 4.0,
        maxSuspendDays = 14,
    },
}
