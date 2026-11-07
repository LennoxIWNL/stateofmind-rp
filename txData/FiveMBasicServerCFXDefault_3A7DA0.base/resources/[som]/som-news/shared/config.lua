Config = {
    -- Ships off: nobody can publish and nothing is paid until this is true (LAUNCH-TODO.md).
    enabled = false,

    job = 'news',
    feedSize = 25,
    breakingWindowMinutes = 120,

    headline = { min = 8, max = 80 },
    -- A body this short is not a story, and pay is per story.
    body = { min = 60, max = 500 },

    gapSeconds = { story = 120, breaking = 600 },
    breakingNetworkGapSeconds = 300,   -- one breaking alert in this time across all reporters together

    -- Only stories pay. The city treasury is the source; an empty treasury pays nothing.
    pay = {
        perStory = 150,
        perReporterHourly = 600,
        hourlyCap = 3000,
    },
}
