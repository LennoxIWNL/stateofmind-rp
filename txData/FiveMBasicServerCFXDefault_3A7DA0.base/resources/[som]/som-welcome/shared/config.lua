Config = {
    -- The settling-in payment: once per character, paid from the city treasury
    -- only after every step is done, and capped across all characters.
    payment = 1000,
    monthlyCap = 20000,     -- total paid out in any 30 days, all characters together

    -- A job counts for the step only after being held this long, so changing
    -- jobs back and forth at the desk cannot satisfy it.
    jobMinutes = 30,

    -- Ships closed. Staff set the desk with `/place som-welcome desk.coords`.
    desk = { enabled = false, label = 'Job centre', coords = nil, distance = 3.0, cooldownMinutes = 30 },

    -- The only jobs the desk hands out, at grade 0. Whitelisted jobs never belong here.
    jobs = {
        { name = 'taxi', label = 'Cab driver, Downtown Cab Co.' },
        { name = 'delivery', label = 'Courier, Post OP' },
    },

    -- Plain text shown in the phone app. Fill in the real places before launch (LAUNCH-TODO.md).
    guide = {
        { title = 'Your phone', sub = 'Open it with your phone key. Your bank, contacts, messages and jobs are apps on it.' },
        { title = 'Your money', sub = 'The Bank app shows your card balance. Shops let you pay cash or card.' },
        { title = 'Work', sub = 'The Jobs app lets a group queue for a contract. The job centre hands out ordinary jobs.' },
        { title = 'Getting around', sub = 'Take the theory and driving test at the driving school for a licence. The DMV registers your car.' },
        { title = 'A place to live', sub = 'Buy or rent a home. An agent can show you what is for sale or rent.' },
    },
}
