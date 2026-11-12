-- Minimal stand-ins for the FiveM natives and globals this codebase calls.
-- Not an FXServer emulation: just enough that real resource files load and
-- run outside the game.

local function vec3(x, y, z)
    local v = { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
    return setmetatable(v, {
        __sub = function(a, b)
            assert(getmetatable(a) and getmetatable(b), 'vector arithmetic on a plain table')
            return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
    })
end

local function vec4(x, y, z, w)
    return { x = x or 0.0, y = y or 0.0, z = z or 0.0, w = w or 0.0 }
end

_G.vec3 = vec3
_G.vector3 = vec3
_G.vec4 = vec4

-- Boot-time CreateThread bodies (seeding/retiring config rows) never run;
-- tests seed the fake DB directly instead, so a resource's load-time thread
-- doesn't need a working MySQL connection to not crash.
_G.CreateThread = function(fn) end
_G.Wait = function(ms) end
_G.PendingTimeouts = {}
_G.SetTimeout = function(ms, fn) _G.PendingTimeouts[#_G.PendingTimeouts + 1] = { ms = ms, fn = fn } end
_G.Handlers = {}
local handlerLists = {}
_G.AddEventHandler = function(name, fn)
    local list = handlerLists[name]
    if not list then
        list = {}
        handlerLists[name] = list
        -- Every handler for an event runs, in order, as the real runtime does.
        _G.Handlers[name] = function(...) for _, h in ipairs(list) do h(...) end end
    end
    list[#list + 1] = fn
end
_G.ResetHandlers = function() handlerLists = {}; _G.Handlers = {}; _G.PendingTimeouts = {} end
_G.RegisteredEvents = {}
_G.RegisterNetEvent = function(name, fn) if fn then _G.RegisteredEvents[name] = fn end end
_G.GetGameTimer = function() return (_G.Mocks and _G.Mocks.clock) or 0 end
_G.TriggerEvent = function(name, ...) local h = _G.Handlers[name]; if h then h(...) end end
_G.TriggerClientEvent = function(name, source, ...) end
_G.RegisterCommand = function(name, fn, restricted) end
_G.GetResourceState = function(name) return 'started' end
_G.GetInvokingResource = function() return (_G.Mocks and _G.Mocks.invoking) or 'test' end
_G.PerformHttpRequest = function() end
_G.GetConvar = function(name, default)
    local v = _G.Mocks and _G.Mocks.convars and _G.Mocks.convars[name]
    if v ~= nil then return v end
    return default
end
_G.GetNumPlayerIdentifiers = function(source) return #((_G.Mocks and _G.Mocks.identifiers and _G.Mocks.identifiers[source]) or {}) end
_G.GetPlayerIdentifier = function(source, i) return _G.Mocks.identifiers[source][i + 1] end

-- Player positions, settable per test via placePed() in run.lua.
_G.FakePeds = {}
_G.GetPlayerPed = function(source)
    return (_G.FakePeds[source] ~= nil) and source or 0
end
_G.GetEntityCoords = function(ped)
    return _G.FakePeds[ped] or vec3(0, 0, 0)
end

_G.GetPlayers = function() local out = {}; for id in pairs(_G.FakePeds) do out[#out + 1] = tostring(id) end; return out end
_G.GetPlayerName = function(source) return 'Player' .. tostring(source) end
_G.Buckets = {}
_G.SetPlayerRoutingBucket = function(source, bucket) _G.Buckets[source] = bucket end
_G.GetPlayerRoutingBucket = function(source) return _G.Buckets[source] or 0 end
_G.FakeSpeed = {}
_G.GetEntitySpeed = function(ped) return _G.FakeSpeed[ped] or 0.0 end
_G.Teleports = {}
_G.SetEntityCoords = function(ped, x, y, z) _G.Teleports[#_G.Teleports + 1] = { ped = ped, x = x, y = y, z = z } end

_G.Vehicles = {}
_G.Animals = {}
_G.NetworkGetEntityFromNetworkId = function(netId) return (_G.Vehicles[netId] or _G.Animals[netId]) and netId or 0 end
_G.DoesEntityExist = function(e) return _G.Vehicles[e] ~= nil or _G.Animals[e] ~= nil end
_G.GetEntityType = function(e) return _G.Animals[e] and 1 or 2 end
_G.GetEntityModel = function(e) return _G.joaat((_G.Vehicles[e] or _G.Animals[e]).model) end
_G.GetEntityHealth = function(e) return _G.Animals[e].health end
_G.PedKillers, _G.PlayerPeds = {}, {}
_G.GetPedSourceOfDeath = function(e) return (_G.Animals[e] and _G.Animals[e].killer) or _G.PedKillers[e] or 0 end
_G.IsPedAPlayer = function(e) return _G.PlayerPeds[e] == true end
_G.Entity = function(e)
    _G.Animals[e].bag = _G.Animals[e].bag or {}
    local bag = _G.Animals[e].bag
    return { state = setmetatable({ set = function(_, k, v) bag[k] = v end }, { __index = bag }) }
end
_G.GetVehicleEngineHealth = function(e) return _G.Vehicles[e].engine end
_G.GetVehicleBodyHealth = function(e) return _G.Vehicles[e].body end
_G.GetPedInVehicleSeat = function(e, seat)
    local v = _G.Vehicles[e]
    if seat and seat ~= -1 then return v.seats and v.seats[seat] or 0 end
    return v.driver or 0
end
_G.GetVehiclePedIsIn = function(ped) return _G.PedVehicle and _G.PedVehicle[ped] or 0 end
_G.SetPedIntoVehicle = function(ped, vehicle, seat)
    _G.PedVehicle = _G.PedVehicle or {}
    _G.PedVehicle[ped] = vehicle
    _G.Seated = { ped = ped, vehicle = vehicle, seat = seat }
end
_G.joaat = function(name) local h = 5381; for i = 1, #name do h = (h * 33 + name:byte(i)) % 4294967296 end; return h end

_G.GetVehicleNumberPlateText = function(e) return (_G.Vehicles[e] or {}).plate end
_G.Deleted = {}
_G.Spawned = {}
_G.CreateVehicle = function(hash)
    local id = 7000 + #_G.Spawned + 1
    _G.Spawned[#_G.Spawned + 1] = id
    _G.Vehicles[id] = { body = 1000.0, engine = 1000.0 }
    return id
end
_G.MockCreateVehicle = _G.CreateVehicle
_G.NetworkGetNetworkIdFromEntity = function(e) return e end
_G.SetVehicleNumberPlateText = function(e, text) if _G.Vehicles[e] then _G.Vehicles[e].plate = text end end
_G.SetVehicleDoorsLocked = function(e, state) if _G.Vehicles[e] then _G.Vehicles[e].locked = state end end
_G.DeleteEntity = function(e) _G.Deleted[#_G.Deleted + 1] = e; _G.Vehicles[e] = nil end

_G.Dropped = {}
_G.DropPlayer = function(id, reason) _G.Dropped[#_G.Dropped + 1] = { id = id, reason = reason } end

-- Not real JSON: a Lua literal round trip is enough for the flat tables the tests store.
_G.json = _G.json or {
    encode = function(v)
        if type(v) ~= 'table' then return tostring(v) end
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = ('%s=%s'):format(k, tostring(x)) end
        table.sort(parts)
        return '{' .. table.concat(parts, ',') .. '}'
    end,
    decode = function(s)
        local f = load('return ' .. tostring(s), 'json', 't', {})
        if not f then error('bad json') end
        return f()
    end,
}
_G.GetEntityHeading = function() return 90.0 end
