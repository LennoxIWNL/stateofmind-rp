--- Jerry cans. The fuel is the can's `durability` metadata (0 to 100 percent of
--- `Config.can.capacity`), written here only, with `ammo` mirrored the way
--- ox_inventory does for a petrol can.

local core = exports['som-core']
local ox = exports.ox_inventory

local done = Fuel.Done
local ITEM = 'WEAPON_PETROLCAN'

local function heldCan(source)
    local weapon = ox:GetCurrentWeapon(source)
    if not weapon or weapon.name ~= ITEM then return nil end
    return weapon, tonumber(weapon.metadata and weapon.metadata.durability) or 0
end

local function setFill(source, weapon, value)
    local metadata = {}
    for k, v in pairs(weapon.metadata or {}) do metadata[k] = v end
    metadata.durability, metadata.ammo = value, value
    ox:SetMetadata(source, weapon.slot, metadata)
    local after = ox:GetCurrentWeapon(source)
    return after ~= nil and after.metadata ~= nil and after.metadata.durability == value
end

lib.callback.register('som-fuel:server:canBuy', function(source, accountName)
    if not core:getPlayer(source) then return done(false, 'not loaded') end
    local station = Fuel.StationAt(source)
    if not station then return done(false, 'no gas station here') end
    if not Fuel.Ready(source) then return done(false, 'one moment') end

    local method = Fuel.Account(accountName)
    local ok, err = Fuel.Sell(source, method, Config.can.price, 'fuelcan:' .. station.name)
    if not ok then return done(false, err) end

    if not ox:AddItem(source, ITEM, 1, { durability = 100, ammo = 100 }) then
        Fuel.Reverse(source, method, Config.can.price, 'fuelcan:' .. station.name)
        return done(false, 'you cannot carry it')
    end
    return done(true)
end)

lib.callback.register('som-fuel:server:canRefill', function(source, accountName)
    if not core:getPlayer(source) then return done(false, 'not loaded') end
    local station = Fuel.StationAt(source)
    if not station then return done(false, 'no gas station here') end
    local weapon, fill = heldCan(source)
    if not weapon then return done(false, 'hold your jerry can') end
    if not Fuel.Ready(source) then return done(false, 'one moment') end

    local missing = math.floor(Config.can.capacity * (100 - fill) / 100)
    if missing < 1 then return done(false, 'the can is full') end

    local method = Fuel.Account(accountName)
    local total = missing * Fuel.Price(station)
    local ok, err = Fuel.Sell(source, method, total, 'fuelcan:refill')
    if not ok then return done(false, err) end

    if not setFill(source, weapon, 100) then
        Fuel.Reverse(source, method, total, 'fuelcan:refill')
        return done(false, 'the can could not be filled')
    end
    return done(true, nil, { litres = missing, total = total })
end)

lib.callback.register('som-fuel:server:canUse', function(source, netId)
    if not core:getPlayer(source) then return done(false, 'not loaded') end
    if GetVehiclePedIsIn(GetPlayerPed(source), false) ~= 0 then return done(false, 'get out first') end
    local vehicle = Fuel.VehicleNear(source, netId, Config.can.distance)
    if not vehicle then return done(false, 'no vehicle here') end
    local weapon, fill = heldCan(source)
    if not weapon then return done(false, 'hold your jerry can') end
    if not Fuel.Ready(source) then return done(false, 'one moment') end

    local current = Fuel.Current(vehicle)
    local inCan = math.floor(Config.can.capacity * fill / 100)
    if inCan < 1 then return done(false, 'the can is empty') end
    local litres = math.min(Config.can.pour, inCan, math.floor(Config.tank - current))
    if litres < 1 then return done(false, 'the tank is full') end

    -- The can is emptied first: if that write fails, no fuel is given.
    local cost = math.ceil(litres * 100 / Config.can.capacity)
    if not setFill(source, weapon, math.max(0, fill - cost)) then return done(false, 'the can could not be used') end

    Fuel.Set(vehicle, current + litres)
    return done(true, nil, { litres = litres })
end)
