return {
	{
        name = 'mechanic_workshop',
		groups = { mechanic = 0 },
		items = {
			{
				name = 'lockpick',
				ingredients = {
					scrapmetal = 5,
					WEAPON_HAMMER = 0.05
				},
				duration = 5000,
				count = 2,
			},
			{
				name = 'repairkit',
				ingredients = {
					steel = 2,
					plastic = 2,
					scrapmetal = 3
				},
				duration = 8000,
				count = 1,
			},
			{
				name = 'tirerepairkit',
				ingredients = {
					rubber = 2,
					scrapmetal = 2
				},
				duration = 6000,
				count = 1,
			},
			{
				name = 'advancedrepairkit',
				ingredients = {
					repairkit = 1,
					electronickit = 1,
					steel = 2
				},
				duration = 12000,
				count = 1,
			},
			{
				name = 'advancedlockpick',
				ingredients = {
					lockpick = 1,
					screwdriverset = 1
				},
				duration = 8000,
				count = 1,
			},
			{
				name = 'electronickit',
				ingredients = {
					copper = 2,
					plastic = 2,
					glass = 1
				},
				duration = 8000,
				count = 1,
			},
		},
		points = {
			vec3(-1147.083008, -2002.662109, 13.180260),
			vec3(-345.374969, -130.687088, 39.009613)
		},
		zones = {
			{
				coords = vec3(-1146.2, -2002.05, 13.2),
				size = vec3(3.8, 1.05, 0.15),
				distance = 1.5,
				rotation = 315.0,
			},
			{
				coords = vec3(-346.1, -130.45, 39.0),
				size = vec3(3.8, 1.05, 0.15),
				distance = 1.5,
				rotation = 70.0,
			},
		},
		blip = { id = 566, colour = 31, scale = 0.8 },
	},
}
