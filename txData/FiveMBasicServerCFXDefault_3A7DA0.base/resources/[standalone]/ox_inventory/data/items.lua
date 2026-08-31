return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = 'Bandage',
		-- kept at ox stock's weight; qb-core's source catalog lists 0 for this
		-- item, which looks like a data error there rather than intentional.
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 300,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 30000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	-- SOM PATCH. On the AUDIT 16.2 re-apply list with the other items.
	--
	-- Police entry tool for som-housing raids. Heavy and unstackable on purpose:
	-- carrying one is a decision, and an officer should not have four.
	--
	-- The image is WEAPON_HAMMER.png, which ox_inventory already ships. Pointing
	-- client.image at an existing file rather than adding a new PNG keeps this
	-- to a code change: a binary asset is outside what gets edited here, and
	-- there are already 61 blank icons in this inventory without adding a 62nd.
	['breach_ram'] = {
		label = 'Battering Ram',
		weight = 8000,
		stack = false,
		close = true,
		description = 'Police entry tool. Loud.',
		client = {
			image = 'WEAPON_HAMMER.png',
		},
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 300,
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

	-- Ported from the old qb-core item catalog: fixes nil Shared.Items lookups
	-- surfaced by qb-crypto, qb-bankrobbery, qb-prison, qb-houserobbery, and
	-- jim-jobgarage during boot testing. The full old catalog has more items
	-- than are ported here (see qbx_core/shared/items.lua) -- only the ones
	-- confirmed referenced by active resources are added.
	['cryptostick'] = {
		label = 'Crypto Stick',
		weight = 200,
		stack = false,
		client = {
			image = 'cryptostick.png'
		}
	},

	['thermite'] = {
		label = 'Thermite',
		weight = 1000,
		client = {
			image = 'thermite.png'
		}
	},

	['electronickit'] = {
		label = 'Electronic Kit',
		weight = 100,
		client = {
			image = 'electronickit.png'
		}
	},

	['advancedlockpick'] = {
		label = 'Advanced Lockpick',
		weight = 500,
		client = {
			image = 'advancedlockpick.png'
		}
	},

	['heavyarmor'] = {
		label = 'Heavy Armor',
		weight = 5000,
		client = {
			image = 'heavyarmor.png'
		}
	},

	['empty_evidence_bag'] = {
		label = 'Empty Evidence Bag',
		weight = 0,
		stack = true,
		client = {
			image = 'empty_evidence_bag.png'
		}
	},

	['police_stormram'] = {
		label = 'Stormram',
		weight = 18000,
		client = {
			image = 'police_stormram.png'
		}
	},

	-- Full catalog port from the old qb-core item catalog (qbx_core/shared/items.lua),
	-- 577 entries. Excludes: weapon-typed entries (handled by data/weapons.lua),
	-- the 7 items ported above in the first boot-test pass, 4 items with
	-- crafting/combinable behavior handled separately (see data/crafting.lua and
	-- the phone/radio/bandage/burger/parachute/lockpick conflict merges below),
	-- and 2 zero-reference combinables (rolling_paper, ironoxide) that were dropped.

	['clip_attachment'] = {
		label = 'Clip',
		weight = 1000,
		description = 'A clip for a weapon',
	},

	['drum_attachment'] = {
		label = 'Drum',
		weight = 1000,
		description = 'A drum for a weapon',
	},

	['flashlight_attachment'] = {
		label = 'Flashlight',
		weight = 1000,
		description = 'A flashlight for a weapon',
	},

	['suppressor_attachment'] = {
		label = 'Suppressor',
		weight = 1000,
		description = 'A suppressor for a weapon',
	},

	['smallscope_attachment'] = {
		label = 'Small Scope',
		weight = 1000,
		description = 'A small scope for a weapon',
	},

	['medscope_attachment'] = {
		label = 'Medium Scope',
		weight = 1000,
		description = 'A medium scope for a weapon',
	},

	['largescope_attachment'] = {
		label = 'Large Scope',
		weight = 1000,
		description = 'A large scope for a weapon',
	},

	['holoscope_attachment'] = {
		label = 'Holo Scope',
		weight = 1000,
		description = 'A holo scope for a weapon',
	},

	['advscope_attachment'] = {
		label = 'Advanced Scope',
		weight = 1000,
		description = 'An advanced scope for a weapon',
	},

	['nvscope_attachment'] = {
		label = 'Night Vision Scope',
		weight = 1000,
		description = 'A night vision scope for a weapon',
	},

	['thermalscope_attachment'] = {
		label = 'Thermal Scope',
		weight = 1000,
		description = 'A thermal scope for a weapon',
	},

	['flat_muzzle_brake'] = {
		label = 'Flat Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['tactical_muzzle_brake'] = {
		label = 'Tactical Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brakee for a weapon',
	},

	['fat_end_muzzle_brake'] = {
		label = 'Fat End Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['precision_muzzle_brake'] = {
		label = 'Precision Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['heavy_duty_muzzle_brake'] = {
		label = 'HD Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['slanted_muzzle_brake'] = {
		label = 'Slanted Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['split_end_muzzle_brake'] = {
		label = 'Split End Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['squared_muzzle_brake'] = {
		label = 'Squared Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['bellend_muzzle_brake'] = {
		label = 'Bellend Muzzle Brake',
		weight = 1000,
		description = 'A muzzle brake for a weapon',
	},

	['barrel_attachment'] = {
		label = 'Barrel',
		weight = 1000,
		description = 'A barrel for a weapon',
	},

	['grip_attachment'] = {
		label = 'Grip',
		weight = 1000,
		description = 'A grip for a weapon',
	},

	['comp_attachment'] = {
		label = 'Compensator',
		weight = 1000,
		description = 'A compensator for a weapon',
	},

	['luxuryfinish_attachment'] = {
		label = 'Luxury Finish',
		weight = 1000,
		description = 'A luxury finish for a weapon',
	},

	['digicamo_attachment'] = {
		label = 'Digital Camo',
		weight = 1000,
		description = 'A digital camo for a weapon',
	},

	['brushcamo_attachment'] = {
		label = 'Brushstroke Camo',
		weight = 1000,
		description = 'A brushstroke camo for a weapon',
	},

	['woodcamo_attachment'] = {
		label = 'Woodland Camo',
		weight = 1000,
		description = 'A woodland camo for a weapon',
	},

	['skullcamo_attachment'] = {
		label = 'Skull Camo',
		weight = 1000,
		description = 'A skull camo for a weapon',
	},

	['sessantacamo_attachment'] = {
		label = 'Sessanta Nove Camo',
		weight = 1000,
		description = 'A sessanta nove camo for a weapon',
	},

	['perseuscamo_attachment'] = {
		label = 'Perseus Camo',
		weight = 1000,
		description = 'A perseus camo for a weapon',
	},

	['leopardcamo_attachment'] = {
		label = 'Leopard Camo',
		weight = 1000,
		description = 'A leopard camo for a weapon',
	},

	['zebracamo_attachment'] = {
		label = 'Zebra Camo',
		weight = 1000,
		description = 'A zebra camo for a weapon',
	},

	['geocamo_attachment'] = {
		label = 'Geometric Camo',
		weight = 1000,
		description = 'A geometric camo for a weapon',
	},

	['boomcamo_attachment'] = {
		label = 'Boom Camo',
		weight = 1000,
		description = 'A boom camo for a weapon',
	},

	['patriotcamo_attachment'] = {
		label = 'Patriot Camo',
		weight = 1000,
		description = 'A patriot camo for a weapon',
	},

	['weapontint_0'] = {
		label = 'Default Tint',
		weight = 1000,
		description = 'Default/Black Weapon Tint',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_1'] = {
		label = 'Green Tint',
		weight = 1000,
		description = 'Green Weapon Tint',
		client = {
			image = 'weapontint_green.png'
		},
	},

	['weapontint_2'] = {
		label = 'Gold Tint',
		weight = 1000,
		description = 'Gold Weapon Tint',
		client = {
			image = 'weapontint_gold.png'
		},
	},

	['weapontint_3'] = {
		label = 'Pink Tint',
		weight = 1000,
		description = 'Pink Weapon Tint',
		client = {
			image = 'weapontint_pink.png'
		},
	},

	['weapontint_4'] = {
		label = 'Army Tint',
		weight = 1000,
		description = 'Army Weapon Tint',
		client = {
			image = 'weapontint_army.png'
		},
	},

	['weapontint_5'] = {
		label = 'LSPD Tint',
		weight = 1000,
		description = 'LSPD Weapon Tint',
		client = {
			image = 'weapontint_lspd.png'
		},
	},

	['weapontint_6'] = {
		label = 'Orange Tint',
		weight = 1000,
		description = 'Orange Weapon Tint',
		client = {
			image = 'weapontint_orange.png'
		},
	},

	['weapontint_7'] = {
		label = 'Platinum Tint',
		weight = 1000,
		description = 'Platinum Weapon Tint',
		client = {
			image = 'weapontint_plat.png'
		},
	},

	['weapontint_mk2_0'] = {
		label = 'Classic Black Tint',
		weight = 1000,
		description = 'Classic Black Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_1'] = {
		label = 'Classic Gray Tint',
		weight = 1000,
		description = 'Classic Gray Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_2'] = {
		label = 'Classic Two-Tone Tint',
		weight = 1000,
		description = 'Classic Two-Tone Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_3'] = {
		label = 'Classic White Tint',
		weight = 1000,
		description = 'Classic White Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_4'] = {
		label = 'Classic Beige Tint',
		weight = 1000,
		description = 'Classic Beige Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_5'] = {
		label = 'Classic Green Tint',
		weight = 1000,
		description = 'Classic Green Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_6'] = {
		label = 'Classic Blue Tint',
		weight = 1000,
		description = 'Classic Blue Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_7'] = {
		label = 'Classic Earth Tint',
		weight = 1000,
		description = 'Classic Earth Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_8'] = {
		label = 'Classic Brown & Black Tint',
		weight = 1000,
		description = 'Classic Brown & Black Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_9'] = {
		label = 'Red Contrast Tint',
		weight = 1000,
		description = 'Red Contrast Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_10'] = {
		label = 'Blue Contrast Tint',
		weight = 1000,
		description = 'Blue Contrast Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_11'] = {
		label = 'Yellow Contrast Tint',
		weight = 1000,
		description = 'Yellow Contrast Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_12'] = {
		label = 'Orange Contrast Tint',
		weight = 1000,
		description = 'Orange Contrast Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_13'] = {
		label = 'Bold Pink Tint',
		weight = 1000,
		description = 'Bold Pink Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_14'] = {
		label = 'Bold Purple & Yellow Tint',
		weight = 1000,
		description = 'Bold Purple & Yellow Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_15'] = {
		label = 'Bold Orange Tint',
		weight = 1000,
		description = 'Bold Orange Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_16'] = {
		label = 'Bold Green & Purple Tint',
		weight = 1000,
		description = 'Bold Green & Purple Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_17'] = {
		label = 'Bold Red Features Tint',
		weight = 1000,
		description = 'Bold Red Features Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_18'] = {
		label = 'Bold Green Features Tint',
		weight = 1000,
		description = 'Bold Green Features Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_19'] = {
		label = 'Bold Cyan Features Tint',
		weight = 1000,
		description = 'Bold Cyan Features Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_20'] = {
		label = 'Bold Yellow Features Tint',
		weight = 1000,
		description = 'Bold Yellow Features Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_21'] = {
		label = 'Bold Red & White Tint',
		weight = 1000,
		description = 'Bold Red & White Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_22'] = {
		label = 'Bold Blue & White Tint',
		weight = 1000,
		description = 'Bold Blue & White Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_23'] = {
		label = 'Metallic Gold Tint',
		weight = 1000,
		description = 'Metallic Gold Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_24'] = {
		label = 'Metallic Platinum Tint',
		weight = 1000,
		description = 'Metallic Platinum Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_25'] = {
		label = 'Metallic Gray & Lilac Tint',
		weight = 1000,
		description = 'Metallic Gray & Lilac Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_26'] = {
		label = 'Metallic Purple & Lime Tint',
		weight = 1000,
		description = 'Metallic Purple & Lime Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_27'] = {
		label = 'Metallic Red Tint',
		weight = 1000,
		description = 'Metallic Red Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_28'] = {
		label = 'Metallic Green Tint',
		weight = 1000,
		description = 'Metallic Green Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_29'] = {
		label = 'Metallic Blue Tint',
		weight = 1000,
		description = 'Metallic Blue Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_30'] = {
		label = 'Metallic White & Aqua Tint',
		weight = 1000,
		description = 'Metallic White & Aqua Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_31'] = {
		label = 'Metallic Orange & Yellow Tint',
		weight = 1000,
		description = 'Metallic Orange & Yellow Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['weapontint_mk2_32'] = {
		label = 'Metallic Red and Yellow Tint',
		weight = 1000,
		description = 'Metallic Red and Yellow Weapon Tint for MK2 Weapons',
		client = {
			image = 'weapontint_black.png'
		},
	},

	['pistol_ammo'] = {
		label = 'Pistol ammo',
		weight = 200,
		description = 'Ammo for Pistols',
	},

	['rifle_ammo'] = {
		label = 'Rifle ammo',
		weight = 1000,
		description = 'Ammo for Rifles',
	},

	['smg_ammo'] = {
		label = 'SMG ammo',
		weight = 500,
		description = 'Ammo for Sub Machine Guns',
	},

	['shotgun_ammo'] = {
		label = 'Shotgun ammo',
		weight = 500,
		description = 'Ammo for Shotguns',
	},

	['mg_ammo'] = {
		label = 'MG ammo',
		weight = 1000,
		description = 'Ammo for Machine Guns',
	},

	['snp_ammo'] = {
		label = 'Sniper ammo',
		weight = 1000,
		description = 'Ammo for Sniper Rifles',
		client = {
			image = 'rifle_ammo.png'
		},
	},

	['emp_ammo'] = {
		label = 'EMP Ammo',
		weight = 200,
		description = 'Ammo for EMP Launcher',
	},

	-- SOM PATCH: rental agreement issued by som-rentals. The metadata is the
	-- point: ox renders `description` in the tooltip, so hovering the papers
	-- shows the plate, the renter and the time it was taken out.
	['rental_papers'] = {
		label = 'Rental Agreement',
		weight = 10,
		stack = false,
		close = true,
		description = 'A vehicle rental agreement',
		-- A stack of document folders. Owner asked specifically for a folder or
		-- file for this one. Pointed at rather than renamed, so the art keeps
		-- its own name for whatever already uses it.
		client = { image = 'printerdocument.png' },
	},

	-- SOM PATCH: identity documents are shown to players nearby by som-id.
	-- Re-apply these three client.export lines after an ox_inventory upgrade.
	['id_card'] = {
		label = 'ID Card',
		weight = 0,
		stack = false,
		close = false,
		description = 'A card containing all your information to identify yourself',
		client = {
			export = 'som-id.useIdCard',
		},
	},

	['idcard'] = {
		label = 'ID Card',
		weight = 0,
		stack = false,
		close = false,
		description = 'A card containing all your information to identify yourself',
		client = {
			image = 'id_card.png'
		},
	},

	['driver_license'] = {
		label = 'Drivers License',
		weight = 0,
		stack = false,
		close = false,
		description = 'Permit to show you can drive a vehicle',
		client = {
			export = 'som-id.useDriverLicense',
		},
	},

	['lawyerpass'] = {
		label = 'Lawyer Pass',
		weight = 0,
		stack = false,
		close = false,
		description = 'Pass exclusive to lawyers to show they can represent a suspect',
	},

	['weaponlicense'] = {
		label = 'Weapon License',
		weight = 0,
		stack = false,
		description = 'Weapon License',
		client = {
			image = 'weapon_license.png',
			export = 'som-id.useWeaponLicense',
		},
	},

	['bank_card'] = {
		label = 'Bank Card',
		weight = 0,
		stack = false,
		description = 'Used to access ATM',
	},

	['security_card_01'] = {
		label = 'Security Card A',
		weight = 0,
		description = 'A security card... I wonder what it goes to',
	},

	['security_card_02'] = {
		label = 'Security Card B',
		weight = 0,
		description = 'A security card... I wonder what it goes to',
	},

	['tosti'] = {
		label = 'Grilled Cheese Sandwich',
		weight = 200,
		description = 'Nice to eat',
	},

	['twerks_candy'] = {
		label = 'Twerks',
		weight = 100,
		description = 'Some delicious candy :O',
	},

	['snikkel_candy'] = {
		label = 'Snikkel',
		weight = 100,
		description = 'Some delicious candy :O',
	},

	['sandwich'] = {
		label = 'Sandwich',
		weight = 200,
		description = 'Nice bread for your stomach',
		-- Had no client block at all, so eating it did nothing: no animation,
		-- no prop, and no effect on hunger. Matched to burger's values rather
		-- than inventing a second tier for food.
		--
		-- The reference template had this feeding THIRST, which is a mistake in
		-- that template and is not copied.
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'sandwich',
			usetime = 2500,
		},
	},

	['water_bottle'] = {
		label = 'Bottle of Water',
		weight = 500,
		description = 'For all the thirsty out there',
	},

	['coffee'] = {
		label = 'Coffee',
		weight = 200,
		description = 'Pump 4 Caffeine',
	},

	['kurkakola'] = {
		label = 'Cola',
		weight = 500,
		description = 'For all the thirsty out there',
		client = {
			image = 'cola.png'
		},
	},

	['beer'] = {
		label = 'Beer',
		weight = 500,
		description = 'Nothing like a good cold beer!',
	},

	['whiskey'] = {
		label = 'Whiskey',
		weight = 1000,
		description = 'This is not a bottle of booze!',
	},

	['vodka'] = {
		label = 'Vodka',
		weight = 500,
		description = 'For all the thirsty out there',
	},

	['grape'] = {
		label = 'Grape',
		weight = 100,
		close = false,
		description = 'Mmmmh yummie, grapes',
	},

	['wine'] = {
		label = 'Wine',
		weight = 300,
		close = false,
		description = 'Some good wine to drink on a fine evening',
	},

	['grapejuice'] = {
		label = 'Grape Juice',
		weight = 200,
		close = false,
		description = 'Grape juice is said to be healthy',
	},

	['joint'] = {
		label = 'Joint',
		weight = 0,
		description = 'Sidney would be very proud at you',
	},

	['cokebaggy'] = {
		label = 'Bag of Coke',
		weight = 0,
		description = 'To get happy real quick',
		client = {
			image = 'cocaine_baggy.png'
		},
	},

	['crack_baggy'] = {
		label = 'Bag of Crack',
		weight = 0,
		description = 'To get happy faster',
	},

	['xtcbaggy'] = {
		label = 'Bag of XTC',
		weight = 0,
		description = 'Pop those pills baby',
		client = {
			image = 'xtc_baggy.png'
		},
	},

	['coke_brick'] = {
		label = 'Coke Brick',
		weight = 1000,
		stack = false,
		description = 'Heavy package of cocaine, mostly used for deals and takes a lot of space',
	},

	['weed_brick'] = {
		label = 'Weed Brick',
		weight = 1000,
		description = '1KG Weed Brick to sell to large customers.',
	},

	['coke_small_brick'] = {
		label = 'Coke Package',
		weight = 350,
		stack = false,
		description = 'Small package of cocaine, mostly used for deals and takes a lot of space',
	},

	['oxy'] = {
		label = 'Prescription Oxy',
		weight = 0,
		description = 'The Label Has Been Ripped Off',
	},

	['meth'] = {
		label = 'Meth',
		weight = 100,
		description = 'A baggie of Meth',
		client = {
			image = 'meth_baggy.png'
		},
	},

	['weed_whitewidow'] = {
		label = 'White Widow 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g White Widow',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_skunk'] = {
		label = 'Skunk 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g Skunk',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_purplehaze'] = {
		label = 'Purple Haze 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g Purple Haze',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_ogkush'] = {
		label = 'OGKush 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g OG Kush',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_amnesia'] = {
		label = 'Amnesia 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g Amnesia',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_ak47'] = {
		label = 'AK47 2g',
		weight = 200,
		close = false,
		description = 'A weed bag with 2g AK47',
		client = {
			image = 'weed_baggy.png'
		},
	},

	['weed_whitewidow_seed'] = {
		label = 'White Widow Seed',
		weight = 0,
		close = false,
		description = 'A weed seed of White Widow',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_skunk_seed'] = {
		label = 'Skunk Seed',
		weight = 0,
		description = 'A weed seed of Skunk',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_purplehaze_seed'] = {
		label = 'Purple Haze Seed',
		weight = 0,
		description = 'A weed seed of Purple Haze',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_ogkush_seed'] = {
		label = 'OGKush Seed',
		weight = 0,
		description = 'A weed seed of OG Kush',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_amnesia_seed'] = {
		label = 'Amnesia Seed',
		weight = 0,
		description = 'A weed seed of Amnesia',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_ak47_seed'] = {
		label = 'AK47 Seed',
		weight = 0,
		description = 'A weed seed of AK47',
		client = {
			image = 'weed_seed.png'
		},
	},

	['weed_seed'] = {
		label = 'Weed Seed',
		weight = 0,
		description = 'A Basic weed seed',
	},

	['empty_weed_bag'] = {
		label = 'Empty Weed Bag',
		weight = 0,
		description = 'A small empty bag',
		client = {
			image = 'weed_baggy_empty.png'
		},
	},

	['weed_nutrition'] = {
		label = 'Plant Fertilizer',
		weight = 2000,
		description = 'Plant nutrition',
	},

	['dust'] = {
		label = 'Plant Dust',
		weight = 2000,
		description = 'Plant nutrition',
		client = {
			image = 'weed_nutrition.png'
		},
	},

	['plastic'] = {
		label = 'Plastic',
		weight = 100,
		close = false,
		description = 'RECYCLE! - Greta Thunberg 2019',
	},

	['metalscrap'] = {
		label = 'Metal Scrap',
		weight = 100,
		close = false,
		description = 'You can probably make something nice out of this',
	},

	['copper'] = {
		label = 'Copper',
		weight = 100,
		close = false,
		description = 'Nice piece of metal that you can probably use for something',
	},

	['aluminum'] = {
		label = 'Aluminium',
		weight = 100,
		close = false,
		description = 'Nice piece of metal that you can probably use for something',
	},

	['aluminumoxide'] = {
		label = 'Aluminium Powder',
		weight = 100,
		close = false,
		description = 'Some powder to mix with',
	},

	['iron'] = {
		label = 'Iron',
		weight = 100,
		close = false,
		description = 'Handy piece of metal that you can probably use for something',
	},

	['steel'] = {
		label = 'Steel',
		weight = 100,
		close = false,
		description = 'Nice piece of metal that you can probably use for something',
	},

	['rubber'] = {
		label = 'Rubber',
		weight = 100,
		close = false,
		description = 'Rubber, I believe you can make your own rubber ducky with it :D',
	},

	['glass'] = {
		label = 'Glass',
		weight = 100,
		close = false,
		description = 'It is very fragile, watch out',
	},

	['gatecrack'] = {
		label = 'Gatecrack',
		weight = 0,
		description = 'Handy software to tear down some fences',
		client = {
			image = 'usb_device.png'
		},
	},

	['trojan_usb'] = {
		label = 'Trojan USB',
		weight = 0,
		description = 'Handy software to shut down some systems',
		client = {
			image = 'usb_device.png'
		},
	},

	['screwdriverset'] = {
		label = 'Toolkit',
		weight = 1000,
		close = false,
		description = 'Very useful to screw... screws...',
	},

	['drill'] = {
		label = 'Drill',
		weight = 20000,
		close = false,
		description = 'The real deal...',
	},

	['nitrous'] = {
		label = 'Nitrous',
		weight = 1000,
		description = 'Speed up, gas pedal! :D',
	},

	['repairkit'] = {
		label = 'Repairkit',
		weight = 2500,
		description = 'A nice toolbox with stuff to repair your vehicle',
	},

	['advancedrepairkit'] = {
		label = 'Advanced Repairkit',
		weight = 4000,
		description = 'A nice toolbox with stuff to repair your vehicle',
		client = {
			image = 'advancedkit.png'
		},
	},

	['cleaningkit'] = {
		label = 'Cleaning Kit',
		weight = 250,
		description = 'A microfiber cloth with some soap will let your car sparkle again!',
	},

	['tunerlaptop'] = {
		label = 'Tunerchip',
		weight = 2000,
		stack = false,
		description = 'With this tunerchip you can get your car on steroids... If you know what you\'re doing',
		client = {
			image = 'tunerchip.png'
		},
	},

	['harness'] = {
		label = 'Race Harness',
		weight = 1000,
		stack = false,
		description = 'Racing Harness so no matter what you stay in the car',
	},

	['jerry_can'] = {
		label = 'Jerrycan 20L',
		weight = 20000,
		description = 'A can full of Fuel',
	},

	['tirerepairkit'] = {
		label = 'Tire Repair Kit',
		weight = 1000,
		description = 'A kit to repair your tires',
	},

	['veh_toolbox'] = {
		label = 'Toolbox',
		weight = 1000,
		description = 'Check vehicle status',
	},

	['veh_armor'] = {
		label = 'Armor',
		weight = 1000,
		description = 'Upgrade vehicle armor',
	},

	['veh_brakes'] = {
		label = 'Brakes',
		weight = 1000,
		description = 'Upgrade vehicle brakes',
	},

	['veh_engine'] = {
		label = 'Engine',
		weight = 1000,
		description = 'Upgrade vehicle engine',
	},

	['veh_suspension'] = {
		label = 'Suspension',
		weight = 1000,
		description = 'Upgrade vehicle suspension',
	},

	['veh_transmission'] = {
		label = 'Transmission',
		weight = 1000,
		description = 'Upgrade vehicle transmission',
	},

	['veh_turbo'] = {
		label = 'Turbo',
		weight = 1000,
		description = 'Install vehicle turbo',
	},

	['veh_interior'] = {
		label = 'Interior',
		weight = 1000,
		description = 'Upgrade vehicle interior',
	},

	['veh_exterior'] = {
		label = 'Exterior',
		weight = 1000,
		description = 'Upgrade vehicle exterior',
	},

	['veh_wheels'] = {
		label = 'Wheels',
		weight = 1000,
		description = 'Upgrade vehicle wheels',
	},

	['veh_neons'] = {
		label = 'Neons',
		weight = 1000,
		description = 'Upgrade vehicle neons',
	},

	['veh_xenons'] = {
		label = 'Xenons',
		weight = 1000,
		description = 'Upgrade vehicle xenons',
	},

	['veh_tint'] = {
		label = 'Tints',
		weight = 1000,
		description = 'Install vehicle tint',
	},

	['veh_plates'] = {
		label = 'Plates',
		weight = 1000,
		description = 'Install vehicle plates',
	},

	['firstaid'] = {
		label = 'First Aid',
		weight = 2500,
		description = 'You can use this First Aid kit to get people back on their feet',
	},

	['ifaks'] = {
		label = 'ifaks',
		weight = 200,
		description = 'ifaks for healing and a complete stress remover.',
		client = {
			image = 'ifak.png'
		},
	},

	['painkillers'] = {
		label = 'Painkillers',
		weight = 0,
		description = 'For pain you can\'t stand anymore, take this pill that\'d make you feel great again',
	},

	['walkstick'] = {
		label = 'Walking Stick',
		weight = 1000,
		description = 'Walking stick for ya\'ll grannies out there.. HAHA',
	},

	['iphone'] = {
		label = 'iPhone',
		weight = 1000,
		description = 'Very expensive phone',
	},

	['samsungphone'] = {
		label = 'Samsung S10',
		weight = 1000,
		description = 'Very expensive phone',
	},

	['laptop'] = {
		label = 'Laptop',
		weight = 4000,
		description = 'Expensive laptop',
	},

	['tablet'] = {
		label = 'Tablet',
		weight = 2000,
		description = 'Expensive tablet',
	},

	['fitbit'] = {
		label = 'Fitbit',
		weight = 500,
		stack = false,
		description = 'I like fitbit',
	},

	['radioscanner'] = {
		label = 'Radio Scanner',
		weight = 1000,
		description = 'With this you can get some police alerts. Not 100% effective however',
	},

	['pinger'] = {
		label = 'Pinger',
		weight = 1000,
		description = 'With a pinger and your phone you can send out your location',
	},

	['rolex'] = {
		label = 'Golden Watch',
		weight = 1500,
		description = 'A golden watch seems like the jackpot to me!',
	},

	['diamond_ring'] = {
		label = 'Diamond Ring',
		weight = 200,
		close = false,
	},

	['diamond'] = {
		label = 'Diamond',
		weight = 100,
		close = false,
		description = 'A Diamond that shimmers',
	},

	['goldchain'] = {
		label = 'Golden Chain',
		weight = 200,
		close = false,
	},

	-- Keyed by '10kgoldchain' (not 'tenkgoldchain', the qb-core source table's
	-- key) to match its own `name` field and what qb-pawnshop/qb-jewelery/
	-- qb-traphouse actually call.
	['10kgoldchain'] = {
		label = '10k Gold Chain',
		weight = 2000,
		description = '10 carat golden chain',
		client = {
			image = '10kgoldchain.png'
		},
	},

	['goldbar'] = {
		label = 'Gold Bar',
		weight = 500,
		description = 'Looks pretty expensive to me',
	},

	['armor'] = {
		label = 'Armor',
		weight = 5000,
		description = 'Some protection won\'t hurt... right?',
	},

	['handcuffs'] = {
		label = 'Handcuffs',
		weight = 100,
		description = 'Comes in handy when people misbehave. Maybe it can be used for something else?',
	},

	['filled_evidence_bag'] = {
		label = 'Evidence Bag',
		weight = 200,
		stack = false,
		close = false,
		description = 'A filled evidence bag to see who committed the crime >:(',
		client = {
			image = 'evidence.png'
		},
	},

	['firework1'] = {
		label = '2Brothers',
		weight = 1000,
		description = 'Fireworks',
	},

	['firework2'] = {
		label = 'Poppelers',
		weight = 1000,
		description = 'Fireworks',
	},

	['firework3'] = {
		label = 'WipeOut',
		weight = 1000,
		description = 'Fireworks',
	},

	['firework4'] = {
		label = 'Weeping Willow',
		weight = 1000,
		description = 'Fireworks',
	},

	['dendrogyra_coral'] = {
		label = 'Dendrogyra',
		weight = 1000,
		description = 'Its also known as pillar coral',
	},

	['antipatharia_coral'] = {
		label = 'Antipatharia',
		weight = 1000,
		description = 'Its also known as black corals or thorn corals',
	},

	['diving_gear'] = {
		label = 'Diving Gear',
		weight = 30000,
		stack = false,
		description = 'An oxygen tank and a rebreather',
	},

	['diving_fill'] = {
		label = 'Diving Tube',
		weight = 3000,
		stack = false,
		client = {
			image = 'diving_tube.png'
		},
	},

	['casinochips'] = {
		label = 'Casino Chips',
		weight = 0,
		close = false,
		description = 'Chips For Casino Gambling',
	},

	['stickynote'] = {
		label = 'Sticky note',
		weight = 0,
		stack = false,
		close = false,
		description = 'Sometimes handy to remember something :)',
	},

	['moneybag'] = {
		label = 'Money Bag',
		weight = 0,
		stack = false,
		description = 'A bag with cash',
	},

	['binoculars'] = {
		label = 'Binoculars',
		weight = 600,
		description = 'Sneaky Breaky...',
	},

	['lighter'] = {
		label = 'Lighter',
		weight = 0,
		description = 'On new years eve a nice fire to stand next to',
	},

	['certificate'] = {
		label = 'Certificate',
		weight = 0,
		description = 'Certificate that proves you own certain stuff',
	},

	['markedbills'] = {
		label = 'Marked Money',
		weight = 1000,
		stack = false,
		description = 'Money?',
	},

	['labkey'] = {
		label = 'Key',
		weight = 500,
		stack = false,
		description = 'Key for a lock...?',
	},

	['printerdocument'] = {
		label = 'Document',
		weight = 500,
		stack = false,
		description = 'A nice document',
	},

	['newscam'] = {
		label = 'News Camera',
		weight = 100,
		stack = false,
		description = 'A camera for the news',
	},

	['newsmic'] = {
		label = 'News Microphone',
		weight = 100,
		stack = false,
		description = 'A microphone for the news',
	},

	['newsbmic'] = {
		label = 'Boom Microphone',
		weight = 100,
		stack = false,
		description = 'A Useable BoomMic',
	},

	['classic_phone'] = {
		label = 'Classic Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['black_phone'] = {
		label = 'Black Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['blue_phone'] = {
		label = 'Blue Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['gold_phone'] = {
		label = 'Gold Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['red_phone'] = {
		label = 'Red Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['green_phone'] = {
		label = 'Green Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['greenlight_phone'] = {
		label = 'Green Light Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['pink_phone'] = {
		label = 'Pink Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['white_phone'] = {
		label = 'White Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['wet_phone'] = {
		label = 'Wet Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
		client = {
			image = 'wet_classic_phone.png'
		},
	},

	['wet_classic_phone'] = {
		label = 'Wet Classic Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
	},

	['wet_black_phone'] = {
		label = 'Wet Black Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
	},

	['wet_blue_phone'] = {
		label = 'Wet Blue Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
	},

	['wet_gold_phone'] = {
		label = 'Wet Gold Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
	},

	['wet_red_phone'] = {
		label = 'Wet Red Phone',
		weight = 700,
		stack = false,
		description = 'Did you really think that swimming in the ocean with your phone was a good idea?',
	},

	['wet_green_phone'] = {
		label = 'Wet Green Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['wet_greenlight_phone'] = {
		label = 'Wet Green Light Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['wet_pink_phone'] = {
		label = 'Wet Pink Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['wet_white_phone'] = {
		label = 'Wet White Phone',
		weight = 700,
		stack = false,
		description = 'They say that Quasar Smartphone is the same as an iPhone, what do you think?',
	},

	['phone_hack'] = {
		label = 'Phone Hack',
		weight = 300,
		stack = false,
		description = 'With this chip, you can access hidden areas of Discord.',
	},

	['phone_module'] = {
		label = 'Phone Module',
		weight = 300,
		stack = false,
		description = 'It seems that we can fix a wet phone with this module, interesting.',
	},

	['powerbank'] = {
		label = 'Power Bank',
		weight = 150,
		stack = false,
		description = 'Incredible portable charger!',
	},

	['spikespack'] = {
		label = 'Spikes Pack',
		weight = 0,
		stack = false,
		description = 'A 5 spikes pack for your needs.',
	},

	['nikon'] = {
		label = 'Nikoff G900',
		weight = 1000,
		stack = false,
		description = 'Caught in 4K',
		-- Points at the existing camera art rather than renaming the file, the
		-- same way ifaks points at ifak.png. Non-destructive: camera.png stays
		-- available under its own name if a second camera item ever wants it.
		client = { image = 'camera.png' },
	},

	['gsrtestkit'] = {
		label = 'GSR Field Test Kit',
		weight = 200,
		description = 'A field GSR test kit containing several test strips',
	},

	['dnatestkit'] = {
		label = 'DNA Field Swab Kit',
		weight = 200,
		description = 'A field DNA swab kit containing several vials and swabs',
	},

	['drugtestkit'] = {
		label = 'Drug Test Kit',
		weight = 200,
		description = 'A multipanel field test kit used to test for popular drugs in a suspects saliva, it\'s probably accurate.',
	},

	['breathalyzer'] = {
		label = 'Breathalyzer',
		weight = 200,
		description = 'A vintage 2000\'s WiWang breathalyzer engraved Property of LSPD',
	},

	['accesstool'] = {
		label = 'Access Tool',
		weight = 500,
		stack = false,
		description = 'Snap into an access tool.',
	},

	['fingerprintreader'] = {
		label = 'Pro Tech XFR8001',
		weight = 200,
		stack = false,
		description = 'A Pro Tech mobile fingerprint reader that looks like it\'s seen better days, currently stuck in french.',
		-- A real biometric fingerprint terminal, which is what this is.
		client = { image = 'finger_scanner.png' },
	},

	['sdcard'] = {
		label = 'SD Card',
		weight = 1000,
		stack = false,
		description = 'People still use these??',
	},

	['tshirt'] = {
		label = 'T-shirt',
		weight = 0,
		stack = false,
		description = 'Tshirt',
	},

	['torso'] = {
		label = 'Torso',
		weight = 0,
		stack = false,
		description = 'Torso',
	},

	['arms'] = {
		label = 'Arms',
		weight = 0,
		stack = false,
		description = 'Arms',
	},

	['jeans'] = {
		label = 'Jeans',
		weight = 0,
		stack = false,
		description = 'Jeans',
	},

	['shoes'] = {
		label = 'Shoes',
		weight = 0,
		stack = false,
		description = 'Shoes',
	},

	['mask'] = {
		label = 'Mask',
		weight = 0,
		stack = false,
		description = 'Mask',
	},

	['ears'] = {
		label = 'Ears',
		weight = 0,
		stack = false,
		description = 'Ears',
	},

	['glasses'] = {
		label = 'Glasses',
		weight = 0,
		stack = false,
		description = 'Glasses',
	},

	['helmet'] = {
		label = 'Helmet',
		weight = 0,
		stack = false,
		description = 'Helmet',
	},

	['bag'] = {
		label = 'Bag',
		weight = 10,
		description = 'Bag.',
	},

	['body_cam'] = {
		label = 'Body Cam',
		weight = 0,
		stack = false,
		description = 'Body cam for law enforcers',
		client = {
			image = 'bodycam.png'
		},
	},

	['bandageg'] = {
		label = 'Bandage',
		weight = 500,
		description = 'A rolled bandage',
		client = { image = 'bandage.png' },
	},

	['gauze'] = {
		label = 'Gauze',
		weight = 500,
		description = 'Sterile gauze roll',
		-- Our bandage art is a realistic gauze roll already, so this is the
		-- closest honest match rather than a new asset.
		client = { image = 'bandage.png' },
	},

	['tape'] = {
		label = 'Tape',
		weight = 500,
		description = 'edit here',
	},

	['surgical_tray'] = {
		label = 'Surgical tray',
		weight = 500,
		description = 'edit here',
	},

	['iodine'] = {
		label = 'Iodine',
		weight = 500,
		description = 'edit here',
	},

	['syringe'] = {
		label = 'Syringe',
		weight = 500,
		description = 'edit here',
	},

	['forceps'] = {
		label = 'Forceps',
		weight = 500,
		description = 'edit here',
	},

	['pill'] = {
		label = 'Pill',
		weight = 500,
		description = 'edit here',
	},

	['surgical_gloves'] = {
		label = 'Surgical gloves',
		weight = 500,
		description = 'edit here',
	},

	['surgical_staple'] = {
		label = 'Surgical staple',
		weight = 500,
		description = 'edit here',
	},

	['spray'] = {
		label = 'Spray Paint',
		weight = 300,
		close = false,
		description = 'Spray Anywhere Boys',
	},

	['spray_remover'] = {
		label = 'Spray Removal Kit',
		weight = 300,
		description = 'Remove the sprays, increase the heat btw gangs!',
	},

	['syphoningkit'] = {
		label = 'Syphoning Kit',
		weight = 5000,
		stack = false,
		close = false,
		description = 'A kit made to siphon gasoline from vehicles.',
	},

	['jerrycan'] = {
		label = 'Jerry Can',
		weight = 15000,
		stack = false,
		close = false,
		description = 'A Jerry Can made to hold gasoline.',
	},

	['thermite_bomb'] = {
		label = 'Thermite Bomb',
		weight = 100,
		description = 'Explosive',
		client = {
			image = 'thermite.png'
		},
	},

	['c4_bomb'] = {
		label = 'C4 Bomb',
		weight = 220,
		description = 'Explosive',
		client = {
			image = 'np_c4.png'
		},
	},

	['cutter'] = {
		label = 'Cutter',
		weight = 15000,
		description = 'Cutter.',
		client = {
			image = 'trimming_scissors.png'
		},
	},

	['paintingg'] = {
		label = 'Painting G',
		weight = 120,
		description = 'Painting G',
	},

	['paintingf'] = {
		label = 'Painting F',
		weight = 120,
		description = 'Painting F',
	},

	['burgershot_bagbig'] = {
		label = 'Big Size Package',
		weight = 100,
		stack = false,
		description = '1x Big King, 1x Big Size Cola, 1x Big Size Patato',
	},

	['burgershot_bigking'] = {
		label = 'Big King Burger',
		weight = 100,
		stack = false,
		description = 'Big King',
	},

	['burgershot_colab'] = {
		label = 'Big Size Cola',
		weight = 100,
		stack = false,
		description = 'Big Size Cola',
	},

	['burgershot_patatob'] = {
		label = 'Big Size Patato',
		weight = 100,
		stack = false,
		description = 'Big Size Patato',
	},

	['burgershot_bagsmall'] = {
		label = 'Small Size Package',
		weight = 100,
		stack = false,
		description = '1x Bleeder Burger, 1x Small Size Cola, 1x Small Size Patato',
	},

	['burgershot_bleeder'] = {
		label = 'Bleeder Burger',
		weight = 100,
		stack = false,
		description = 'Bleeder Burger',
	},

	['burgershot_colas'] = {
		label = 'Small Size Cola',
		weight = 100,
		stack = false,
		description = 'Small Size Cola',
	},

	['vpn'] = {
		label = 'VPN',
		weight = 500,
		stack = false,
		description = 'What are you gonna do with that?',
	},

	['burgershot_patatos'] = {
		label = 'Small Size Patato',
		weight = 100,
		stack = false,
		description = 'Small Size Patato',
	},

	['burgershot_baggoat'] = {
		label = 'Goat Menu Package',
		weight = 100,
		stack = false,
		description = '1x Goat Wrap, 1x Big Size Cola, 1x Shot Nuggets, 1x Shot Rings',
	},

	['burgershot_goatwrap'] = {
		label = 'Goat Wrap',
		weight = 100,
		stack = false,
		description = 'Goat Wrap',
	},

	['burgershot_shotnuggets'] = {
		label = 'Shot Nuggets',
		weight = 100,
		stack = false,
		description = 'Shot Nuggets',
	},

	['burgershot_shotrings'] = {
		label = 'Shot Rings',
		weight = 100,
		stack = false,
		description = 'Shot Rings',
	},

	['burgershot_bagcoffe'] = {
		label = 'Coffee Package',
		weight = 100,
		stack = false,
		description = '1x Coffee, 1x Macaroon',
	},

	['burgershot_coffee'] = {
		label = 'Burger Shot Coffee',
		weight = 100,
		stack = false,
		description = 'Burger Shot Coffee',
	},

	['burgershot_macaroon'] = {
		label = 'Macaroon',
		weight = 100,
		stack = false,
		description = 'Macaroon',
	},

	['burgershot_toy1'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_toy2'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_toy3'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_toy4'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_toy5'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_toy6'] = {
		label = 'Burger Shot Toy',
		weight = 100,
		stack = false,
		description = 'Burger Shot Toy',
	},

	['burgershot_tomato'] = {
		label = 'Tomato',
		weight = 100,
		stack = false,
		description = 'Tomato',
	},

	['burgershot_cheddar'] = {
		label = 'Cheddar',
		weight = 100,
		stack = false,
		description = 'Cheddar',
	},

	['burgershot_curly'] = {
		label = 'Curly',
		weight = 100,
		stack = false,
		description = 'Curly',
	},

	['burgershot_sauce'] = {
		label = 'Sauce',
		weight = 100,
		stack = false,
		description = 'Sauce',
	},

	['burgershot_bread'] = {
		label = 'Bread',
		weight = 100,
		stack = false,
		description = 'Bread',
	},

	['burgershot_lavash'] = {
		label = 'Lavash',
		weight = 100,
		stack = false,
		description = 'Lavash',
	},

	['burgershot_bigcardboard'] = {
		label = 'Big Size Cardboard',
		weight = 100,
		stack = false,
		description = 'Big Size Cardboard',
	},

	['burgershot_smallcardboard'] = {
		label = 'Small Size Cardboard',
		weight = 100,
		stack = false,
		description = 'Small Size Cardboard',
	},

	['burgershot_smallemptyglass'] = {
		label = 'Small Size Empty Glass',
		weight = 100,
		stack = false,
		description = 'Small Size Empty Glass',
	},

	['burgershot_bigemptyglass'] = {
		label = 'Big Size Empty Glass',
		weight = 100,
		stack = false,
		description = 'Big Size Empty Glass',
	},

	['burgershot_coffeeemptyglass'] = {
		label = 'Coffee Empty Glass',
		weight = 100,
		stack = false,
		description = 'Coffee Empty Glass',
	},

	['burgershot_frozenmeat'] = {
		label = 'Frozen Meat',
		weight = 100,
		stack = false,
		description = 'Frozen Meat',
	},

	['burgershot_frozenrings'] = {
		label = 'Frozen Rings',
		weight = 100,
		stack = false,
		description = 'Frozen Rings',
	},

	['burgershot_frozennuggets'] = {
		label = 'Frozen Nuggets',
		weight = 100,
		stack = false,
		description = 'Frozen Nuggets',
	},

	['burgershot_smallfrozenpotato'] = {
		label = 'Small Size Frozen Potato',
		weight = 100,
		stack = false,
		description = 'Small Size Frozen Potato',
	},

	['burgershot_bigfrozenpotato'] = {
		label = 'Big Size Frozen Potato',
		weight = 100,
		stack = false,
		description = 'Big Size Frozen Potato',
	},

	['burgershot_meat'] = {
		label = 'Meat',
		weight = 100,
		stack = false,
		description = 'Meat',
	},

	['burgershot_thesmurfsicecream'] = {
		label = 'The Smurfs Ice Cream',
		weight = 100,
		stack = false,
		description = 'The Smurfs Ice Cream',
	},

	['burgershot_smurfetteicecream'] = {
		label = 'Smurfette Ice Cream',
		weight = 100,
		stack = false,
		description = 'Smurfette Ice Cream',
	},

	['burgershot_matchaicecream'] = {
		label = 'Matcha Ice Cream',
		weight = 100,
		stack = false,
		description = 'Matcha Ice Cream',
	},

	['burgershot_ubeicecream'] = {
		label = 'Ube Ice Cream',
		weight = 100,
		stack = false,
		description = 'Ube Ice Cream',
	},

	['burgershot_unicornicecream'] = {
		label = 'Unicorn Ice Cream',
		weight = 100,
		stack = false,
		description = 'Unicorn Ice Cream',
	},

	['burgershot_vanillaicecream'] = {
		label = 'Vanilla Ice Cream',
		weight = 100,
		stack = false,
		description = 'Vanilla Ice Cream',
	},

	['burgershot_chocolateicecream'] = {
		label = 'Chocolate Ice Cream',
		weight = 100,
		stack = false,
		description = 'Chocolate Ice Cream',
	},

	['burgershot_strawberryicecream'] = {
		label = 'Strawberry Ice Cream',
		weight = 100,
		stack = false,
		description = 'Strawberry Ice Cream',
	},

	['burgershot_icecreamcone'] = {
		label = 'Empty Cone',
		weight = 100,
		stack = false,
		description = 'Cone',
	},

	['cctv_tablet'] = {
		label = 'CCTV Tablet',
		weight = 100,
		stack = false,
		description = 'Tablet where we can see things ahaha',
	},

	['car_wheel'] = {
		label = 'Car Wheel',
		weight = 10000,
	},

	['car_door'] = {
		label = 'Car Door',
		weight = 10000,
	},

	['radiator'] = {
		label = 'Car Radiator',
		weight = 10000,
		stack = false,
		client = {
			image = 'car_radiator.png'
		},
	},

	['trunk'] = {
		label = 'Car Trunk',
		weight = 10000,
		stack = false,
		client = {
			image = 'car_trunk.png'
		},
	},

	['rfid_disruptor'] = {
		label = 'RFID Disruptor',
		weight = 1000,
		close = false,
		description = 'A Disruptor used for ATM firewalls',
	},

	['potato'] = {
		label = 'Potato',
		weight = 350,
		description = 'Po-ta-to',
	},

	['dirty_potato'] = {
		label = 'Dirty Potato',
		weight = 350,
		description = 'Po-ta-to',
	},

	['tomato'] = {
		label = 'Tomato',
		weight = 350,
		description = 'To-ma-to',
	},

	['dirty_tomato'] = {
		label = 'Dirty Tomato',
		weight = 350,
		description = 'To-ma-to',
	},

	['coffee_beans'] = {
		label = 'Coffee Beans',
		weight = 350,
		description = 'Wakey wakey!',
	},

	['dirty_coffee_beans'] = {
		label = 'Dirty Coffee Beans',
		weight = 350,
		description = 'Wakey wakey!',
	},

	['cabbage'] = {
		label = 'Cabbage',
		weight = 350,
		description = 'Let-tuce? No!',
	},

	['dirty_cabbage'] = {
		label = 'Dirty Cabbage',
		weight = 350,
		description = 'Let-tuce? No!',
	},

	['orange'] = {
		label = 'Orange',
		weight = 1000,
		description = 'an ingredient!',
	},

	['dirty_orange'] = {
		label = 'Dirty Orange',
		weight = 350,
		description = 'The talking orange!',
		client = { image = 'orange.png' },
	},

	['trowel'] = {
		label = 'Trowel',
		weight = 350,
		description = 'Mini-shovel yes',
	},

	['shovel'] = {
		label = 'Shovel',
		weight = 350,
		description = 'Legit shovel yes',
	},

	['wallet'] = {
		label = 'Wallet',
		weight = 350,
		description = 'Dont Leave it ANYWHERE!',
	},

	['delivery_food'] = {
		label = 'Delivery Food',
		weight = 300,
		stack = false,
		description = 'Grab food!?',
		client = {
			image = 'burgershot_bagbig.png'
		},
	},

	['bands'] = {
		label = 'Band Of Notes',
		weight = 100,
		close = false,
		description = 'A band of small notes..',
		client = {
			image = 'cashstack.png'
		},
	},

	['rolls'] = {
		label = 'Roll Of Small Notes',
		weight = 100,
		close = false,
		description = 'A roll of small notes..',
		client = {
			image = 'cashroll.png'
		},
	},

	['package'] = {
		label = 'Suspicious Package',
		weight = 10000,
		stack = false,
		close = false,
		description = 'A mysterious package.. Scary!',
	},

	['weedbud'] = {
		label = 'Weed Bud',
		weight = 200,
		close = false,
		description = 'A small 2g weed bud..',
	},

	['weedpackage'] = {
		label = 'Weed Package',
		weight = 15000,
		stack = false,
		close = false,
		description = 'A large & hastly sealed package with a herbal aroma',
	},

	['sealedpackage'] = {
		label = 'Sealed Package',
		weight = 15000,
		stack = false,
		close = false,
		description = 'A heavy water-sealed package',
	},

	['stone'] = {
		label = 'Stone',
		weight = 2000,
		close = false,
		description = 'Stone woo',
	},

	['uncut_emerald'] = {
		label = 'Uncut Emerald',
		weight = 100,
		close = false,
		description = 'A rough Emerald',
	},

	['uncut_ruby'] = {
		label = 'Uncut Ruby',
		weight = 100,
		close = false,
		description = 'A rough Ruby',
	},

	['uncut_diamond'] = {
		label = 'Uncut Diamond',
		weight = 100,
		close = false,
		description = 'A rough Diamond',
	},

	['uncut_sapphire'] = {
		label = 'Uncut Sapphire',
		weight = 100,
		close = false,
		description = 'A rough Sapphire',
	},

	['emerald'] = {
		label = 'Emerald',
		weight = 100,
		close = false,
		description = 'A Emerald that shimmers',
	},

	['ruby'] = {
		label = 'Ruby',
		weight = 100,
		close = false,
		description = 'A Ruby that shimmers',
	},

	['sapphire'] = {
		label = 'Sapphire',
		weight = 100,
		close = false,
		description = 'A Sapphire that shimmers',
	},

	['gold_ring'] = {
		label = 'Gold Ring',
		weight = 200,
		close = false,
	},

	['ruby_ring'] = {
		label = 'Ruby Ring',
		weight = 200,
		close = false,
	},

	['sapphire_ring'] = {
		label = 'Sapphire Ring',
		weight = 200,
		close = false,
	},

	['emerald_ring'] = {
		label = 'Emerald Ring',
		weight = 200,
		close = false,
	},

	['silver_ring'] = {
		label = 'Silver Ring',
		weight = 200,
		close = false,
	},

	['diamond_ring_silver'] = {
		label = 'Diamond Ring Silver',
		weight = 200,
		close = false,
	},

	['ruby_ring_silver'] = {
		label = 'Ruby Ring Silver',
		weight = 200,
		close = false,
	},

	['sapphire_ring_silver'] = {
		label = 'Sapphire Ring Silver',
		weight = 200,
		close = false,
	},

	['emerald_ring_silver'] = {
		label = 'Emerald Ring Silver',
		weight = 200,
		close = false,
	},

	['diamond_necklace'] = {
		label = 'Diamond Necklace',
		weight = 200,
		close = false,
	},

	['ruby_necklace'] = {
		label = 'Ruby Necklace',
		weight = 200,
		close = false,
	},

	['sapphire_necklace'] = {
		label = 'Sapphire Necklace',
		weight = 200,
		close = false,
	},

	['emerald_necklace'] = {
		label = 'Emerald Necklace',
		weight = 200,
		close = false,
	},

	['silverchain'] = {
		label = 'Silver Chain',
		weight = 200,
		close = false,
	},

	['diamond_necklace_silver'] = {
		label = 'Diamond Necklace Silver',
		weight = 200,
		close = false,
	},

	['ruby_necklace_silver'] = {
		label = 'Ruby Necklace Silver',
		weight = 200,
		close = false,
	},

	['sapphire_necklace_silver'] = {
		label = 'Sapphire Necklace Silver',
		weight = 200,
		close = false,
	},

	['emerald_necklace_silver'] = {
		label = 'Emerald Necklace Silver',
		weight = 200,
		close = false,
	},

	['goldearring'] = {
		label = 'Golden Earrings',
		weight = 200,
		close = false,
		client = {
			image = 'gold_earring.png'
		},
	},

	['diamond_earring'] = {
		label = 'Diamond Earrings',
		weight = 200,
		close = false,
	},

	['ruby_earring'] = {
		label = 'Ruby Earrings',
		weight = 200,
		close = false,
	},

	['sapphire_earring'] = {
		label = 'Sapphire Earrings',
		weight = 200,
		close = false,
	},

	['emerald_earring'] = {
		label = 'Emerald Earrings',
		weight = 200,
		close = false,
	},

	['silverearring'] = {
		label = 'Silver Earrings',
		weight = 200,
		close = false,
		client = {
			image = 'silver_earring.png'
		},
	},

	['diamond_earring_silver'] = {
		label = 'Diamond Earrings Silver',
		weight = 200,
		close = false,
	},

	['ruby_earring_silver'] = {
		label = 'Ruby Earrings Silver',
		weight = 200,
		close = false,
	},

	['sapphire_earring_silver'] = {
		label = 'Sapphire Earrings Silver',
		weight = 200,
		close = false,
	},

	['emerald_earring_silver'] = {
		label = 'Emerald Earrings Silver',
		weight = 200,
		close = false,
	},

	['carbon'] = {
		label = 'Carbon',
		weight = 1000,
		close = false,
		description = 'Carbon, a base ore.',
	},

	['ironore'] = {
		label = 'Iron Ore',
		weight = 1000,
		close = false,
		description = 'Iron, a base ore.',
	},

	['copperore'] = {
		label = 'Copper Ore',
		weight = 1000,
		close = false,
		description = 'Copper, a base ore.',
	},

	['goldore'] = {
		label = 'Gold Ore',
		weight = 1000,
		close = false,
		description = 'Gold Ore',
	},

	['silverore'] = {
		label = 'Silver Ore',
		weight = 1000,
		close = false,
		description = 'Silver Ore',
	},

	['goldingot'] = {
		label = 'Gold Ingot',
		weight = 1000,
		close = false,
	},

	['silveringot'] = {
		label = 'Silver Ingot',
		weight = 1000,
		close = false,
	},

	['pickaxe'] = {
		label = 'Pickaxe',
		weight = 1000,
		close = false,
	},

	['miningdrill'] = {
		label = 'Mining Drill',
		weight = 1000,
		close = false,
	},

	['mininglaser'] = {
		label = 'Mining Laser',
		weight = 900,
		close = false,
	},

	['drillbit'] = {
		label = 'Drill Bit',
		weight = 10,
		close = false,
	},

	['goldpan'] = {
		label = 'Gold Panning Tray',
		weight = 10,
		close = false,
	},

	['bottle'] = {
		label = 'Empty Bottle',
		weight = 10,
		close = false,
		description = 'A glass bottle',
	},

	['can'] = {
		label = 'Empty Can',
		weight = 10,
		close = false,
		description = 'An empty can, good for recycling',
	},

	['recyclablematerial'] = {
		label = 'Recycle Box',
		weight = 100,
		close = false,
		description = 'A box of Recyclable Materials',
	},

	['skateboard'] = {
		label = 'Skateboard',
		weight = 1,
		stack = false,
		description = 'a jimnastic board',
	},

	['notepad'] = {
		label = 'Notepad',
		weight = 100,
		stack = false,
	},

	['mechanic_tools'] = {
		label = 'Mechanic tools',
		weight = 0,
		stack = false,
		description = 'Needed for vehicle repairs',
	},

	['toolbox'] = {
		label = 'Toolbox',
		weight = 0,
		stack = false,
		description = 'Needed for Performance part removal',
	},

	['ducttape'] = {
		label = 'Duct Tape',
		weight = 0,
		stack = false,
		description = 'Good for quick fixes',
		client = {
			image = 'bodyrepair.png'
		},
	},

	['mechboard'] = {
		label = 'Mechanic Sheet',
		weight = 0,
		stack = false,
	},

	['turbo'] = {
		label = 'Supercharger Turbo',
		weight = 0,
		stack = false,
		description = 'Who doesn\'t need a 65mm Turbo??',
	},

	['car_armor'] = {
		label = 'Vehicle Armor',
		weight = 0,
		stack = false,
		client = {
			image = 'armour.png'
		},
	},

	['nos'] = {
		label = 'NOS Bottle',
		weight = 0,
		stack = false,
		description = 'A full bottle of NOS',
	},

	['noscan'] = {
		label = 'Empty NOS Bottle',
		weight = 0,
		description = 'An Empty bottle of NOS',
	},

	['noscolour'] = {
		label = 'NOS Colour Injector',
		weight = 0,
		description = 'Make that purge spray',
	},

	['engine1'] = {
		label = 'Tier 1 Engine',
		weight = 0,
		stack = false,
	},

	['engine2'] = {
		label = 'Tier 2 Engine',
		weight = 0,
		stack = false,
	},

	['engine3'] = {
		label = 'Tier 3 Engine',
		weight = 0,
		stack = false,
	},

	['engine4'] = {
		label = 'Tier 4 Engine',
		weight = 0,
		stack = false,
	},

	['engine5'] = {
		label = 'Tier 5 Engine',
		weight = 0,
		stack = false,
	},

	['transmission1'] = {
		label = 'Tier 1 Transmission',
		weight = 0,
		stack = false,
	},

	['transmission2'] = {
		label = 'Tier 2 Transmission',
		weight = 0,
		stack = false,
	},

	['transmission3'] = {
		label = 'Tier 3 Transmission',
		weight = 0,
		stack = false,
	},

	['transmission4'] = {
		label = 'Tier 4 Transmission',
		weight = 0,
		stack = false,
	},

	['brakes1'] = {
		label = 'Tier 1 Brakes',
		weight = 0,
		stack = false,
	},

	['brakes2'] = {
		label = 'Tier 2 Brakes',
		weight = 0,
		stack = false,
	},

	['brakes3'] = {
		label = 'Tier 3 Brakes',
		weight = 0,
		stack = false,
	},

	['suspension1'] = {
		label = 'Tier 1 Suspension',
		weight = 0,
		stack = false,
	},

	['suspension2'] = {
		label = 'Tier 2 Suspension',
		weight = 0,
		stack = false,
	},

	['suspension3'] = {
		label = 'Tier 3 Suspension',
		weight = 0,
		stack = false,
	},

	['suspension4'] = {
		label = 'Tier 4 Suspension',
		weight = 0,
		stack = false,
	},

	['suspension5'] = {
		label = 'Tier 5 Suspension',
		weight = 0,
		stack = false,
	},

	['bprooftires'] = {
		label = 'Bulletproof Tires',
		weight = 0,
		stack = false,
	},

	['drifttires'] = {
		label = 'Drift Tires',
		weight = 0,
		stack = false,
	},

	['underglow_controller'] = {
		label = 'Neon Controller',
		weight = 0,
		description = 'RGB LED Vehicle Remote',
	},

	['headlights'] = {
		label = 'Xenon Headlights',
		weight = 0,
		stack = false,
		description = '8k HID headlights',
	},

	['tint_supplies'] = {
		label = 'Tint Supplies',
		weight = 0,
		description = 'Supplies for window tinting',
	},

	['customplate'] = {
		label = 'Customized Plates',
		weight = 0,
		stack = false,
		client = {
			image = 'plate.png'
		},
	},

	['hood'] = {
		label = 'Vehicle Hood',
		weight = 0,
		stack = false,
	},

	['roof'] = {
		label = 'Vehicle Roof',
		weight = 0,
		stack = false,
	},

	['spoiler'] = {
		label = 'Vehicle Spoiler',
		weight = 0,
		stack = false,
	},

	['bumper'] = {
		label = 'Vehicle Bumper',
		weight = 0,
		stack = false,
	},

	['skirts'] = {
		label = 'Vehicle Skirts',
		weight = 0,
		stack = false,
	},

	['exhaust'] = {
		label = 'Vehicle Exhaust',
		weight = 0,
		stack = false,
	},

	['seat'] = {
		label = 'Seat Cosmetics',
		weight = 0,
		stack = false,
	},

	['rollcage'] = {
		label = 'Roll Cage',
		weight = 0,
		stack = false,
	},

	['rims'] = {
		label = 'Custom Wheel Rims',
		weight = 0,
		stack = false,
	},

	['livery'] = {
		label = 'Livery Roll',
		weight = 0,
		stack = false,
	},

	['paintcan'] = {
		label = 'Vehicle Spray Can',
		weight = 0,
		stack = false,
		client = {
			image = 'spraycan.png'
		},
	},

	['tires'] = {
		label = 'Drift Smoke Tires',
		weight = 0,
		stack = false,
	},

	['horn'] = {
		label = 'Custom Vehicle Horn',
		weight = 0,
		stack = false,
	},

	['internals'] = {
		label = 'Internal Cosmetics',
		weight = 0,
		stack = false,
	},

	['externals'] = {
		label = 'Exterior Cosmetics',
		weight = 0,
		stack = false,
		client = {
			image = 'mirror.png'
		},
	},

	['newoil'] = {
		label = 'Car Oil',
		weight = 0,
		close = false,
		client = {
			image = 'caroil.png'
		},
	},

	['sparkplugs'] = {
		label = 'Spark Plugs',
		weight = 0,
		close = false,
	},

	['carbattery'] = {
		label = 'Car Battery',
		weight = 0,
		close = false,
	},

	['axleparts'] = {
		label = 'Axle Parts',
		weight = 0,
		close = false,
	},

	['sparetire'] = {
		label = 'Spare Tire',
		weight = 0,
		stack = false,
		close = false,
	},

	['cleanershovel'] = {
		label = 'Mini Shovel',
		weight = 2000,
		stack = false,
	},

	['eblower'] = {
		label = 'Electric Blower',
		weight = 2000,
		stack = false,
	},

	['casino_goldchip'] = {
		label = 'Casino Chip',
		weight = 0,
		close = false,
		description = 'Diamond Casino Chip',
	},

	['casino_member'] = {
		label = 'Casino Membership',
		weight = 500,
		stack = false,
		close = false,
		description = 'Diamond Casino Member Card',
	},

	['casino_vip'] = {
		label = 'V.I.P Membership',
		weight = 500,
		stack = false,
		close = false,
		description = 'Diamond Casino V.I.P Card',
	},

	['pancakesbb'] = {
		label = 'Blueberry Pancakes',
		weight = 10,
		description = 'Yum.',
	},

	['pancakesmaple'] = {
		label = 'Syrup Pancakes',
		weight = 10,
		description = 'Yum.',
	},

	['pancakemix'] = {
		label = 'Pancake Mix',
		weight = 10,
		description = 'Pancake mix.',
	},

	['blueberries'] = {
		label = 'Blueberries',
		weight = 10,
		description = 'Blueberries.',
	},

	['maplesyrup'] = {
		label = 'Maple Syrup',
		weight = 10,
		description = 'Maple Syrup.',
	},

	['baconegg'] = {
		label = 'B.E Muffin',
		weight = 10,
		description = 'Like McDonalds but better.',
	},

	['lteggs'] = {
		label = 'LT Eggs',
		weight = 10,
		description = '.',
	},

	['ltcheese'] = {
		label = 'LT Cheese',
		weight = 10,
		description = '.',
	},

	['ltmuffin'] = {
		label = 'Muffin Bun',
		weight = 10,
		description = '.',
	},

	['ltbacon'] = {
		label = 'Bacon',
		weight = 10,
		description = '.',
	},

	['teapotorange'] = {
		label = 'Orange Juice',
		weight = 10,
		description = '.',
	},

	['oranges'] = {
		label = 'Oranges',
		weight = 10,
		description = '.',
	},

	['teapotcoffee'] = {
		label = 'Cup of Coffee',
		weight = 10,
		description = '.',
	},

	['ltbox'] = {
		label = 'LT Ingredients',
		weight = 10,
		stack = false,
		description = '.',
	},

	['coffeebeans'] = {
		label = 'Coffee Beans',
		weight = 10,
		description = '.',
	},

	['ltbuns'] = {
		label = 'Breakfast Buns',
		weight = 10,
		description = '.',
	},

	['ltlettuce'] = {
		label = 'Lettuce',
		weight = 10,
		description = '.',
	},

	['lttomato'] = {
		label = 'Tomato',
		weight = 10,
		description = '.',
	},

	['bltsandwich'] = {
		label = 'BLT Sandwich',
		weight = 10,
		description = '.',
	},

	['ltteabags'] = {
		label = 'Tea Bags',
		weight = 10,
		description = '.',
	},

	['teapottea'] = {
		label = 'Cup of Tea',
		weight = 10,
		description = '.',
	},

	['ltcookies'] = {
		label = 'Cookie',
		weight = 10,
		description = 'Cookies',
	},

	['ltdonut'] = {
		label = 'Donut',
		weight = 10,
		description = 'Donut',
	},

	['ltcroissant'] = {
		label = 'Croissant',
		weight = 10,
		description = 'Croissant',
	},

	['smoothieor'] = {
		label = 'Orange Smoothie',
		weight = 10,
		description = 'Orange Smoothie',
	},

	['smoothiera'] = {
		label = 'Raspberry Smoothie',
		weight = 10,
		description = 'Raspberry Smoothie',
	},

	['ltraspberry'] = {
		label = 'Raspberries',
		weight = 10,
		description = 'Raspberries',
	},

	['smoothiest'] = {
		label = 'Strawberry Smoothie',
		weight = 10,
		description = 'Strawberry Smoothie',
	},

	['ltstrawberry'] = {
		label = 'Strawberries',
		weight = 10,
		description = 'Strawberries',
	},

	['smoothiema'] = {
		label = 'Mango Smoothie',
		weight = 10,
		description = 'Mango Smoothie',
	},

	['ltmango'] = {
		label = 'Mango',
		weight = 10,
		description = 'Mango',
	},

	['pacote-leite'] = {
		label = 'Milk Pack',
		weight = 1500,
		client = {
			image = 'leite.png'
		},
	},

	['barra-manteiga'] = {
		label = 'Butter Bar',
		weight = 1500,
		client = {
			image = 'manteiga.png'
		},
	},

	['pacote-farinha'] = {
		label = 'Flour Package',
		weight = 1500,
		client = {
			image = 'farinha.png'
		},
	},

	['barra-chocolate'] = {
		label = 'Chocolate Bar',
		weight = 1500,
		client = {
			image = 'chocolate.png'
		},
	},

	['caixa-morangos'] = {
		label = 'Strawberries Box',
		weight = 1500,
		client = {
			image = 'morangos.png'
		},
	},

	['limao'] = {
		label = 'Lemon',
		weight = 1500,
	},

	['pacote-natas'] = {
		label = 'Package of Cream',
		weight = 1500,
		client = {
			image = 'natas.png'
		},
	},

	['leite-condensado'] = {
		label = 'Condensed Milk',
		weight = 1500,
		client = {
			image = 'condensado.png'
		},
	},

	['extrato-baunilha'] = {
		label = 'Vanilla Extract',
		weight = 1500,
		client = {
			image = 'baunilha.png'
		},
	},

	['pacote-acucar'] = {
		label = 'Sugar Pack',
		weight = 1500,
		client = {
			image = 'acucar.png'
		},
	},

	['frasco-nutela'] = {
		label = 'Jar of Nutella',
		weight = 1500,
		client = {
			image = 'nutela.png'
		},
	},

	['pacote-oreo'] = {
		label = 'Oreo Pack',
		weight = 1500,
		client = {
			image = 'oreo.png'
		},
	},

	['extrato-menta'] = {
		label = 'Mint Extract',
		weight = 1500,
		client = {
			image = 'menta.png'
		},
	},

	['caixa-amoras'] = {
		label = 'Box of Blackberries',
		weight = 1500,
		client = {
			image = 'amoras.png'
		},
	},

	['graos-cafe'] = {
		label = 'Coffee Beans',
		weight = 1500,
		client = {
			image = 'graoscafe.png'
		},
	},

	['frango'] = {
		label = 'Chicken',
		weight = 1500,
	},

	['cupcake-morango'] = {
		label = 'Strawberry Cupcake',
		weight = 1000,
		client = {
			image = 'cupmorango.png'
		},
	},

	['cupcake-chocolate'] = {
		label = 'Chocolate Cupcake',
		weight = 1000,
		client = {
			image = 'cupchocolate.png'
		},
	},

	['cupcake-limao'] = {
		label = 'Lemon Cupcake',
		weight = 1000,
		client = {
			image = 'cuplimao.png'
		},
	},

	['gelado-morango'] = {
		label = 'Strawberry Icecream',
		weight = 1000,
		client = {
			image = 'gemorango.png'
		},
	},

	['gelado-chocolate'] = {
		label = 'Chocolate Icecream',
		weight = 1000,
		client = {
			image = 'gechocolate.png'
		},
	},

	['gelado-baunilha'] = {
		label = 'Vanilla Icecream',
		weight = 1000,
		client = {
			image = 'gemorango.png'
		},
	},

	['panqueca-nutela'] = {
		label = 'Nutella Pancake',
		weight = 1000,
		client = {
			image = 'panutela.png'
		},
	},

	['panqueca-oreo'] = {
		label = 'Oreo Pancake',
		weight = 1000,
		client = {
			image = 'paoreo.png'
		},
	},

	['waffle-nutela'] = {
		label = 'Nutela Waffle',
		weight = 1000,
		client = {
			image = 'wnutela.png'
		},
	},

	['pastel-frango'] = {
		label = 'Chicken Pastel',
		weight = 1000,
		client = {
			image = 'pfrango.png'
		},
	},

	['muffin-chocolate'] = {
		label = 'Chocolate Muffin',
		weight = 1000,
		client = {
			image = 'mufchocolate.png'
		},
	},

	['cafe-uwu'] = {
		label = 'Café',
		weight = 1000,
		client = {
			image = 'cafe.png'
		},
	},

	['latte-uwu'] = {
		label = 'Latte',
		weight = 1000,
		client = {
			image = 'latte.png'
		},
	},

	['bubble-amora'] = {
		label = 'Blackberry Bubble Tea',
		weight = 1000,
		client = {
			image = 'btamora.png'
		},
	},

	['bubble-menta'] = {
		label = 'Mint Bubble Team',
		weight = 1000,
		client = {
			image = 'btmenta.png'
		},
	},

	['bubble-morango'] = {
		label = 'Strawberry Bubble Tea',
		weight = 1000,
		client = {
			image = 'btmorango.png'
		},
	},

	['milkshake-morango'] = {
		label = 'Strawberry Milkshake',
		weight = 1000,
		client = {
			image = 'msmorango.png'
		},
	},

	['milkshake-chocolate'] = {
		label = 'Chocolate Milkshake',
		weight = 1000,
		client = {
			image = 'mschocolate.png'
		},
	},

	['vehicletracker'] = {
		label = 'Vehicle GPS Tracker',
		weight = 1000,
		stack = false,
		description = 'A device placed to track a vehicle\'s location.',
	},

	['vehicletrackertablet'] = {
		label = 'Vehicle Tracker Tablet',
		weight = 1000,
		stack = false,
		description = 'Connects to a vehicle tracker to show it\'s location.',
	},

	['vehicletrackerscanner'] = {
		label = 'Vehicle Tracker Scanner',
		weight = 1000,
		stack = false,
		description = 'Scans a vehicle for existence of GPS tracker.',
	},

	['cash_bag'] = {
		label = 'Gruppe 6 Cash Bag',
		weight = 1000,
		close = false,
		description = 'Bag full of un-inked cash',
		client = { image = 'moneybag.png' },
	},

	['inked_cash_bag'] = {
		label = 'Gruppe 6 Inked Cash Bag',
		weight = 1000,
		close = false,
		description = 'Bag full of useless inked cash.',
		-- Same bag as cash_bag on purpose. Inked money is only distinguishable
		-- once it is out of the bag, so two different bags would be telling the
		-- player something the character cannot see.
		client = { image = 'moneybag.png' },
	},

	['limeysdonut'] = {
		label = 'Strawberry Donut',
		weight = 200,
		description = 'Strawberry Donut!',
		client = {
			image = 'limeysdonut2.png'
		},
	},

	['limeysdonut2'] = {
		label = 'Chocolate Donut',
		weight = 200,
		description = 'Chocolate Donut!',
	},

	['limeysgum'] = {
		label = 'Trident Gum',
		weight = 100,
		description = 'Chewy! Minty! Fresh!',
	},

	['limeyschocolate'] = {
		label = 'Nestle Extrafino Chocolate',
		weight = 100,
		description = 'Mmmmmm Chocolate!',
	},

	['limeyschocolate2'] = {
		label = 'Cadbury Dairy Milk Chocolate',
		weight = 100,
		description = 'Cadbury Chocolate!',
	},

	['cherrydrink'] = {
		label = 'Cherry Drink',
		weight = 1000,
		description = 'Cherries!',
	},

	['lemondrink'] = {
		label = 'Lemon Drink',
		weight = 1000,
		description = 'Rip-off Lemonade',
	},

	['limedrink'] = {
		label = 'Lime Drink',
		weight = 1000,
		description = 'Limes...',
	},

	['orangedrink'] = {
		label = 'Orange Drink',
		weight = 1000,
		description = 'A fancy orange juice...',
	},

	['watermelondrink'] = {
		label = 'Watermelon Drink',
		weight = 1000,
		description = 'Watermelon Drink.',
	},

	['paradisecocktail'] = {
		label = 'Paradise Cocktail',
		weight = 1000,
		description = 'Living in paradise!',
	},

	['cherrycocktail'] = {
		label = 'Cherry Cocktail',
		weight = 1000,
		description = 'Cherries.. But with whiskey',
	},

	['applecocktail'] = {
		label = 'Apple Cocktail',
		weight = 1000,
		description = 'Rumor has it that Issac Newton made this.',
	},

	['bananacocktail'] = {
		label = 'Banana Cocktail',
		weight = 1000,
		description = 'The Minions made this.',
	},

	['kiwicocktail'] = {
		label = 'Kiwi Cocktail',
		weight = 1000,
		description = 'Kiwi.',
	},

	['drink-glass'] = {
		label = 'Glass',
		weight = 1000,
		description = 'Glass made for normal drinks',
	},

	['cocktailglass'] = {
		label = 'Cocktail Glass',
		weight = 1000,
		description = 'Glass made for cocktails!',
	},

	['apple'] = {
		label = 'Apple',
		weight = 1000,
		description = 'an ingredient!',
	},

	['banana'] = {
		label = 'Banana',
		weight = 1000,
		description = 'an ingredient!',
	},

	['cherry'] = {
		label = 'Cherry',
		weight = 1000,
		description = 'an ingredient!',
	},

	['kiwi'] = {
		label = 'Kiwi',
		weight = 1000,
		description = 'an ingredient!',
	},

	['lemon'] = {
		label = 'Lemon',
		weight = 1000,
		description = 'an ingredient!',
	},

	['lime'] = {
		label = 'Lime',
		weight = 1000,
		description = 'an ingredient!',
	},

	['watermelon'] = {
		label = 'Watermelon',
		weight = 1000,
		description = 'a sliceable watermelon!',
	},

	['watermelonslice'] = {
		label = 'Watermelon Slice',
		weight = 200,
		description = 'an ingredient!',
	},

	['stingray'] = {
		label = 'Stingray',
		weight = 2500,
		stack = false,
		close = false,
		description = 'Stingray',
	},

	['flounder'] = {
		label = 'Flounder',
		weight = 2500,
		stack = false,
		close = false,
		description = 'Flounder',
	},

	['codfish'] = {
		label = 'Cod',
		weight = 2500,
		stack = false,
		close = false,
		description = 'Cod',
	},

	['mackerel'] = {
		label = 'Mackerel',
		weight = 2500,
		stack = false,
		close = false,
		description = 'Mackerel',
	},

	['bass'] = {
		label = 'Bass',
		weight = 1250,
		stack = false,
		close = false,
		description = 'A normal fish Tatses pretty good!',
	},

	['fishingtin'] = {
		label = 'Fishing Tin',
		weight = 2500,
		close = false,
		description = 'Fishing Tin',
	},

	['fishingboot'] = {
		label = 'Fishing Boot',
		weight = 2500,
		close = false,
		description = 'Fishing Boot',
	},

	['killerwhale'] = {
		label = 'Whale',
		weight = 15000,
		stack = false,
		close = false,
		description = 'Killer Whale',
	},

	['dolphin'] = {
		label = 'Dolphin',
		weight = 5000,
		stack = false,
		close = false,
		description = 'Dolphin',
	},

	['sharkhammer'] = {
		label = 'Shark',
		weight = 5000,
		stack = false,
		close = false,
		description = 'Hammerhead Shark',
	},

	['sharktiger'] = {
		label = 'Shark',
		weight = 5000,
		stack = false,
		close = false,
		description = 'Tigershark',
	},

	['fishbait'] = {
		label = 'Fish Bait',
		weight = 400,
		description = 'Fishing bait',
	},

	['fishingrod'] = {
		label = 'Fishing Rod',
		weight = 750,
		description = 'A fishing rod for adventures with friends!!',
	},

	['anchor'] = {
		label = 'Boat Anchor',
		weight = 2500,
		description = 'Boat Anchor',
	},

	['fishicebox'] = {
		label = 'Fishing Ice Chest',
		weight = 2500,
		stack = false,
		description = 'Ice Box to store all of your fish',
	},

	['fishingloot'] = {
		label = 'Metal Box',
		weight = 500,
		description = 'Seems to be a corroded from the salt water, Should be easy to open',
	},

	['fishinglootbig'] = {
		label = 'Treasure Chest',
		weight = 2500,
		description = 'The lock seems to be intact, Might need a key',
	},

	['fishingkey'] = {
		label = 'Corroded Key',
		weight = 100,
		description = 'A weathered key that looks usefull',
	},

	['fishtacklebox'] = {
		label = 'Tackle Box',
		weight = 1000,
		description = 'Seems to be left over tackle box from another fisherman',
	},

	['pearlscard'] = {
		label = 'Pearls Seafood',
		weight = 100,
		description = 'A special member of Pearl\'s Seafood Restaurant',
	},

	['guide'] = {
		label = 'Server Guide',
		weight = 100,
		description = 'A weathered key that looks usefull',
		client = {
			image = 'np_book.png'
		},
	},

	['police_guide'] = {
		label = 'Police Guide',
		weight = 1000,
		description = 'Seems to be left over',
		client = {
			image = 'np_book.png'
		},
	},

	['bar'] = {
		label = 'News book',
		weight = 100,
		description = 'LOL',
		client = {
			image = 'np_book.png'
		},
	},

	['heist_papers'] = {
		label = 'Vehicle Papers',
		weight = 0,
		stack = false,
		description = 'Delivery documents.',
	},

	['finger_scanner'] = {
		label = 'Finger Scanner',
		weight = 0,
	},

	['shitgpu'] = {
		label = 'A trash gpu',
		weight = 0,
		stack = false,
		description = 'Just look at it, what do you expect!',
	},

	['1050gpu'] = {
		label = 'gtx 1050',
		weight = 0,
		stack = false,
		description = 'It does the job for its price.',
		client = {
			image = '1050.png'
		},
	},

	['1060gpu'] = {
		label = 'gtx 1060',
		weight = 0,
		stack = false,
		description = 'A good upgrade if you are broke.',
		client = {
			image = '1060.png'
		},
	},

	['1080gpu'] = {
		label = 'gtx 1080',
		weight = 0,
		stack = false,
		description = 'It must be good since it got 3 fans right?',
		client = {
			image = '1080.png'
		},
	},

	['2080gpu'] = {
		label = 'RTX 2080',
		weight = 0,
		stack = false,
		description = 'WOOW!! A new look! Then This is the one.',
		client = {
			image = '2080.png'
		},
	},

	['3060gpu'] = {
		label = 'RTX 3060',
		weight = 0,
		stack = false,
		description = 'IDK Man! It\'s so expensive.',
		client = {
			image = '3060.png'
		},
	},

	['4090gpu'] = {
		label = 'RTX 4090',
		weight = 0,
		stack = false,
		description = 'Is it just me or this looks kinda thicc?',
		client = {
			image = '4090.png'
		},
	},

	['thermalpast'] = {
		label = 'Thermal past',
		weight = 0,
		stack = false,
		description = 'A thermalpast To keep your cpu chiling.',
	},

	-- Not in qbx_core's catalog at all; ps-mdt's server/main.lua:1812 calls
	-- exports.ox_inventory:AddItem(..., 'mdtcitation', ...) but nothing ever
	-- defined it. Definition below matches ps-mdt's own README exactly. No
	-- 'citation.png' found in the old qb-inventory image set -- falls back to
	-- ox_inventory's default icon until a real one is added.
	['mdtcitation'] = {
		label = 'Citation',
		weight = 1000,
		stack = false,
		description = 'Citation from a police officer!',
		-- Was pointed at citation.png, which does not exist and never has, so
		-- every citation issued has shown the fallback. heist_papers.png is a
		-- realistic printed form, which is what a citation is.
		client = {
			image = 'heist_papers.png'
		},
	},

	-- ---------------------------------------------------------------------
	-- Placeable scene props. Cones, barriers and worklights an officer puts
	-- down to close a road or light a scene.
	--
	-- Item definitions and icons adapted from Andyyy7666/itemcollection. Its
	-- placement Lua was NOT used: its pickup event trusted a model name sent
	-- by the client and handed out a free item for it, with no distance check
	-- and no proof the entity existed. som-props reimplements both halves with
	-- the server deciding. See som-props/README.md.
	--
	-- `placeable` is read by som-props, not by ox_inventory. Every model is
	-- vanilla GTA, so none of this streams anything.
	--
	-- The `client.anim` is the same clip som-props plays on pickup, so putting
	-- one down and taking it back look like one act.
	-- ---------------------------------------------------------------------
	['prop_cone_small'] = {
		label = 'Traffic Cone',
		weight = 1800,
		description = 'Small traffic cone',
		placeable = { models = { `prop_mp_cone_02`, `prop_mp_cone_03`, `prop_roadcone02a`, `prop_roadcone02b`, `prop_roadcone02c` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_cone_large'] = {
		label = 'Traffic Cone',
		weight = 1800,
		description = 'Large traffic cone',
		placeable = { models = { `prop_mp_cone_01`, `prop_roadcone01a`, `prop_roadcone01b`, `prop_roadcone01c` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_police_barrier'] = {
		label = 'Police Barrier',
		weight = 1800,
		description = 'DO NOT CROSS. POLICE DEPT.',
		placeable = { models = { `prop_barrier_work05` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_barrier_small'] = {
		label = 'Work Barrier',
		weight = 1800,
		description = 'Small work barrier',
		placeable = { models = { `prop_barrier_work01a` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_barrier_medium'] = {
		label = 'Work Barrier',
		weight = 1800,
		description = 'Medium work barrier',
		placeable = { models = { `prop_barrier_work06a` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_barrier_large'] = {
		label = 'Work Barrier',
		weight = 1800,
		description = 'Large work barrier',
		placeable = { models = { `prop_mp_barrier_02b` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_worklight_small'] = {
		label = 'Worklight',
		weight = 1800,
		description = 'Small worklight',
		placeable = { models = { `prop_worklight_02a` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},

	['prop_worklight_large'] = {
		label = 'Worklight',
		weight = 1800,
		description = 'Large worklight',
		placeable = { models = { `prop_worklight_03b` }, avoid = true },
		client = { anim = 'placing', usetime = 900, disable = { move = true, car = true, combat = true }, cancel = true },
		server = { export = 'som-props.use' },
	},
}
