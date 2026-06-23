

-- █░░█ █▀▀█ █▀▀ █░█ █▀▀ █▀▀█   █▀▄▀█ █▀▀ █▀▀▄ █░░█   █▀▀ █▀▀█ █▀▀▄ █▀▀ ░▀░ █▀▀▀
-- █▀▀█ █▄▄█ █░░ █▀▄ █▀▀ █▄▄▀   █░▀░█ █▀▀ █░░█ █░░█   █░░ █░░█ █░░█ █▀▀ ▀█▀ █░▀█
-- ▀░░▀ ▀░░▀ ▀▀▀ ▀░▀ ▀▀▀ ▀░▀▀   ▀░░░▀ ▀▀▀ ▀░░▀ ░▀▀▀   ▀▀▀ ▀▀▀▀ ▀░░▀ ▀░░ ▀▀▀ ▀▀▀▀

Config = {}

Config.Mysql = "oxmysql" -- mysql-async, ghmattimysql, oxmysql
Config.Money = "bank" -- cash or bank
Config.Webhook = "https://discord.com/api/webhooks/1246766874541428777/bCaRDSfTwIYJfVHfGakxpeuJ_3Xbnrcf-4gkIkGWf8gAkOGwC66YZhAlBQdptvWq5KMp" -- insert log channel webhook
Config.ItemName = "tablet" -- hacker tablet item name

