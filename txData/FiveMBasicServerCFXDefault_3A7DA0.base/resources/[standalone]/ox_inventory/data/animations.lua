-- The item prop and animation binder.
--
-- Items reference these by name (`client = { anim = 'eating', prop = 'burger' }`)
-- instead of repeating a dict, clip, model, pos and rot at every call site. That
-- is the whole point: one place to correct a hand position, and every item
-- holding that prop moves with it.
--
-- SOM additions are grouped below the two stock entries. Sourced from
-- allyaminou/Ox_Inventory-ItemsTemplate (GPL-3.0) and
-- Andyyy7666/itemcollection, recorded in ICON-AUDIT.md.
--
-- `pos` and `rot` are relative to the right hand bone (28422). If a prop floats
-- or clips, those two are what to change, and changing them here fixes every
-- item that names the prop.
return {
	anim = {
		['eating'] = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },

		-- Bottles and cans. One clip covers both; the prop is what differs.
		['drinking'] = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },

		-- Held at chest height and looked at. Reads as inspecting something
		-- rather than consuming it, so it suits documents and small tools.
		['clipboard'] = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },

		-- Crouch and place. Used by the placeable props below, and it is the
		-- same clip their pickup interaction plays, so putting one down and
		-- picking it up look like the same act.
		['placing'] = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' },

		-- Shrugging a shirt on. Stock ox uses this for the parachute.
		['wearing'] = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
	},
	prop = {
		['burger'] = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },

		['sandwich'] = { model = `prop_sandwich_01`, pos = vec3(0.05, -0.02, -0.03), rot = vec3(150.0, 340.0, 170.0) },

		['cola'] = { model = `prop_ecola_can`, pos = vec3(0.025, 0.010, 0.05), rot = vec3(5.0, 5.0, -180.5) },
		['energy_can'] = { model = `sf_prop_sf_can_01a`, pos = vec3(0.025, 0.010, 0.05), rot = vec3(5.0, 5.0, -180.5) },

		-- Stock ox already uses this model for the bandage. Named here so the
		-- bandage and anything else holding it share one definition.
		['rolled_cloth'] = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
	}
}
