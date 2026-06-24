Config = Config or {}

Config.WomanPlayerModels = {
    'mp_f_freemode_01',
    'a_f_m_bevhills_01',
    'a_f_m_bevhills_02',
    'a_f_m_business_02',
    'a_f_m_downtown_01',
    'a_f_m_eastsa_01',
    'a_f_m_ktown_01',
    'a_f_y_beach_01',
    'a_f_y_bevhills_01',
    'a_f_y_bevhills_02',
    'a_f_y_business_01',
    'a_f_y_business_02',
    'a_f_y_fitness_01',
    'a_f_y_genhot_01',
    'a_f_y_hiker_01',
    'a_f_y_hipster_01',
    'a_f_y_hipster_02',
    'a_f_y_indian_01',
    'a_f_y_runner_01',
    'a_f_y_scdressy_01',
    'a_f_y_skater_01',
    'a_f_y_soucent_01',
    'a_f_y_tourist_01',
    'a_f_y_vinewood_01',
    'a_f_y_vinewood_02',
    'a_f_y_yoga_01',
    's_f_m_fembarber',
    's_f_m_shop_high',
    's_f_y_bartender_01',
    's_f_y_cop_01',
    's_f_y_scrubs_01',
    's_f_y_sheriff_01',
    's_f_y_shop_low',
    's_f_y_shop_mid',
    'a_f_y_femaleagent',
    'a_f_y_hippie_01'
}

Config.ManPlayerModels = {
    'mp_m_freemode_01',
    'a_m_m_afriamer_01',
    'a_m_m_beach_01',
    'a_m_m_bevhills_01',
    'a_m_m_bevhills_02',
    'a_m_m_business_01',
    'a_m_m_eastsa_01',
    'a_m_m_farmer_01',
    'a_m_m_golfer_01',
    'a_m_m_indian_01',
    'a_m_m_ktown_01',
    'a_m_m_malibu_01',
    'a_m_m_polynesian_01',
    'a_m_m_skater_01',
    'a_m_m_soucent_01',
    'a_m_m_tourist_01',
    'a_m_y_beach_01',
    'a_m_y_bevhills_01',
    'a_m_y_bevhills_02',
    'a_m_y_business_01',
    'a_m_y_business_02',
    'a_m_y_downtown_01',
    'a_m_y_eastsa_01',
    'a_m_y_genstreet_01',
    'a_m_y_hiker_01',
    'a_m_y_hipster_01',
    'a_m_y_indian_01',
    'a_m_y_ktown_01',
    'a_m_y_latino_01',
    'a_m_y_runner_01',
    'a_m_y_skater_01',
    'a_m_y_soucent_01',
    'a_m_y_vinewood_01',
    'a_m_y_vinewood_02',
    's_m_m_doctor_01',
    's_m_m_paramedic_01',
    's_m_m_security_01',
    's_m_y_barman_01',
    's_m_y_chef_01',
    's_m_y_construct_01',
    's_m_y_cop_01',
    's_m_y_waiter_01',
    'a_m_y_hippy_01'
}
Config.LoadedManModels = {}
Config.LoadedWomanModels = {}

-- Set to true or false or GetConvar('UseTarget', 'false') == 'true' to use global option or script specific
-- These have to be a string thanks to how Convars are returned.
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

-- width, length, minZ and maxZ are for the size and height of the PolyZone
Config.Stores = {
    [1] = {shopType = 'clothing', coords = vector3(1693.32, 4823.48, 42.06), width = 2, length = 2},
    [2] = {shopType = 'clothing', coords = vector3(-712.215881, -155.352982, 38.4151268), width = 2, length = 2},
    [3] = {shopType = 'clothing', coords = vector3(-1192.94495, -772.688965, 18.3255997), width = 2, length = 2},
    [4] = {shopType = 'clothing', coords = vector3(425.236, -806.008, 29.491), width = 2, length = 2},
    [5] = {shopType = 'clothing', coords = vector3(-162.658, -303.397, 39.733), width = 2, length = 2},
    [6] = {shopType = 'clothing', coords = vector3(75.950, -1392.891, 29.376), width = 2, length = 2},
    [7] = {shopType = 'clothing', coords = vector3(-822.194, -1074.134, 11.328), width = 2, length = 2},
    [8] = {shopType = 'clothing', coords = vector3(-1450.711, -236.83, 49.809), width = 2, length = 2},
    [9] = {shopType = 'clothing', coords = vector3(4.254, 6512.813, 31.877), width = 2, length = 2},
    [10] = {shopType = 'clothing', coords = vector3(615.180, 2762.933, 42.088), width = 2, length = 2},
    [11] = {shopType = 'clothing', coords = vector3(1196.785, 2709.558, 38.222), width = 2, length = 2},
    [12] = {shopType = 'clothing', coords = vector3(-3171.453, 1043.857, 20.863), width = 2, length = 2},
    [13] = {shopType = 'clothing', coords = vector3(-1100.959, 2710.211, 19.107), width = 2, length = 2},
    [14] = {shopType = 'clothing', coords = vector3(-1207.65, -1456.88, 5.3784737586975), width = 2, length = 2},
    [15] = {shopType = 'clothing', coords = vector3(121.76, -224.6, 54.56), width = 2, length = 2},
    [16] = {shopType = 'barber', coords = vector3(-814.3, -183.8, 37.6), width = 2, length = 2},
    [17] = {shopType = 'barber', coords = vector3(136.8, -1708.4, 29.3), width = 2, length = 2},
    [18] = {shopType = 'barber', coords = vector3(-1282.6, -1116.8, 7.0), width = 2, length = 2},
    [19] = {shopType = 'barber', coords = vector3(1931.5, 3729.7, 32.8), width = 2, length = 2},
    [20] = {shopType = 'barber', coords = vector3(1212.8, -472.9, 66.2), width = 2, length = 2},
    [21] = {shopType = 'barber', coords = vector3(-32.9, -152.3, 57.1), width = 2, length = 2},
    [22] = {shopType = 'barber', coords = vector3(-278.1, 6228.5, 31.7), width = 2, length = 2}
}

