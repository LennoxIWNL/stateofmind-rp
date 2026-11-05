-- Minimal stand-ins for the FiveM natives and globals this codebase calls.
-- Not an FXServer emulation: just enough that real resource files load and
-- run outside the game.

local function vec3(x, y, z)
    local v = { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
    return setmetatable(v, {
        __sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end,
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
_G.Teleports = {}
_G.SetEntityCoords = function(ped, x, y, z) _G.Teleports[#_G.Teleports + 1] = { ped = ped, x = x, y = y, z = z } end

_G.Vehicles = {}
_G.NetworkGetEntityFromNetworkId = function(netId) return _G.Vehicles[netId] and netId or 0 end
_G.DoesEntityExist = function(e) return _G.Vehicles[e] ~= nil end
_G.GetEntityType = function(e) return 2 end
_G.GetVehicleEngineHealth = function(e) return _G.Vehicles[e].engine end
_G.GetVehicleBodyHealth = function(e) return _G.Vehicles[e].body end
_G.GetPedInVehicleSeat = function(e) return _G.Vehicles[e].driver or 0 end
