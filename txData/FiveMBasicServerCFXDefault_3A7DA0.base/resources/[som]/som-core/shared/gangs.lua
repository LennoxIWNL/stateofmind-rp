-- Gang definitions. Unlike the legacy qbx gangs table these carry a payment
-- field, because Phase 6 gives gangs an economic identity through turf.
--
-- payment is the passive per-interval cut paid from the gang account, funded
-- by turf income. It is not minted: if the gang account is empty, nobody is paid.

Gangs = {
    none = {
        label = 'No Gang',
        grades = {
            [0] = { name = 'Unaffiliated' },
        },
    },

    lostmc = {
        label = 'The Lost MC',
        color = '#8b1a1a',
        grades = {
            [0] = { name = 'Prospect', payment = 0 },
            [1] = { name = 'Member', payment = 20 },
            [2] = { name = 'Enforcer', payment = 35 },
            [3] = { name = 'Road Captain', payment = 50 },
            [4] = { name = 'President', payment = 75, isboss = true },
        },
    },

    ballas = {
        label = 'Ballas',
        color = '#6b3fa0',
        grades = {
            [0] = { name = 'Recruit', payment = 0 },
            [1] = { name = 'Member', payment = 20 },
            [2] = { name = 'Shot Caller', payment = 35 },
            [3] = { name = 'Lieutenant', payment = 50 },
            [4] = { name = 'Boss', payment = 75, isboss = true },
        },
    },

    vagos = {
        label = 'Vagos',
        color = '#d4a017',
        grades = {
            [0] = { name = 'Recruit', payment = 0 },
            [1] = { name = 'Member', payment = 20 },
            [2] = { name = 'Shot Caller', payment = 35 },
            [3] = { name = 'Lieutenant', payment = 50 },
            [4] = { name = 'Boss', payment = 75, isboss = true },
        },
    },

    families = {
        label = 'Families',
        color = '#2e8b57',
        grades = {
            [0] = { name = 'Recruit', payment = 0 },
            [1] = { name = 'Member', payment = 20 },
            [2] = { name = 'Shot Caller', payment = 35 },
            [3] = { name = 'Lieutenant', payment = 50 },
            [4] = { name = 'Boss', payment = 75, isboss = true },
        },
    },

    cartel = {
        label = 'Cartel',
        color = '#b8860b',
        grades = {
            [0] = { name = 'Runner', payment = 0 },
            [1] = { name = 'Soldier', payment = 25 },
            [2] = { name = 'Sicario', payment = 40 },
            [3] = { name = 'Underboss', payment = 60 },
            [4] = { name = 'Jefe', payment = 85, isboss = true },
        },
    },
}