-- set isGang to true if the requiredJob is a gang
Config.ClothingRooms = {
    [1] = {requiredJob = 'police', isGang = false, coords = vector3(454.43, -988.85, 29.00), width = 2, length = 2, cameraLocation = vector4(454.42, -990.52, 30.69, 358.48)},
    [2] = {requiredJob = 'ambulance', isGang = false, coords = vector3(298.99, -597.13, 43.28), width = 2, length = 2, cameraLocation = vector4(298.99, -597.13, 43.28, 290.25)}, -- Right double door in Hospital Map that is on QBCore GitHub
}

Config.Outfits = {
    ['police'] = {
        -- Job
        ['male'] = {
            -- Gender
            [0] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'PCSO',
                    outfitData = {
                        ["pants"] = {item = 61, texture = 0}, -- Pants
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 1, texture = 0}, -- T Shirt
                        ["vest"] = {item = 1, texture = 0}, -- Body Vest
                        ["torso2"] = {item = 2, texture = 0}, -- Jacket
                        ["shoes"] = {item = 63, texture = 0}, -- Shoes
                        ["hat"] = {item = 1, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
			-- Gender
            [1] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Constable',
                    outfitData = {
                        ["pants"] = {item = 61, texture = 0}, -- Pants
                    ["arms"] = {item = 0, texture = 0}, -- Arms
                    ["t-shirt"] = {item = 1, texture = 0}, -- T Shirt
                    ["vest"] = {item = 9, texture = 0}, -- Body Vest
                    ["torso2"] = {item = 2, texture = 0}, -- Jacket
                    ["shoes"] = {item = 63, texture = 0}, -- Shoes
                    ["hat"] = {item = 1, texture = 0}, -- Hat
                    ["glass"] = {item = -1, texture = 0}, -- Glasses
                    ["mask"] = {item = 0, texture = 0}, -- Mask
                    ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                    ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
			-- Gender
            [2] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'MO19',
                    outfitData = {
                        ["pants"] = {item = 61, texture = 0}, -- Pants
                    ["arms"] = {item = 0, texture = 0}, -- Arms
                    ["t-shirt"] = {item = 1, texture = 0}, -- T Shirt
                    ["vest"] = {item = 6, texture = 0}, -- Body Vest
                    ["torso2"] = {item = 90, texture = 0}, -- Jacket
                    ["shoes"] = {item = 63, texture = 0}, -- Shoes
                    ["hat"] = {item = -1, texture = -1}, -- Hat
                    ["glass"] = {item = -1, texture = 0}, -- Glasses
                    ["mask"] = {item = 0, texture = 0}, -- Mask
                    ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                    ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
			-- Gender
            [3] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'MO7',
                    outfitData = {
                        ["pants"] = {item = 28, texture = 0}, -- Pants
                        ["arms"] = {item = 15, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T Shirt
                        ["torso2"] = {item = 442, texture = 2}, -- Jacket
                        ["shoes"] = {item = 12, texture = 2}, -- Shoes
                        ["bag"] = {item = 5, texture = 0}, -- Bag
                        ["vest"] = {item = 0, texture = 0}, -- Body Vest
                        ["hat"] = {item = -1, texture = -1}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                    }
                }
            },
        },
        ['female'] = {
            -- Gender
            -- Gender
            [1] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Constable',
                    outfitData = {
                        ["pants"] = {item = 0, texture = 0}, -- Pants
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 16, texture = 0}, -- T Shirt
                        ["vest"] = {item = 1, texture = 0}, -- Body Vest
                        ["torso2"] = {item = 3, texture = 0}, -- Jacket
                        ["shoes"] = {item = 133, texture = 0}, -- Shoes
                        ["accessory"] = {item = 1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                        ["hat"] = {item = 14, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 8, texture = 0}, -- Mask
                        ["decals"] = {item = 1, texture = 0} -- Decals
                    }
                }
            },
			-- Gender
            [2] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'MO19',
                    outfitData = {
                        ["pants"] = {item = 133, texture = 0}, -- Pants
                    ["arms"] = {item = 31, texture = 0}, -- Arms
                    ["t-shirt"] = {item = 35, texture = 0}, -- T Shirt
                    ["vest"] = {item = 34, texture = 0}, -- Body Vest
                    ["torso2"] = {item = 327, texture = 8}, -- Jacket
                    ["shoes"] = {item = 52, texture = 0}, -- Shoes
                    ["accessory"] = {item = 0, texture = 0}, -- Neck Accessory
                    ["bag"] = {item = 0, texture = 0}, -- Bag
                    ["hat"] = {item = 0, texture = 0}, -- Hat
                    ["glass"] = {item = 0, texture = 0}, -- Glasses
                    ["mask"] = {item = 0, texture = 0} -- Mask
                    }
                }
            },
			-- Gender
            [3] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'mo7',
                    outfitData = {
                        ["pants"] = {item = 135, texture = 1}, -- Pants
                        ["arms"] = {item = 213, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 0, texture = 0}, -- T Shirt
                        ["vest"] = {item = 17, texture = 2}, -- Body Vest
                        ["torso2"] = {item = 327, texture = 8}, -- Jacket
                        ["shoes"] = {item = 52, texture = 0}, -- Shoes
                        ["accessory"] = {item = 102, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                        ["hat"] = {item = 149, texture = 0}, -- Hat
                        ["glass"] = {item = 0, texture = 0}, -- Glasses
                        ["mask"] = {item = 35, texture = 0} -- Mask
                    }
                }
            }
        }
    },
    ['realestate'] = {
        -- Job
        ['male'] = {
            -- Gender
            [0] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 28, texture = 0},  -- Pants
                    ["arms"]        = { item = 1, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 31, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 294, texture = 0},  -- Jacket
                    ["shoes"]       = { item = 10, texture = 0},  -- Shoes
                    ["accessory"]   = { item = 0, texture = 0},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = 12, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [1] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 28, texture = 0},  -- Pants
                    ["arms"]        = { item = 1, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 31, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 294, texture = 0},  -- Jacket
                    ["shoes"]       = { item = 10, texture = 0},  -- Shoes
                    ["accessory"]   = { item = 0, texture = 0},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = 12, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [2] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 28, texture = 0},  -- Pants
                    ["arms"]        = { item = 1, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 31, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 294, texture = 0},  -- Jacket
                    ["shoes"]       = { item = 10, texture = 0},  -- Shoes
                    ["accessory"]   = { item = 0, texture = 0},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = 12, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [3] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 28, texture = 0},  -- Pants
                    ["arms"]        = { item = 1, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 31, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 294, texture = 0},  -- Jacket
                    ["shoes"]       = { item = 10, texture = 0},  -- Shoes
                    ["accessory"]   = { item = 0, texture = 0},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = 12, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [4] = {
                -- Grade Level
                [1] = {
                    -- Outfits
                    outfitLabel = 'Short Sleeve',
                    outfitData = {
                    ["pants"]       = { item = 28, texture = 0},  -- Pants
                    ["arms"]        = { item = 1, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 31, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 294, texture = 0},  -- Jacket
                    ["shoes"]       = { item = 10, texture = 0},  -- Shoes
                    ["accessory"]   = { item = 0, texture = 0},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = 12, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            }
        },
        ['female'] = {
            -- Gender
            [0] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 57, texture = 2},  -- Pants
                    ["arms"]        = { item = 0, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 34, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 105, texture = 7},  -- Jacket
                    ["shoes"]       = { item = 8, texture = 5},  -- Shoes
                    ["accessory"]   = { item = 11, texture = 3},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = -1, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
            -- Gender
            [1] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 57, texture = 2},  -- Pants
                    ["arms"]        = { item = 0, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 34, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 105, texture = 7},  -- Jacket
                    ["shoes"]       = { item = 8, texture = 5},  -- Shoes
                    ["accessory"]   = { item = 11, texture = 3},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = -1, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [2] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 57, texture = 2},  -- Pants
                    ["arms"]        = { item = 0, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 34, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 105, texture = 7},  -- Jacket
                    ["shoes"]       = { item = 8, texture = 5},  -- Shoes
                    ["accessory"]   = { item = 11, texture = 3},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = -1, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [3] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 57, texture = 2},  -- Pants
                    ["arms"]        = { item = 0, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 34, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 105, texture = 7},  -- Jacket
                    ["shoes"]       = { item = 8, texture = 5},  -- Shoes
                    ["accessory"]   = { item = 11, texture = 3},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = -1, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            },
			-- Gender
            [4] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Worker',
                    outfitData = {
                    ["pants"]       = { item = 57, texture = 2},  -- Pants
                    ["arms"]        = { item = 0, texture = 0},  -- Arms
                    ["t-shirt"]     = { item = 34, texture = 0},  -- T Shirt
                    ["vest"]        = { item = 0, texture = 0},  -- Body Vest
                    ["torso2"]      = { item = 105, texture = 7},  -- Jacket
                    ["shoes"]       = { item = 8, texture = 5},  -- Shoes
                    ["accessory"]   = { item = 11, texture = 3},  -- Neck Accessory
                    ["bag"]         = { item = 0, texture = 0},  -- Bag
                    ["hat"]         = { item = -1, texture = -1},  -- Hat
                    ["glass"]       = { item = 0, texture = 0},  -- Glasses
                    ["mask"]        = { item = 0, texture = 0},  -- Mask
                    }
                }
            }
        }
    },
    ['ambulance'] = {
        -- Job
        ['male'] = {
            -- Gender
            [0] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Paramedic',
                    outfitData = {
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 65, texture = 1}, -- Jackets
                        ["pants"] = {item = 21, texture = 0}, -- Pants
                        ["shoes"] = {item = 63, texture = 0}, -- Shoes
                        ["vest"] = {item = 0, texture = 0}, -- Body Vest
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
            [1] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Doctor',
                    outfitData = {
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 65, texture = 3}, -- Jackets
                        ["pants"] = {item = 21, texture = 0}, -- Pants
                        ["shoes"] = {item = 63, texture = 0}, -- Shoes
                        ["vest"] = {item = 0, texture = 0}, -- Body Vest
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
            [2] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Sr.Doctor',
                    outfitData = {
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 65, texture = 6}, -- Jackets
                        ["pants"] = {item = 21, texture = 0}, -- Pants
                        ["shoes"] = {item = 63, texture = 0}, -- Shoes
                        ["vest"] = {item = 0, texture = 0}, -- Body Vest
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            },
            [3] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'CMO',
                    outfitData = {
                        ["arms"] = {item = 0, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 65, texture = 7}, -- Jackets
                        ["pants"] = {item = 21, texture = 0}, -- Pants
                        ["shoes"] = {item = 63, texture = 0}, -- Shoes
                        ["vest"] = {item = 0, texture = 0}, -- Body Vest
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                        ["glass"] = {item = -1, texture = 0}, -- Glasses
                        ["mask"] = {item = 0, texture = 0}, -- Mask
                        ["accessory"] = {item = -1, texture = 0}, -- Neck Accessory
                        ["bag"] = {item = 0, texture = 0}, -- Bag
                    }
                }
            }
        },
        ['female'] = {
            -- Gender
            [0] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Paramedic',
                    outfitData = {
                        ["arms"] = {item = 6, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 585, texture = 0}, -- Jackets
                        ["pants"] = {item = 251, texture = 0}, -- Pants
                        ["shoes"] = {item = 133, texture = 0}, -- Shoes
                        ["mask"] = {item = 8, texture = 0}, -- Mask
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                    }
                }
            },
            [1] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Doctor',
                    outfitData = {
                        ["arms"] = {item = 6, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 585, texture = 0}, -- Jackets
                        ["pants"] = {item = 251, texture = 0}, -- Pants
                        ["shoes"] = {item = 133, texture = 0}, -- Shoes
                        ["mask"] = {item = 8, texture = 0}, -- Mask
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                    }
                }
            },
            [2] = {
                -- Grade Level
                [1] = {
                    outfitLabel = 'Sr.Doctor',
                    outfitData = {
                        ["arms"] = {item = 6, texture = 0}, -- Arms
                        ["t-shirt"] = {item = 15, texture = 0}, -- T-Shirt
                        ["torso2"] = {item = 585, texture = 0}, -- Jackets
                        ["pants"] = {item = 251, texture = 0}, -- Pants
                        ["shoes"] = {item = 133, texture = 0}, -- Shoes
                        ["mask"] = {item = 8, texture = 0}, -- Mask
                        ["hat"] = {item = -1, texture = 0}, -- Hat
                    }
                }
            }
        }
    }
}