Config.HackerMenu = {
	LspdActivePersonel = {
		label = "Check LSPD Active Personnel", -- what to show up as on the hacker menu
		permission = "police", -- which profession's permission is required
		dec = "Access real-time data on the total number of active police officers serving in the Los Santos Police Department (LSPD) through this powerful tool. Stay informed about the strength and presence of law enforcement in the city to strategize and plan your actions accordingly.", -- what to write as a description in the menu?
		level = 1, -- how many levels are required to access
		waiter = 3, -- after how many minutes can it be done again after doing it once
		HackTime = 10, -- how many seconds to complete the hack once it starts
		price = 100, -- how much to pay
		addXP = 3, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	PhoneCheck = {
		label = "Phone Number Check", -- what to show up as on the hacker menu
		dec = "If you know the name of the person you are looking for, you can access their contact details, including their phone number, through this advanced tool. Stay connected and stay informed with the power of information at your fingertips.", -- what to write as a description in the menu?
		level = 2, -- how many levels are required to access
		waiter = 5, -- after how many minutes can it be done again after doing it once
		HackTime = 10, -- how many seconds to complete the hack once it starts
		price = 200, -- how much to pay
		addXP = 5, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	PhonefromName = {
		label = "Identity Information", -- what to show up as on the hacker menu
		dec = "Here, using the power of advanced algorithms and extensive databases, you can uncover comprehensive credentials of individuals by simply providing their full name and surname. Discover personal information, contact details, and more with this cutting-edge tool.", -- what to write as a description in the menu?
		level = 2, -- how many levels are required to access
		waiter = 7, -- after how many minutes can it be done again after doing it once
		HackTime = 15, -- how many seconds to complete the hack once it starts
		price = 200, -- how many xp will it give upon completion? how much to pay
		addXP = 7, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	CctvCamera = {
		label = "Infiltrate CCTV", -- what to show up as on the hacker menu
		dec = "Gain unauthorized access to the city's extensive Closed Circuit Television (CCTV) network through this sophisticated tool. Explore live camera feeds, monitor key locations, and gather valuable surveillance information to stay one step ahead in the urban landscape.", -- what to write as a description in the menu?
		level = 1, -- how many levels are required to access
		waiter = 10, -- after how many minutes can it be done again after doing it once
		HackTime = 20, -- how many seconds to complete the hack once it starts
		price = 300, -- how much to pay
		addXP = 9, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	AnonimTweet = {
		label = "Send Anonymous Tweet", -- what to show up as on the hacker menu
		dec = "Utilize this powerful tool to send anonymous tweets without revealing your identity. Express your thoughts, share information, or engage in covert communication with complete anonymity. Your secrets are safe with us.", -- what to write as a description in the menu?
		level = 4, -- how many levels are required to access
		waiter = 10, -- after how many minutes can it be done again after doing it once
		HackTime = 20, -- how many seconds to complete the hack once it starts
		price = 500, -- how much to pay
		addXP = 10, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	CarLock = {
		label = "Open Car Lock", -- what to show up as on the hacker menu
		dec = "Unlock the doors of a nearby vehicle using this tool. Gain unauthorized access to locked cars, providing you with the ability to retrieve valuable items, assist stranded individuals, or engage in covert operations. Exercise caution and responsibility while utilizing this feature.", -- what to write as a description in the menu?
		level = 4, -- how many levels are required to access
		waiter = 15, -- after how many minutes can it be done again after doing it once
		HackTime = 30, -- how many seconds to complete the hack once it starts
		price = 500, -- how much to pay
		addXP = 10, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	LocationCheck = {
		label = "Phone Number Location Check", -- what to show up as on the hacker menu
		dec = "Discover the real-time location of an individual whose phone number you possess using this cutting-edge tool. Track their movements, monitor their whereabouts, or ensure their safety with precise location information. Stay one step ahead with this advanced tracking capability.", -- what to write as a description in the menu?
		level = 5, -- how many levels are required to access
		waiter = 30, -- after how many minutes can it be done again after doing it once
		HackTime = 60, -- how many seconds to complete the hack once it starts
		price = 1000, -- how much to pay
		addXP = 15, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	BankHack = {
		label = "Bank Hack", -- what to show up as on the hacker menu
		dec = "Unleash your hacking skills to infiltrate the bank's secure system and initiate a simulated heist. While no funds are deducted from real players, you can experience the thrill of hacking into the virtual bank and earn virtual money. Test your abilities and see if you can outsmart the bank's defenses.", -- what to write as a description in the menu?
		level = 7, -- how many levels are required to access
		waiter = 60, -- after how many minutes can it be done again after doing it once
		HackTime = 80, -- how many seconds to complete the hack once it starts
		price = 1500, -- how much to pay
		giveMoney = {min = 500, max=2500}, -- How much money should he pay when he succeeds?
		addXP = 15, -- how many xp will it give upon completion? 100xp = 1lvl
	},
	SendAllDM = {
		label = "Send Anonymous Announcement", -- what to show up as on the hacker menu
		dec = "Send a mass direct message (DM) to all players anonymously using this powerful tool. Make announcements, share important information, or broadcast your message to the entire community. Maintain your anonymity while ensuring that all players receive and acknowledge your message.", -- what to write as a description in the menu?
		level = 10, -- how many levels are required to access
		waiter = 30, -- after how many minutes can it be done again after doing it once
		HackTime = 60, -- how many seconds to complete the hack once it starts
		price = 2000, -- how much to pay
		addXP = 20, -- how many xp will it give upon completion? 100xp = 1lvl
	},
}

Config.Langs = {
	TimeError = "You've already done that recently",
	MoneyError = "You're short of money, check your bank",
	LevelError = "You lack the experience to do this job.",
	ActivePolice = "Total Police:",
	Identifier = "Person's Information:",
	SearchLimit = "You have exceeded the search limit then start a hack again.",
	PhoneNumber = "Personal Phone Number:",
	Exit = "Back to Menu",
	PrevCam = "Previous Camera",
	NextCam = "Next Camera",
	TweetText = " ANONIM TWEET ",
	AllDMText = " MESSAGE TO EVERYONE ",
	NoPlayer = "The person is not in the game",
	Gps = "GPS also marked",
	entername = "ENTER NAME...",
	enternumber = "ENTER NUMBER...",
	BankHack = "Hack success :",
}

Config.Tweet = {
	Phone = "qb-phone", -- other, quasarphone, gksphone, qb-phone
	Name = "Anonim Hacker",
	Username = "anonymous",
	profile = "https://img.freepik.com/premium-vector/anonymous-hacker-mascot-logo-illustration_360091-279.jpg?w=2000",
}

Config.CctvCamera = {
		["Bank"] = {
			{x = 232.86, y = 221.46, z = 107.83, r = {x = -25.0, y = 0.0, z = -140.0}, canRotate = true},
			{x = 257.45, y = 210.07, z = 109.08, r = {x = -25.0, y = 0.0, z = 28.0}, canRotate = true},
			{x = 261.50, y = 218.08, z = 107.95, r = {x = -25.0, y = 0.0, z = -149.0}, canRotate = true},
			{x = 241.64, y = 233.83, z = 111.48, r = {x = -25.0, y = 0.0, z = 120.0}, canRotate = true},
			{x = 269.66, y = 223.67, z = 113.23, r = {x = -25.0, y = 0.0, z = 111.0}, canRotate = true},
			{x = 261.98, y = 217.92, z = 113.25, r = {x = -25.0, y = 0.0, z = -159.0}, canRotate = true},
			{ x = 258.44, y = 204.97, z = 113.25, r = {x = -25.0, y = 0.0, z = 10.0}, canRotate = true},
			{x = 235.53, y = 227.37, z = 113.23, r = {x = -25.0, y = 0.0, z = -160.0}, canRotate = true},
			{x = 254.72, y = 206.06, z = 113.28, r = {x = -25.0, y = 0.0, z = 44.0}, canRotate = true},
			{x = 269.89, y = 223.76, z = 106.48, r = {x = -25.0, y = 0.0, z = 112.0}, canRotate = true},
			{x = 252.27, y = 225.52, z = 103.99, r = {x = -25.0, y = 0.0, z = -74.0}, canRotate = true}
		},

		["Police"] = {
			{x = 433.8810, y = -988.291, z = 33.822, r = {x = -25.0, y = 0.0, z = 39.0}, canRotate = true},
			{x = 424.3083, y = -996.720, z = 33.381, r = {x = -25.0, y = 0.0, z = 156.0}, canRotate = true},
			{x = 458.8177, y = -1021.05, z = 37.413, r = {x = -25.0, y = 0.0, z = 89.0}, canRotate = true},
			{x = 489.4088, y = -1017.59, z = 32.751, r = {x = -25.0, y = 0.0, z = 126.0}, canRotate = true},
			{x = 426.9510, y = -972.836, z = 27.333, r = {x = -25.0, y = 0.0, z = 234.0}, canRotate = true},
			{x = 464.9103, y = -972.539, z = 28.341, r = {x = -25.0, y = 0.0, z = 193.0}, canRotate = true},
			{x = 477.0179, y = -1004.85, z = 28.152, r = {x = -25.0, y = 0.0, z = 225.0}, canRotate = true},
			{x = 449.3049, y = -972.898, z = 32.373, r = {x = -25.0, y = 0.0, z = 195.0}, canRotate = true},
			{x = 419.0173, y = -1024.90, z = 30.797, r = {x = -25.0, y = 0.0, z = 288.0}, canRotate = true},
			{x = 386.8959, y = -999.827, z = 55.304, r = {x = -25.0, y = 0.0, z = 273.0}, canRotate = true},
		},
	
		["State"] = {
			{x = -1090.93, y = -807.855, z = 21.330, r = {x = -25.0, y = 0.0, z = 97.0}, canRotate = true},
			{x = -1088.53, y = -826.211, z = 20.889, r = {x = -25.0, y = 0.0, z = 1.0}, canRotate = true},
			{x = -1090.23, y = -847.576, z = 14.778, r = {x = -25.0, y = 0.0, z = 350.0}, canRotate = true},
			{x = -1112.61, y = -836.048, z = 40.501, r = {x = -25.0, y = 0.0, z = 276.0}, canRotate = true},
			{x = -1116.65, y = -831.386, z = 40.312, r = {x = -25.0, y = 0.0, z = 339.0}, canRotate = true},
			{x = -1033.22, y = -850.371, z = 17.318, r = {x = -25.0, y = 0.0, z = 111.0}, canRotate = true},
		},
	
		["Sheriff"] = {
			{x = -435.278, y = 6011.176, z = 34.078, r = {x = -25.0, y = 0.0, z = 5.0}, canRotate = true},
			{x = -449.116, y = 6023.020, z = 33.133, r = {x = -25.0, y = 0.0, z = 187.0}, canRotate = true},
			{x = -430.469, y = 5992.520, z = 33.070, r = {x = -25.0, y = 0.0, z = 90.0}, canRotate = true},
			{x = -440.689, y = 5994.783, z = 34.204, r = {x = -25.0, y = 0.0, z = 94.0}, canRotate = true},
			{x = -431.489, y = 5989.478, z = 34.267, r = {x = -25.0, y = 0.0, z = 280.0}, canRotate = true},
			{x = -447.589, y = 6022.989, z = 34.267, r = {x = -25.0, y = 0.0, z = 333.0}, canRotate = true},
		},
	
		["Hospital"] = {
			{x = -818.156, y = -1222.13, z = 8.8670, r = {x = -20.0, y = 0.0, z = 190.0}, canRotate = true},
			{x = -804.196, y = -1249.38, z = 8.8648, r = {x = -25.0, y = 0.0, z = 14.0}, canRotate = true},
			{x = -810.212, y = -1212.59, z = 8.8648, r = {x = -25.0, y = 0.0, z = 180.0}, canRotate = true},
			{x = -809.348, y = -1220.15, z = 8.9908, r = {x = -25.0, y = 0.0, z = 212.0}, canRotate = true},
			{x = -782.665, y = -1222.37, z = 8.8018, r = {x = -25.0, y = 0.0, z = 124.0}, canRotate = true},
			{x = -774.851, y = -1241.81, z = 8.8018, r = {x = -25.0, y = 0.0, z = 64.0}, canRotate = true},
			{x = -803.165, y = -1249.84, z = 9.0538, r = {x = -25.0, y = 0.0, z = 290.0}, canRotate = true},
			{x = -821.352, y = -1224.80, z = 9.7258, r = {x = -25.0, y = 0.0, z = 49.0}, canRotate = true},
			{x = -863.976, y = -1225.57, z = 10.040, r = {x = -25.0, y = 0.0, z = 305.0}, canRotate = true},
			{x = -772.696, y = -1229.64, z = 48.638, r = {x = -25.0, y = 0.0, z = 100.0}, canRotate = true},
			{x = -802.192, y = -1171.68, z = 54.119, r = {x = -25.0, y = 0.0, z = 214.0}, canRotate = true},
		},
	
		["Jewelry"] = {
			{x = -627.34, y = -239.85, z = 39.85, r = {x = -25.0, y = 0.0, z = 345.0}, canRotate = true},
			{x = -620.25, y = -224.22, z = 39.85, r = {x = -25.0, y = 0.0, z = 153.0}, canRotate = true},
			{x = -622.46, y = -235.5, z = 39.85, r = {x = -25.0, y = 0.0, z = 343.0}, canRotate = true},
			{x = -627.78, y = -230.01, z = 39.85, r = {x = -25.0, y = 0.0, z = 160.0}, canRotate = true}
		},
	
		["Motel"] = {
			{x = 326.79, y = -194.97, z = 57.0, r = {x = -25.0, y = 0.0, z = 230.0}, canRotate = true},
			{x = 306.36, y = -216.39, z = 60.02, r = {x = -25.0, y = 0.0, z = 299.0}, canRotate = true},
			{x = 347.02, y = -199.04, z = 60.02, r = {x = -25.0, y = 0.0, z = 107.0}, canRotate = true},
			{x = 339.31, y = -240.46, z = 61.05, r = {x = -25.0, y = 0.0, z = 83.0}, canRotate = true},
		},
	
		["Shop1"] = {
			{x = 373.27, y = 331.44, z = 105.57, r = {x = -25.0, y = 0.0, z = 208.0}, canRotate = true},
			{x = 380.63, y = 330.38, z = 105.57, r = {x = -25.0, y = 0.0, z = 55.0}, canRotate = true},
		},
	
		["Shop2"] = {
			{x = 2552.09, y = 380.34, z = 110.62, r = {x = -25.0, y = 0.0, z = 322.0}, canRotate = true},
			{x = 2551.68, y = 388.01, z = 110.62, r = {x = -25.0, y = 0.0, z = 147.0}, canRotate = true},
		},
	
		["Shop3"] = {
			{x = -3043.24, y = 582.42, z = 9.91, r = {x = -25.0, y = 0.0, z = 344.0}, canRotate = true},
			{x = -3046.66, y = 589.29, z = 9.91, r = {x = -25.0, y = 0.0, z = 168.0}, canRotate = true},
		},
	
		["Shop4"] = {
			{x = -1483.5, y = -380.12, z = 42.6, r = {x = -25.0, y = 0.0, z = 85.0}, canRotate = true},
			{x = -1479.84, y = -372.09, z = 42.16, r = {x = -25.0, y = 0.0, z = 168.0}, canRotate = true},
		},
	
		["Shop5"] = {
			{x = 1387.83, y = 3604.63, z = 36.98, r = {x = -25.0, y = 0.0, z = 265.0}, canRotate = true},
			{x = 1398.25, y = 3610.38, z = 36.98, r = {x = -25.0, y = 0.0, z = 50.0}, canRotate = true},
		},
	
		["Shop6"] = {
			{x = -2965.79, y = 387.31, z = 17.04, r = {x = -25.0, y = 0.0, z = 46.0}, canRotate = true},
			{x = -2957.82, y = 389.9, z = 16.04, r = {x = -25.0, y = 0.0, z = 139.0}, canRotate = true},
		},
	
		["Shop7"] = {
			{x = 2673.41, y = 3281.22, z = 57.24, r = {x = -25.0, y = 0.0, z = 303.0}, canRotate = true},
			{x = 2676.25, y = 3288.3, z = 57.24, r = {x = -25.0, y = 0.0, z = 109.0}, canRotate = true},
		},
	
		["Shop8"] = {
			{x = -42.85, y = -1755.13, z = 31.44, r = {x = -25.0, y = 0.0, z = 100.0}, canRotate = true},
			{x = -41.37, y = -1749.37, z = 31.42, r = {x = -25.0, y = 0.0, z = 103.0}, canRotate = true},
		},
	
		["Shop9"] = {
			{x = 1164.64, y = -318.63, z = 71.21, r = {x = -25.0, y = 0.0, z = 150.0}, canRotate = true},
			{x = 1161.57, y = -312.94, z = 71.21, r = {x = -25.0, y = 0.0, z = 176.0}, canRotate = true},
		},
	
		["Shop10"] = {
			{x = -705.5, y = -909.72, z = 21.22, r = {x = -25.0, y = 0.0, z = 150.0}, canRotate = true},
			{x = -707.46, y = -903.42, z = 21.22, r = {x = -25.0, y = 0.0, z = 154.0}, canRotate = true},
		},
	
		["Shop11"] = {
			{x = -1822.4, y = 797.64, z = 140.09, r = {x = -25.0, y = 0.0, z = 195.0}, canRotate = true},
			{x = -1827.99, y = 800.84, z = 138.15, r = {x = -25.0, y = 0.0, z = 195.0}, canRotate = true},
		},
	
		["Shop12"] = {
			{x = 1701.11, y = 4920.02, z = 44.06, r = {x = -25.0, y = 0.0, z = 20.0}, canRotate = true},
			{x = 1707.21, y = 4918.19, z = 44.06, r = {x = -25.0, y = 0.0, z = 20.0}, canRotate = true},
		},
	
		["Shop13"] = {
			{x = 1956.98, y = 3744.05, z = 34.34, r = {x = -25.0, y = 0.0, z = 262.0}, canRotate = true},
			{x = 1963.16, y = 3748.54, z = 34.34, r = {x = -25.0, y = 0.0, z = 80.0}, canRotate = true},
		},
	
		["Shop14"] = {
			{x = 1132.96, y = -979.16, z = 48.42, r = {x = -25.0, y = 0.0, z = 224.0}, canRotate = true},
			{x = 1125.22, y = -983.36, z = 48.0, r = {x = -25.0, y = 0.0, z = 312.0}, canRotate = true},
		},
	
		["Shop15"] = {
			{x = 23.64, y = -1342.25, z = 31.5, r = {x = -25.0, y = 0.0, z = 236.0}, canRotate = true},
			{x = 31.41, y = -1341.48, z = 31.5, r = {x = -25.0, y = 0.0, z = 48.0}, canRotate = true},
		},
	
		["Shop16"] = {
			{x = 550.48, y = 2666.68, z = 44.16, r = {x = -25.0, y = 0.0, z = 67.0}, canRotate = true},
			{x = 542.92, y = 2664.67, z = 44.16, r = {x = -25.0, y = 0.0, z = 243.0}, canRotate = true},
		},
	
		["Shop17"] = {
			{x = -3247.53, y = 1000.08, z = 14.83, r = {x = -25.0, y = 0.0, z = 305.0}, canRotate = true},
			{x = -3247.55, y = 1007.36, z = 14.83, r = {x = -25.0, y = 0.0, z = 138.0}, canRotate = true},
		},
	
		["Shop18"] = {
			{x = 1169.3, y = 2711.34, z = 40.16, r = {x = -25.0, y = 0.0, z = 120.0}, canRotate = true},
			{x = 1166.57, y = 2719.52, z = 40.16, r = {x = -25.0, y = 0.0, z = 230.0}, canRotate = true},
		},
	
		["Shop19"] = {
			{x = 1729.41, y = 6419.83, z = 37.04, r = {x = -25.0, y = 0.0, z = 213.0}, canRotate = true},
			{x = 1736.66, y = 6417.44, z = 37.04, r = {x = -25.0, y = 0.0, z = 19.0}, canRotate = true},
		},	
}