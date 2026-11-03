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
_G.vec4 = vec4

-- Boot-time CreateThread bodies (seeding/retiring config rows) never run;
-- tests seed the fake DB directly instead, so a resource's load-time thread
-- doesn't need a working MySQL connection to not crash.
_G.CreateThread = function(fn) end
_G.Wait = function(ms) end
_G.SetTimeout = function(ms, fn) end
_G.AddEventHandler = function(name, fn) end
_G.RegisterNetEvent = function(name) end
_G.TriggerEvent = function(name, ...) end
_G.TriggerClientEvent = function(name, source, ...) end
_G.GetConvar = function(name, default) return default end

-- Player positions, settable per test via placePed() in run.lua.
_G.FakePeds = {}
_G.GetPlayerPed = function(source)
    return (_G.FakePeds[source] ~= nil) and source or 0
end
_G.GetEntityCoords = function(ped)
    return _G.FakePeds[ped] or vec3(0, 0, 0)
end
