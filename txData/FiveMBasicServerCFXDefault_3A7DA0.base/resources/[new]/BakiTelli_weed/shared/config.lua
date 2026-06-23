	
Config = {}

Config.Inventory = "default" -- ox_inventory, quasar, default, other
Config.MaxWeed = 3 -- How many weeds can be grown at the same time?
Config.Harvest = 0.8 -- Harvest time should give a multiple of the size (for example, a size of 1.2 100% will give 12 weeds for harvest)
Config.Webhook = "https://discord.com/api/webhooks/1246769243689582645/viAXxwUR_Wy7_1QO3RLG1pRP9zdubeeX1bKOhl-E4wAZ8GPmkRm1vE4SKj63Ezh97NZS" -- your webhook adress
Config.Blip = {
	Blip = true, -- Do you get a blip on the map? 
	Alpha = true, -- Should the area appear in red on the map?
	color = 25,
	sprite = 496,
	scale = 0.75,
}

Config.Coords = { -- Where can saplings be planted
	vector4(3718.128, 4537.115, 21.50029, 70), -- x,y,z,distance (distance will determine how much space is available)
}
-- Don't forget to add items in the config to the server!
-- Don't forget to add items in the config to the server!
-- Don't forget to add items in the config to the server!
Config.Items = {
	["Seed"] = "weed_seed", -- seed item name
	["Water"] = "water_bottle", -- water item name
	["Fertilizer"] = "weed_nutrition", -- fertilizer item name
	["Dust"] = "dust", -- Dust item name
	["Weed"] = "weedbud", -- weed item name
}

Config.Give = {
	["Water"] = 10, -- When you give 1 water, how many water % should be added?
	["Fertilizer"] = 10, -- When you give 1 Fertilizer, how many Fertilizer % should be added?
	["Dust"] = { -- When you use this powder, it has a very fast effect
		["Healt"] = 15, -- how much the plant's life will increase when using the powder 
		["Growth"] = 10, -- how much the plant will grow after using the powder 
	}, 
}

Config.Wait = {
	["Check"] = 5, -- Check every few seconds (this time is important because it determines how many seconds it will grow after watering, etc.).
	["Seed"] = 4, -- How many seconds should the seed planting animation last?
	["Harvest"] = 6, -- How many seconds should the harvest animation last?
}

Config.PoliceRequired = 0
Config.PedList = {
	{
		model = "a_f_m_fatbla_01",                            
		coords = vector3(3715.812, 4522.6489, 20.86976),               
		heading = 92.30635,
		gender = "male",
        scenario = "WORLD_HUMAN_AA_SMOKE"
	}
	-- {
	-- 	model = "u_m_m_filmdirector",                            
	-- 	coords = vector3(-64.62981, -2517.584, 6.4011697),               
	-- 	heading = 239.95529,
	-- 	gender = "male",
    --     scenario = "WORLD_HUMAN_AA_SMOKE"
	-- },
}


Config.Langs = {
	["Waiter"] = "You can't open the menu so fast, please wait a bit!",
	["Blip"] = "Weed Field",
	["MaxWeed"] = "You can't plant more seeds in a row.",
	["Distance"] = "This is not a field!",
	["OpenWeed"] = "Review Status",
	["Harvest"] = "Successful harvest",
	["Harvest_eror"] = "Early harvest!",
} 

Config.Props = {
	["Weed_Lvl1"] = "bkr_prop_weed_01_small_01c",
	["Weed_Lvl2"] = "bkr_prop_weed_01_small_01b",
	["Weed_Lvl3"] = "bkr_prop_weed_01_small_01a", 
	["Weed_Lvl4"] = "bkr_prop_weed_med_01a", 
	["Weed_Lvl5"] = "bkr_prop_weed_lrg_01a", 
	["spatulamodel"] = "bkr_prop_coke_spatula_04",
}