Config = {
    ServerCallbacks = {}, -- Don't edit or change
    UseVehicleImages = true, -- If true you will see original vehicle images at UI, if false you will just see a car icon
    AutoRestoreVehicles = false, -- If true stores cars in garage on restart, if false doesnt modify car states
    VisuallyDamageCars = true, -- If true damage car on spawn, if false no damage on spawn
    SharedGarages = true, -- If true take any car from any garage, if false only take car from garage stored in
    ClassSystem = false, -- If true restrict vehicles by class, if false any vehicle class in any garage
    Warp = true, -- If true warp player into vehicle, if false vehicle spawns without warping
    VehicleClasses = {
        all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
        car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 18, 22},
        air = {15, 16},
        sea = {14},
        rig = {10, 11, 17, 19, 20},
        emergency = {18, 19}
    }
}

-- Fuel Functions
function Config.GetFuel(vehicle)
    return exports["cdn-fuel"]:GetFuel(vehicle)
end

function Config.SetFuel(vehicle, fuel)
    exports["cdn-fuel"]:SetFuel(vehicle, fuel)
end

-- Key Function
function Config.GiveKey(plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

-- Garages
Config.Garages = {
    ApartmentsGarage = {
        label = 'Alta Apartments',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(-297.10571289063, -993.80816650391),
            vector2(-294.90356445313, -987.54791259766),
            vector2(-357.55151367188, -965.46685791016),
            vector2(-359.65817260742, -971.33563232422)
            },
            ['minZ'] = 30.0,  -- min height of the parking zone
            ['maxZ'] = 33.0,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(-297.71, -990.11, 30.76, 338.79),
            vector4(-301.09, -988.82, 30.76, 339.11),
            vector4(-304.64, -987.72, 30.76, 339.36),
            vector4(-308.09, -986.34, 30.76, 339.47),
            vector4(-311.46, -985.08, 30.76, 339.5),
            vector4(-315.07, -983.98, 30.76, 339.18),
            vector4(-318.71, -982.49, 30.76, 338.43),
            vector4(-285.76, -888.04, 30.76, 168.44),
            vector4(-289.39, -887.34, 30.76, 168.59),
            vector4(-292.99, -886.36, 30.76, 167.4),
            vector4(-296.78, -885.82, 30.75, 167.93),
            vector4(-300.35, -885.14, 30.76, 167.76),
            vector4(-303.82, -884.06, 30.76, 167.76),
            vector4(-307.59, -883.44, 30.76, 167.24),
            vector4(-311.16, -882.7, 30.76, 166.92),
            vector4(-314.74, -881.99, 30.75, 166.91),
            vector4(-318.34, -881.19, 30.75, 167.5),
            vector4(-322.02, -880.47, 30.75, 167.75),
            vector4(-325.62, -879.65, 30.75, 168.31),
            vector4(-329.11, -878.9, 30.75, 168.35),
            vector4(-332.88, -878.22, 30.75, 167.35),
            vector4(-336.55, -877.38, 30.75, 168.02),
            vector4(-340.1, -876.67, 30.75, 167.45),
            vector4(-343.78, -875.91, 30.75, 167.01),
            vector4(-352.86, -874.08, 30.75, 0.76),
            vector4(-360.26, -889.43, 30.75, 269.23),
            vector4(-360.46, -893.17, 30.75, 268.23),
            vector4(-360.24, -896.83, 30.75, 270.26),
            vector4(-360.37, -900.58, 30.75, 268.61),
            vector4(-360.29, -904.27, 30.75, 269.75),
            vector4(-360.14, -908.01, 30.75, 270.4),
            vector4(-360.5, -911.66, 30.76, 269.55),
            vector4(-360.12, -915.4, 30.76, 269.63),
            vector4(-360.28, -919.07, 30.76, 270.11),
            vector4(-360.56, -922.77, 30.75, 268.41),
            vector4(-360.46, -926.49, 30.76, 270.43),
            vector4(-360.37, -930.12, 30.76, 269.72),
            vector4(-360.22, -933.88, 30.76, 270.34),
            vector4(-360.28, -937.58, 30.76, 269.99),
            vector4(-360.47, -941.31, 30.75, 269.54),
            vector4(-360.28, -944.99, 30.76, 270.14),
            vector4(-360.32, -948.72, 30.76, 269.82),
            vector4(-360.38, -952.44, 30.75, 269.95),
            vector4(-360.57, -956.16, 30.76, 270.31),
            vector4(-322.02, -981.29, 30.76, 339.92),
            vector4(-325.56, -980.1, 30.76, 340.1),
            vector4(-329.0, -978.69, 30.76, 338.49),
            vector4(-332.49, -977.59, 30.76, 339.58),
            vector4(-335.9, -976.3, 30.76, 339.7),
            vector4(-339.43, -975.08, 30.76, 339.47),
            vector4(-342.7, -973.45, 30.76, 338.85),
            vector4(-326.58, -956.4, 30.75, 250.37),
            vector4(-325.37, -952.84, 30.76, 250.47),
            vector4(-324.03, -949.43, 30.76, 250.37),
            vector4(-322.69, -945.96, 30.75, 249.91),
            vector4(-321.47, -942.43, 30.76, 250.29),
            vector4(-320.23, -939.06, 30.76, 250.38),
            vector4(-318.8, -935.56, 30.76, 249.46),
            vector4(-317.66, -932.03, 30.76, 250.73),
            vector4(-316.5, -928.43, 30.76, 250.15),
            vector4(-345.07, -932.2, 30.76, 69.27),
            vector4(-343.99, -928.61, 30.76, 70.11),
            vector4(-342.58, -925.18, 30.76, 70.69),
            vector4(-341.39, -921.67, 30.76, 69.83),
            vector4(-327.34, -924.44, 30.76, 69.82),
            vector4(-328.81, -927.89, 30.76, 69.43),
            vector4(-330.09, -931.33, 30.76, 70.81),
            vector4(-331.29, -934.83, 30.76, 70.29),
            vector4(-332.71, -938.34, 30.76, 69.75),
            vector4(-333.91, -941.81, 30.76, 69.46),
            vector4(-335.02, -945.3, 30.75, 71.24),
            vector4(-336.56, -948.74, 30.75, 70.65),
            vector4(-337.69, -952.22, 30.76, 70.31),
            vector4(-340.74, -902.45, 30.75, 167.89),
            vector4(-337.18, -903.24, 30.75, 167.65),
            vector4(-333.64, -903.98, 30.75, 167.05),
            vector4(-329.93, -904.61, 30.75, 167.95),
            vector4(-326.38, -905.62, 30.75, 168.51),
            vector4(-322.65, -906.2, 30.75, 167.96),
            vector4(-318.98, -906.94, 30.75, 168.06),
            vector4(-315.39, -907.89, 30.75, 166.81),
            vector4(-311.81, -908.81, 30.75, 167.5),
            vector4(-308.14, -909.33, 30.75, 167.34),
            vector4(-285.56, -921.9, 30.76, 70.14),
            vector4(-283.75, -918.52, 30.76, 70.23),
            vector4(-282.97, -914.81, 30.75, 69.93),
            vector4(-281.65, -911.4, 30.76, 69.49),
            vector4(-280.5, -908.04, 30.76, 69.51),
            vector4(-279.28, -904.45, 30.76, 70.18),
            vector4(-302.07, -933.44, 30.75, 69.9),
            vector4(-303.19, -937.09, 30.76, 70.71),
            vector4(-304.56, -940.34, 30.76, 70.04),
            vector4(-305.74, -943.95, 30.76, 70.49),
            vector4(-307.19, -947.34, 30.76, 69.04),
            vector4(-308.26, -950.95, 30.76, 70.24),
            vector4(-309.63, -954.35, 30.76, 68.9),
            vector4(-310.83, -957.88, 30.76, 69.56),
            vector4(-312.07, -961.38, 30.76, 70.21),
            vector4(-313.39, -964.8, 30.76, 68.92),
            vector4(-298.26, -899.82, 30.66, 346.23),
            vector4(-302.47, -898.86, 30.66, 348.7),
            vector4(-305.9, -898.52, 30.66, 351.35),
            vector4(-309.58, -897.38, 30.66, 347.24),
            vector4(-313.04, -896.37, 30.65, 349.98),
            vector4(-316.74, -895.46, 30.65, 347.83),
            vector4(-320.36, -894.95, 30.65, 348.97),
            vector4(-324.05, -893.86, 30.65, 348.71),
            vector4(-327.67, -893.18, 30.65, 347.61),
            vector4(-331.02, -892.69, 30.65, 346.03),
            vector4(-334.83, -891.72, 30.65, 350.2),
            vector4(-338.6, -891.08, 30.65, 348.34)
        },
        showBlip = true,
        blipcoords = vector3(-307.8, -987.18, 31.08),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    motelgarage = {
        label = 'Motel Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(285.39, -345.18),
            vector2(292.59, -325.44),
            vector2(268.95, -316.75),
            vector2(262.46, -332.86)

            },
            ['minZ'] = 43.9,  -- min height of the parking zone
            ['maxZ'] = 47.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(266.92, -332.26, 44.92, 72.71),
            vector4(268.22, -329.41, 44.92, 74.1),
            vector4(269.75, -326.3, 44.92, 71.34),
            vector4(270.69, -322.8, 44.92, 77.47),
            vector4(271.79, -319.55, 44.92, 78.29),
            vector4(278.26, -340.32, 44.92, 75.35),
            vector4(279.12, -337.02, 44.92, 75.28),
            vector4(280.4, -333.82, 44.92, 76.74),
            vector4(281.5, -330.6, 44.92, 74.71),
            vector4(282.78, -327.33, 44.92, 85.26),
            vector4(283.98, -324.23, 44.92, 73.08),
            vector4(288.62, -325.68, 44.92, 250.54),
            vector4(287.73, -329.18, 44.92, 259.32),
            vector4(286.41, -332.4, 44.92, 252.48),
            vector4(285.29, -335.57, 44.92, 257.1),
            vector4(283.99, -338.68, 44.92, 258.69),
            vector4(282.72, -342.16, 44.92, 260.09)
        },
        showBlip = true,
        blipcoords = vector3(273.58, -343.83, 44.92),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    sapcounsel = {
        label = 'San Andreas Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(-329.2, -780.17),
            vector2(-332.92, -775.15),
            vector2(-339.3, -780.71),
            vector2(-334.49, -785.95)

            },
            ['minZ'] = 31.9,  -- min height of the parking zone
            ['maxZ'] = 37.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(-340.78, -767.32, 33.97, 88.58),
            vector4(-342.36, -764.25, 33.97, 265.61),
            vector4(-342.67, -760.41, 33.97, 269.67),
            vector4(-342.85, -756.8, 33.97, 266.94),
            vector4(-342.99, -753.58, 33.97, 264.49),
            vector4(-342.6, -749.53, 33.97, 262.24),
            vector4(-357.77, -776.0, 33.97, 266.25),
            vector4(-357.79, -770.93, 33.97, 272.98),
            vector4(-357.56, -767.71, 33.97, 268.88),
            vector4(-357.58, -764.31, 33.97, 263.13),
            vector4(-357.66, -760.11, 33.97, 271.13),
            vector4(-357.68, -756.84, 33.97, 273.89),
            vector4(-357.27, -753.58, 33.97, 270.21),
            vector4(-357.93, -749.65, 33.97, 269.66),
            vector4(-357.97, -746.15, 33.97, 258.6),
            vector4(-357.8, -743.04, 33.97, 266.34),
            vector4(-357.56, -737.91, 33.97, 267.41),
            vector4(-357.32, -733.48, 33.97, 272.93)
        },
        showBlip = true,
        blipcoords = vector3(-332.92, -775.15, 35.92),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    spanishave = {
        label = 'Spanish Ave Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(-1140.23, -738.02),
            vector2(-1150.56, -743.89),
            vector2(-1131.55, -766.72),
            vector2(-1122.29, -760.17)

            },
            ['minZ'] = 17.9,  -- min height of the parking zone
            ['maxZ'] = 22.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(-1130.49, -763.12, 18.77, 118.35),
            vector4(-1132.88, -760.33, 18.92, 108.38),
            vector4(-1135.05, -757.17, 19.1, 112.07),
            vector4(-1137.35, -754.18, 19.25, 109.81),
            vector4(-1139.87, -751.34, 19.39, 109.43),
            vector4(-1142.46, -748.22, 19.54, 111.29),
            vector4(-1144.75, -745.21, 19.7, 113.96),
            vector4(-1142.85, -741.0, 20.0, 288.83),
            vector4(-1140.39, -743.91, 19.84, 290.72),
            vector4(-1138.11, -746.76, 19.71, 285.08),
            vector4(-1135.11, -749.72, 19.58, 288.49),
            vector4(-1133.08, -752.87, 19.42, 291.61),
            vector4(-1130.76, -755.8, 19.27, 286.11),
            vector4(-1128.59, -758.86, 19.11, 291.57),
        },
        showBlip = true,
        blipcoords = vector3(-1140.23, -738.02, 19.17),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    caears24 = {
        label = 'Caears 24 Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(64.68, 13.78),
            vector2(66.08, 18.01),
            vector2(54.36, 22.58),
            vector2(52.02, 17.7)

            },
            ['minZ'] = 67.9,  -- min height of the parking zone
            ['maxZ'] = 70.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(54.4, 19.19, 69.51, 338.51),
            vector4(57.51, 18.3, 69.3, 337.66),
            vector4(60.59, 17.18, 69.16, 345.62),
            vector4(63.73, 16.07, 69.11, 346.34),
        },
        showBlip = true,
        blipcoords = vector3(69.84, 12.6, 68.96),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    lagunapi = {
        label = 'Laguna Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(361.78, 300.93),
            vector2(352.19, 270.9),
            vector2(387.67, 257.78),
            vector2(398.03, 290.49),

            },
            ['minZ'] = 100.9,  -- min height of the parking zone
            ['maxZ'] = 107.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(375.16, 295.03, 103.28, 161.75),
            vector4(378.77, 293.95, 103.20, 164.83),
            vector4(382.96, 292.88, 103.12, 162.43),
            vector4(386.64, 291.30, 103.05, 169.16),
            vector4(390.92, 290.46, 102.99, 166.40),
            vector4(393.89, 283.79, 102.97, 70.60),
            vector4(392.66, 280.41, 102.99, 74.16),
            vector4(391.66, 276.61, 102.99, 69.66),
            vector4(390.14, 272.97, 103.00, 70.63),
            vector4(388.39, 269.48, 103.01, 74.47),
            vector4(379.02, 263.91, 103.01, 343.44),
            vector4(375.25, 265.36, 103.02, 337.24),
            vector4(371.57, 266.65, 103.03, 337.12),
            vector4(367.64, 267.96, 103.05, 338.30),
            vector4(363.74, 269.44, 103.05, 343.96),
            vector4(359.76, 270.92, 103.08, 342.74),
            vector4(368.91, 275.00, 103.21, 162.64),
            vector4(372.10, 275.84, 103.13, 161.75),
            vector4(376.15, 274.59, 103.07, 160.45),
            vector4(378.56, 281.56, 103.11, 339.96),
            vector4(374.62, 282.88, 103.18, 338.52),
            vector4(371.00, 284.30, 103.25, 348.66),
            vector4(361.60, 293.46, 103.50, 66.52),
        },
        showBlip = true,
        blipcoords = vector3(364.37, 297.83, 103.49),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    beachp = {
        label = 'Beach Parking',
        takeVehicle = {
            ['Shape'] = { --polygon that surrounds the parking area
            vector2(-1192.13, -1507.86),
            vector2(-1173.19, -1491.35),
            vector2(-1190.28, -1466.86),
            vector2(-1207.50, -1483.95),

            },
            ['minZ'] = 2.9,  -- min height of the parking zone
            ['maxZ'] = 6.9,  -- max height of the parking zone

        },
        spawnPoint = {
            vector4(-1192.58, -1470.44, 4.38, 301.53),
            vector4(-1190.21, -1473.59, 4.38, 301.74),
            vector4(-1187.60, -1476.19, 4.38, 310.89),
            vector4(-1182.65, -1484.28, 4.38, 307.92),
            vector4(-1180.74, -1486.47, 4.38, 302.77),
            vector4(-1178.77, -1489.20, 4.38, 317.37),
            vector4(-1176.84, -1491.36, 4.38, 312.33),
            vector4(-1183.14, -1495.71, 4.38, 125.44),
            vector4(-1184.87, -1493.21, 4.38, 121.76),
            vector4(-1186.45, -1490.58, 4.38, 131.43),
            vector4(-1188.35, -1488.27, 4.38, 116.38),
            vector4(-1190.23, -1485.39, 4.38, 124.08),
            vector4(-1191.92, -1482.92, 4.38, 123.19),
            vector4(-1193.90, -1480.10, 4.38, 119.37),
            vector4(-1205.76, -1485.45, 4.36, 307.31),
            vector4(-1203.09, -1488.72, 4.36, 295.58),
            vector4(-1200.92, -1491.40, 4.36, 303.09),
            vector4(-1198.51, -1494.36, 4.37, 309.26),
            vector4(-1196.85, -1497.10, 4.36, 301.79),
            vector4(-1191.35, -1504.49, 4.37, 294.16),
        },
        showBlip = true,
        blipcoords = vector3(-1185.32, -1500.64, 4.38),
        blipName = 'Public Parking',
        blipNumber = 357,
        blipColor = 3,
        type = 'public',
        category = Config.VehicleClasses['car']
    },
    depotLot = {
        label = 'Depot Lot',
        takeVehicle = {
            ['Shape'] = {
                vector2(409.27, -1629.48),
                vector2(402.92, -1624.14),
                vector2(393.89, -1634.77),
                vector2(400.25, -1640.2)
            },
            ['minZ'] = 24.0,  -- min height of the parking zone
            ['maxZ'] = 31.0,  -- max height of the parking zone
        },
        spawnPoint = {
            vector4(410.09, -1657.37, 29.29, 323.3),
            vector4(407.75, -1655.26, 29.29, 319.27),
            vector4(405.5, -1653.09, 29.29, 319.9),
            vector4(403.44, -1650.63, 29.29, 324.06),
            vector4(400.66, -1648.81, 29.29, 317.71),
            vector4(398.35, -1646.78, 29.29, 317.64),
            vector4(395.76, -1644.98, 29.29, 321.8)
        },
        showBlip = true,
        blipName = 'Depot Lot',
        blipNumber = 68,
        blipColor = 3,
        blipcoords = vector3(409.03, -1622.88, 29.29),
        type = 'depot',
        category = Config.VehicleClasses['car']
    },
}