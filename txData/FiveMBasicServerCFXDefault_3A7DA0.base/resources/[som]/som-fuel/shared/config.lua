Config = {
    business = 'fuelco',        -- sales account the pump money lands in (setup.sql)
    tank = 100,                 -- fuel units in a full tank; one unit is one litre here
    pricePerLitre = 4,          -- default, a station may set its own `price`
    stationDistance = 15.0,     -- player to the station point, read server side
    vehicleDistance = 6.0,      -- player to the vehicle being filled
    cooldownMs = 1500,          -- minimum time between money actions from one player
    accounts = { 'cash', 'bank' },

    -- A full jerry can holds `capacity` units; `pour` is poured per use.
    can = { price = 120, capacity = 25, pour = 5, distance = 4.0 },

    -- Burn per second while the engine runs: base plus a share that grows with speed (m/s).
    drain = { base = 0.012, perSpeed = 0.0016, publishEvery = 10, warnBelow = 10.0 },

    pumpModels = { 'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c', 'prop_gas_pump_1d', 'prop_gas_pump_old2', 'prop_gas_pump_old3', 'prop_vintage_pump' },

    -- Ship closed and unplaced: staff set each point with `/place som-fuel stations.<name>.coords`.
    stations = {
        { name = 'station_1', label = 'Gas station 1', enabled = false, coords = nil },
        { name = 'station_2', label = 'Gas station 2', enabled = false, coords = nil },
        { name = 'station_3', label = 'Gas station 3', enabled = false, coords = nil },
        { name = 'station_4', label = 'Gas station 4', enabled = false, coords = nil },
        { name = 'station_5', label = 'Gas station 5', enabled = false, coords = nil },
        { name = 'station_6', label = 'Gas station 6', enabled = false, coords = nil },
        { name = 'station_7', label = 'Gas station 7', enabled = false, coords = nil },
        { name = 'station_8', label = 'Gas station 8', enabled = false, coords = nil },
    },
}
