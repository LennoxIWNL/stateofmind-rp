Config = {
    maxLevel = 10,
    -- Experience needed for level n is base * (n - 1)^2, so early levels come
    -- quickly and the last ones take real time.
    base = 120,
    -- Experience that counts per track per day. Past it, work still pays but no
    -- more experience, so the levels reward time spread over weeks, not a grind.
    dailyCap = 1500,

    tracks = {
        fishing = { label = 'Fishing', blurb = 'Better catches, rarer finds' },
        hunting = { label = 'Hunting', blurb = 'Cleaner kills, better trophies' },
        growing = { label = 'Growing', blurb = 'Bigger harvests' },
        chemistry = { label = 'Chemistry', blurb = 'Faster, steadier cooks' },
        mechanic = { label = 'Mechanic', blurb = 'Trusted with harder repairs' },
        scrapping = { label = 'Scrapping', blurb = 'More parts from every car' },
    },
}
