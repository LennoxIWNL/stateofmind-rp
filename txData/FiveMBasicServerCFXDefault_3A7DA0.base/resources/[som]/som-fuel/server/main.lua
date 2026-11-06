--- Fuel sales. The client asks for litres; the server finds the station by the
--- player's own position, reads the vehicle's current fuel from its state bag,
--- caps the request at the tank, prices it, takes the money first and credits
--- the station business second, undoing the debit if the credit fails. Fuel is
--- only ever raised here (state bag) or by a can use; the drain is the client's.

local core = exports['som-core']

local last = {}

Fuel = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end
Fuel.Done = done

---Rate limit for money actions: true when this player may act now.
function Fuel.Ready(source)
    local now = GetGameTimer()
    if last[source] and now - last[source] < Config.cooldownMs then return false end
    last[source] = now
    return true
end

local function usable(station)
    return station.enabled and station.coords ~= nil
end

---The open station the player is standing at, by server position.
function Fuel.StationAt(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local at = GetEntityCoords(ped)
    for _, station in ipairs(Config.stations) do
        if usable(station) and #(at - station.coords) <= Config.stationDistance then return station end
    end
end

function Fuel.Price(station) return station.price or Config.pricePerLitre end

---A vehicle near the player that they are standing next to or driving.
function Fuel.VehicleNear(source, netId, distance)
    netId = tonumber(netId)
    if not netId or netId % 1 ~= 0 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > distance then return nil end
    local inside = GetVehiclePedIsIn(ped, false)
    if inside ~= 0 and inside ~= vehicle then return nil end
    return vehicle
end

---Current fuel from the state bag the driver publishes; the client's claim only when there is none.
function Fuel.Current(vehicle, claimed)
    local fuel = Entity(vehicle).state.fuel
    if type(fuel) ~= 'number' then fuel = tonumber(claimed) or Config.tank / 2 end
    return math.max(0, math.min(Config.tank, fuel))
end

function Fuel.Set(vehicle, value)
    Entity(vehicle).state:set('fuel', math.max(0, math.min(Config.tank, value)) + 0.0, true)
end

---Takes `total` from the player and credits the station business, or does neither.
function Fuel.Sell(source, account, total, reason)
    local paid, err = core:payWith(source, account, total, reason)
    if not paid then return false, err or 'you cannot afford that' end

    local ok, credited = pcall(function() return core:businessTransact(Config.business, total, reason) end)
    if ok and credited then return true end

    core:addMoney(source, account, total, reason .. ':refund')
    return false, 'the station could not take payment'
end

---Puts a sale back: business debit first, then the player refund.
function Fuel.Reverse(source, account, total, reason)
    local ok, debited = pcall(function() return core:businessTransact(Config.business, -total, reason .. ':undo') end)
    if ok and debited then core:addMoney(source, account, total, reason .. ':refund') end
end

local function account(value)
    for _, name in ipairs(Config.accounts) do
        if value == name then return name end
    end
    return Config.accounts[#Config.accounts]
end
Fuel.Account = account

lib.callback.register('som-fuel:server:stations', function()
    local out = {}
    for _, station in ipairs(Config.stations) do
        if usable(station) then out[#out + 1] = { x = station.coords.x, y = station.coords.y, z = station.coords.z } end
    end
    return out
end)

lib.callback.register('som-fuel:server:quote', function(source, netId, claimed)
    local station = Fuel.StationAt(source)
    if not station then return done(false, 'no gas station here') end
    local vehicle = Fuel.VehicleNear(source, netId, Config.vehicleDistance)
    if not vehicle then return done(false, 'no vehicle here') end

    local current = Fuel.Current(vehicle, claimed)
    return done(true, nil, { price = Fuel.Price(station), room = math.floor(Config.tank - current), current = current })
end)

lib.callback.register('som-fuel:server:buy', function(source, netId, litres, claimed, accountName)
    if not core:getPlayer(source) then return done(false, 'not loaded') end
    litres = tonumber(litres)
    if not litres or litres % 1 ~= 0 or litres < 1 or litres > Config.tank then return done(false, 'bad request') end

    local station = Fuel.StationAt(source)
    if not station then return done(false, 'no gas station here') end
    local vehicle = Fuel.VehicleNear(source, netId, Config.vehicleDistance)
    if not vehicle then return done(false, 'no vehicle here') end
    if not Fuel.Ready(source) then return done(false, 'one moment') end

    local current = Fuel.Current(vehicle, claimed)
    litres = math.min(litres, math.floor(Config.tank - current))
    if litres < 1 then return done(false, 'the tank is full') end

    local total = litres * Fuel.Price(station)
    local method = account(accountName)
    local ok, err = Fuel.Sell(source, method, total, 'fuel:' .. station.name)
    if not ok then return done(false, err) end

    Fuel.Set(vehicle, current + litres)
    return done(true, nil, { litres = litres, total = total, fuel = current + litres })
end)

AddEventHandler('playerDropped', function() last[source] = nil end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then last = {} end
end)

CreateThread(function() SomPlacements.Apply(Config) end)
