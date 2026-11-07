Config = {
    job = 'tow',
    -- The department that asks for the tow pays the driver.
    payer = 'lspd',
    fee = 400,
    maxPaidPerHour = 6,

    -- A ticket nobody takes becomes an instant impound after this long, so a car is never left flagged.
    ticketMinutes = 20,
    -- A ticket taken and not delivered goes back to the board after this long.
    claimMinutes = 10,
    maxClaimed = 2,
    sweepSeconds = 60,

    -- Must be the same lot as Config.Stations.mrpd.impound.coords in som-police.
    yard = { coords = vec3(407.9, -1633.5, 29.29), radius = 40.0 },
    -- The driver has to be this close to the car when it is delivered.
    driverRadius = 40.0,
}
