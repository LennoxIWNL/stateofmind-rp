Config = {
    -- Ships closed. Staff set the counter with `/place som-dmv desk.coords`.
    desk = { enabled = false, label = 'DMV', coords = nil, distance = 3.0 },

    registration = {
        days = 14,       -- one renewal buys this long, and the grace for a car seen for the first time
        fee = 150,
        cooldownMs = 2000,
    },

    vanity = {
        fee = 2500,
        cooldownMinutes = 60,   -- per character, between plate changes
        minLength = 2,
        maxLength = 8,
        -- Lua patterns on the upper case plate. Police, emergency and government
        -- looks, and a few words nobody should be driving around with. Staff extend this.
        blocked = {
            'LSPD', 'POLICE', 'POLIC', 'COP', 'SAHP', 'SWAT', 'FBI', 'DOJ', 'EMS', 'MEDIC', 'FIRE',
            'GOV', 'MAYOR', 'JUDGE', 'SHERIFF', 'ADMIN', 'STAFF', 'TAXI',
            'NIGG', 'FAGG', 'CUNT', 'RAPE', 'NAZI', 'HITLER', 'KKK',
        },
    },
}
