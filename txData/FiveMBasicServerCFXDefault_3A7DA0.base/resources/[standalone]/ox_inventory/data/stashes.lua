return {
	-- SOM: the MRPD personal locker was REMOVED from here.
	--
	-- som-police registers its own lockers, on the eye, at coordinates verified
	-- against the Gabz MLO. This entry put a second locker a few metres away
	-- with an E prompt, so MRPD had two, one of which som-police knew nothing
	-- about. See som-police/shared/config.lua.
	--
	-- Re-apply this removal on an ox_inventory upgrade.

	{
		coords = vec3(301.3, -600.23, 43.28),
		target = {
			loc = vec3(301.82, -600.99, 43.29),
			length = 0.6,
			width = 1.8,
			heading = 340,
			minZ = 43.34,
			maxZ = 44.74,
			label = 'Open personal locker'
		},
		name = 'emslocker',
		label = 'Personal Locker',
		owner = true,
		slots = 70,
		weight = 70000,
		groups = {['ambulance'] = 0}
	},
}
