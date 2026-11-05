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
        crafting = { label = 'Crafting', blurb = 'Harder recipes at the benches' },
    },

    -- What each level opens, for the Skills app. The gates themselves are in the
    -- resource that owns the work (minLevel on a spot, strain, animal, recipe or
    -- repair); keep the two in step.
    unlocks = {
        { track = 'fishing', level = 4, text = 'Deep water spots open' },
        { track = 'hunting', level = 3, text = 'Boar can be skinned' },
        { track = 'growing', level = 5, text = 'OG Kush seeds can be planted' },
        { track = 'growing', level = 7, text = 'Amnesia seeds can be planted' },
        { track = 'chemistry', level = 2, text = 'Refine coca leaves' },
        { track = 'chemistry', level = 4, text = 'Cook meth' },
        { track = 'mechanic', level = 2, text = 'Body repairs' },
        { track = 'crafting', level = 2, text = 'Repair kits at the bench' },
        { track = 'crafting', level = 5, text = 'Advanced kits and lockpicks' },
    },
}
