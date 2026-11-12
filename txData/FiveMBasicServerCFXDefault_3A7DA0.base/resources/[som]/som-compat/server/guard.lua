--- Authorising layer for third party events.
---
--- FiveM runs every handler of an event and nothing can stop another resource's
--- handler from outside (CancelEvent is advisory), and a third party's net events
--- trust whatever a client sends. So this file is listed FIRST in that resource's
--- own server_scripts. All scripts of a resource share one Lua state, so it runs
--- before the resource's own scripts and swaps the global RegisterNetEvent,
--- RegisterServerEvent and AddEventHandler for versions that wrap the handler of
--- a listed event in a check. A refused call never reaches the original handler.
--- No third party logic is edited; an upgrade only has to put the manifest line
--- back (LAUNCH-TODO.md).
---
--- The caller is always the `source` global at call time, never an argument. A
--- call with no player source (the server triggering its own event) passes.
--- Rules that change money, records or doors fail closed: an error in the rule
--- refuses the call. Rules marked `open` fail open and only log.
---
--- som-compat itself loads this file too, for the callback rules its qb shim uses.

SomGuard = {}

local Guard = SomGuard
local core = exports['som-core']

Guard.maxFine = 25000
Guard.fineBusiness = 'lspd'
Guard.supervisorGrade = 5

local logged, loggedCount = {}, 0
local pickable = {}

---Logs a refusal, at most once per event and player every 30 seconds.
function Guard.log(name, id, why)
    local key = name .. ':' .. tostring(id)
    local now = GetGameTimer()
    if logged[key] and now - logged[key] < 30000 then return end

    if loggedCount > 1000 then logged, loggedCount = {}, 0 end
    if not logged[key] then loggedCount = loggedCount + 1 end
    logged[key] = now
    print(('[som-compat] %s: %s from %s (%s)'):format(GetCurrentResourceName(), name, tostring(id), why))
end

local function job(player) return player and player.job and player.job.name end
local function police(player) return job(player) == 'police' end
local function responder(player) return police(player) or job(player) == 'ambulance' end

local function int(value, low, high)
    local n = tonumber(value)
    if n and n % 1 == 0 and n >= low and n <= high then return n end
end

local function text(value, max) return type(value) == 'string' and #value >= 1 and #value <= max end

local function near(a, b, distance)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= distance
end

---A table of at most `limit` boolean values under short text keys.
function Guard.flags(value, limit)
    if type(value) ~= 'table' then return false end

    local n = 0
    for k, v in pairs(value) do
        n = n + 1
        if n > limit or type(k) ~= 'string' or #k > 24 or type(v) ~= 'boolean' then return false end
    end
    return true
end

local function list(value, limit)
    if value == nil then return true end
    if type(value) ~= 'table' then return false end

    local n = 0
    for _ in pairs(value) do
        n = n + 1
        if n > limit then return false end
    end
    return true
end

---A fine against a named citizen, written by a police officer.
local function fine(_, player, citizenId, amount, incident)
    return police(player) and text(citizenId, 16) and int(amount, 1, Guard.maxFine) ~= nil
        and (type(incident) == 'number' or text(incident, 24)) and core:getPlayerByCitizenId(citizenId) ~= nil
end

---Both ends of a radar relay are police and close together.
local function radar(src, player, target)
    local id = int(target, 1, 65535)
    return id ~= nil and police(player) and police(core:getPlayer(id)) and near(src, id, 40.0)
end

local function stress(_, player, amount) return player ~= nil and type(amount) == 'number' and amount >= 0 and amount <= 50 end

