-- Copyright (C) 2021 KUMApt & Shadowskrt

Config = {}

Config.UseLanguage = "en"                                                           -- Select the language you want to use in the script (the translation is at the end of the file)
Config.UseSoundEffect = true                                                        -- Only use this if you use InteractSound
Config.UseTarget = GetConvar('UseTarget', 'true') == 'true'
Config.Elevators = {
    -- The following tags are not required! You can add them if you want
    -- Group = "jobname" or "gangname" -> Only player with this job or gang can can go to the restricted floors
    -- Sound = "soundname" -> Use custom sound when player reaches the new floor | You can add your custom sound with .ogg extension in interactSound folder /client/html/sounds
    -- Simple example with restricted floors and custom sound
    ["ambulance"] = {
        Group = {"police", "ambulance"},                                -- Leave blank if you don't want to use Player Job - You can add jobs or gangs groups
        Sound = "liftSoundBellRing",                                                -- Leave blank if you don't want to use Custom Sound
        Name = "pillbox Hospital",
        Floors = {
            [1] = {
                Label = "Floor [ 0 ] Garage",
                FloorDesc = "Go to Floor -1; Garage ",
                Restricted = false,
                Coords = vector3(341.48, -580.91, 28.8),
                ExitHeading = "250.55"
            },
            [2] = {
                Label = "Floor [ 1 ] main",
                FloorDesc = "Go to main Floor 1",
                Restricted = false,                                                  -- Only players with defined job (Job = "") can change to this floor
                Coords = vector3(331.98162, -595.538, 43.284084),
                ExitHeading = "83.448646"
            },
            [3] = {
                Label = "Roof",
                FloorDesc = "Go to The Roof",
                Restricted = true,
                Coords = vector3(338.76, -583.81, 74.17),
                ExitHeading = "260.75"
            },
        }
    },
    ["nopixel1"] = {
        Group = {"police", "ambulance"},                                -- Leave blank if you don't want to use Player Job - You can add jobs or gangs groups
        Sound = "liftSoundBellRing",                                                -- Leave blank if you don't want to use Custom Sound
        Name = "pillbox Hospital",
        Floors = {
            [1] = {
                Label = "Floor [ 1 ] main",
                FloorDesc = "Go to main Floor 1",
                Restricted = false,                                                  -- Only players with defined job (Job = "") can change to this floor
                Coords = vector3(360.57635, -1410.341, 32.429656),
                ExitHeading = "323.5288"
            },
            [2] = {
                Label = "Roof",
                FloorDesc = "Go to The Roof",
                Restricted = true,
                Coords = vector3(335.14929, -1432.53, 46.513748 ),
                ExitHeading = "144.5166"
            },
        }
    },
    ["crafting"] = {
        -- Group = {},                                -- Leave blank if you don't want to use Player Job - You can add jobs or gangs groups
        Sound = "liftSoundBellRing",                                                -- Leave blank if you don't want to use Custom Sound
        Name = "Under Ground",
        Floors = {
            [1] = {
                Label = "out side",
                FloorDesc = "Go to out side ",
                Restricted = true,
                Coords = vector3(485.46759, -3383.674, 6.0699133),
                ExitHeading = "6.0448241"
            },
            [2] = {
                Label = "Inside",
                FloorDesc = "Go toInside",
                Restricted = false,                                                  -- Only players with defined job (Job = "") can change to this floor
                Coords = vector3(894.54699, -3246.244, -98.25997),
                ExitHeading = "93.485885"
            },
        }
    },
    ["apartment"] = {
        Group = {"police", "ambulance"},     
        -- Group = {},                                -- Leave blank if you don't want to use Player Job - You can add jobs or gangs groups
        Sound = "liftSoundBellRing",                                                -- Leave blank if you don't want to use Custom Sound
        Name = "Apartment",
        Floors = {
            [1] = {
                Label = "Exit Apartment",
                FloorDesc = "Go outside",
                Restricted = true,
                Coords = vector3(-1002.81, -477.7, 50.03),
                ExitHeading = "305.89587"
            },
            [2] = {
                Label = "State of Mind RP",
                FloorDesc = "Here your New Journey Starts",
                Restricted = false,                                                  -- Only players with defined job (Job = "") can change to this floor
                Coords = vector3(-1007.1, -486.59, 39.97),
                ExitHeading = "127.17"
            },
        }
    },
    ["vespuccipd"] = {
        Group = {"police"},
        Sound = "liftSoundBellRing",
        Name = "Vespucci PD",
        Floors = {
            [1] = {
                Label = "Garage",
                FloorDesc = "Go to the Garage",
                Restricted = false,
                Coords = vector3(-1097.37, -849.39, 5.06),
                ExitHeading = "221.42"
            },
            [2] = {
                Label = "Main Floor",
                FloorDesc = "Go to the Main Floor",
                Restricted = false,
                Coords = vector3(-1097.30, -849.20, 19.31),
                ExitHeading = "216.03"
            },
            [3] = {
                Label = "Second Floor",
                FloorDesc = "Go to the Second Floor",
                Restricted = false,
                Coords = vector3(-1097.26, -849.29, 26.83),
                ExitHeading = "227.93"
            },
            [4] = {
                Label = "Third Floor",
                FloorDesc = "Go to the Third Floor",
                Restricted = false,
                Coords = vector3(-1097.29, -849.29, 30.95),
                ExitHeading = "234.03"
            },
            [5] = {
                Label = "Top Floor",
                FloorDesc = "Go to the Top Floor",
                Restricted = true,
                Coords = vector3(-1097.31, -849.23, 34.28),
                ExitHeading = "225.89"
            },
        }
    },
}

Config.Language = {
    ["en"] = {
        Call = "~g~E~w~ - Call Lift",
        Waiting = "Waiting for Lift...",
        Restricted = "Restricted floor!",
        CurrentFloor = "Current floor: "
    },
}