-- fn(src, player, ...) returns true to allow. `anon` allows a caller with no
-- loaded character, `open` fails open on an error in the rule.
Guard.rules = {
    ['mdt:server:removeMoney'] = { fn = fine },
    ['mdt:server:giveCitationItem'] = { fn = fine },
    ['mdt:server:saveProfile'] = {
        fn = function(_, player, _, information, cid, _, _, tags, gallery, licenses)
            return police(player) and text(cid, 16) and (information == nil or text(information, 20000))
                and list(tags, 100) and list(gallery, 100) and (licenses == nil or Guard.flags(licenses, 8))
        end,
    },
    ['mdt:server:updateLicense'] = {
        fn = function(_, player, cid, kind, status)
            return police(player) and text(cid, 16) and text(kind, 24) and (status == 'give' or status == 'revoke')
        end,
    },
    ['mdt:server:setCallsign'] = {
        fn = function(_, player, cid, callsign)
            if type(callsign) ~= 'string' and type(callsign) ~= 'number' then return false end

            callsign = tostring(callsign)
            return responder(player) and text(cid, 16) and #callsign <= 12 and #callsign >= 1
                and (cid == player.citizenid or (tonumber(player.job.grade) or 0) >= Guard.supervisorGrade)
        end,
    },
    ['mdt:server:handleExistingConvictions'] = {
        fn = function(_, player, data) return police(player) and type(data) == 'table' and text(data.Cid, 16) end,
    },
    ['mdt:server:removeIncidentCriminal'] = {
        fn = function(_, player, cid) return police(player) and text(cid, 16) end,
    },
    ['psmdt-mugshot:server:MDTupload'] = {
        fn = function(_, player, cid, urls) return police(player) and text(cid, 16) and type(urls) == 'table' and list(urls, 10) end,
    },
    ['cqc-mugshot:server:triggerSuspect'] = {
        fn = function(src, player, suspect)
            local id = int(suspect, 1, 65535)
            return police(player) and id ~= nil and core:getPlayer(id) ~= nil and near(src, id, 15.0)
        end,
    },
    ['mdt:server:setRadio'] = {
        fn = function(_, player, cid, radio) return responder(player) and text(cid, 16) and int(radio, 0, 9999) ~= nil end,
    },
    ['mdt:server:registerweapon'] = {
        fn = function(_, player, serial) return police(player) and text(serial, 64) end,
    },
    -- The MDT writes its own log lines with TriggerEvent, which keeps the `source` of the client event it
    -- runs inside, so this cannot be refused outright. It is limited to responders and bounded text.
    ['mdt:server:AddLog'] = { fn = function(_, player, line) return responder(player) and text(line, 500) end },
    ['ps-mdt:dispatchStatus'] = {
        fn = function(_, player, running) return responder(player) and type(running) == 'boolean' end,
    },

    -- The client chooses `lockpick`, and the server then only checks that the player carries a
    -- lockpick, for any door. A lockpick is accepted only on a door that is flagged lockpickable.
    ['ox_doorlock:setState'] = {
        anon = true,
        fn = function(_, _, id, _, lockpick)
            if not lockpick then return true end

            id = int(id, 1, 2147483647)
            if not id or not exports.ox_doorlock:getDoor(id) then return false end

            -- Only doors ox_doorlock knows are looked up, so the cache is as big as the door list.
            local now = GetGameTimer()
            local cached = pickable[id]
            if cached and now - cached.at < 30000 then return cached.ok end

            local ok = MySQL.scalar.await(
                "SELECT 1 FROM ox_doorlock WHERE id = ? AND JSON_EXTRACT(data, '$.lockpick') = 'true'", { id }) ~= nil
            pickable[id] = { ok = ok, at = now }
            return ok
        end,
    },

    ['hud:server:GainStress'] = { fn = stress, open = true },
    ['hud:server:RelieveStress'] = { fn = stress, open = true },
}

for _, name in ipairs({
    'sendPowerState', 'sendAntennaPowerState', 'sendAntennaMode', 'sendLockAntennaSpeed', 'sendLockCameraPlate',
    'requestRadarData', 'sendRadarDataForPassenger', 'sendUpdatedOMData',
}) do
    Guard.rules['wk_wars2x_sync:' .. name] = { fn = radar, open = true }
end

-- Callbacks the qb shim registers for ps-mdt: fn(source, player) returns true to allow.
Guard.callbacks = {
    ['mdt:server:getWarrants'] = function(_, player) return police(player) end,
    ['mdt:server:GetPlayerSourceId'] = function(_, player) return police(player) end,
}

---Wraps a handler of a listed event. Anything else is returned untouched.
function Guard.wrap(name, handler)
    local rule = Guard.rules[name]
    if not rule or type(handler) ~= 'function' then return handler end

    return function(...)
        local id = tonumber(source)
        if not id then return handler(...) end

        local ok, allowed = pcall(function(...)
            local player = core:getPlayer(id)
            if not player and not rule.anon then return false end
            return rule.fn(id, player, ...)
        end, ...)

        if not ok then
            Guard.log(name, id, 'guard error: ' .. tostring(allowed))
            allowed = rule.open == true
        elseif not allowed then
            Guard.log(name, id, 'refused')
        end
        if not allowed then return end

        -- The rule may have yielded, and `source` is only reliable at handler entry.
        source = id
        return handler(...)
    end
end

---Resources that must have installed this guard, and the ones that said so.
Guard.expected = { 'ps-mdt', 'ox_doorlock', 'wk_wars2x', 'ps-hud' }
Guard.installed = {}

---Started resources from the expected list that never announced the guard.
function Guard.missing()
    local out = {}
    for _, name in ipairs(Guard.expected) do
        if GetResourceState(name) == 'started' and not Guard.installed[name] then out[#out + 1] = name end
    end
    return out
end

---Swaps the three registration functions of the resource this runs in.
function Guard.install()
    TriggerEvent('som-compat:guardInstalled', GetCurrentResourceName())

    for _, fname in ipairs({ 'RegisterNetEvent', 'RegisterServerEvent', 'AddEventHandler' }) do
        local original = _ENV[fname]
        _ENV[fname] = function(name, handler, ...)
            return original(name, Guard.wrap(name, handler), ...)
        end
    end
end

if GetCurrentResourceName() ~= 'som-compat' then
    Guard.install()
else
    AddEventHandler('som-compat:guardInstalled', function(name) Guard.installed[name] = true end)

    -- An upgrade that rewrites a manifest drops the line that loads this file, and nothing else would say so.
    CreateThread(function()
        Wait(20000)
        for _, name in ipairs(Guard.missing()) do
            print(('[som-compat] WARNING: %s is running without the event guard (put its fxmanifest line back and restart it)'):format(name))
        end
    end)
end
