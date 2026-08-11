-- Dispatch: the call store, and the surface ps-mdt already knows how to talk to.
--
-- ps-mdt is preserved third-party code written against ps-dispatch, which does
-- not exist on this server. Rather than rewrite the MDT's dispatch page, this
-- resource answers to the name ps-dispatch: the export is published under that
-- resource name and the events ps-mdt fires are handled here.
--
-- SECURITY: a client reports that something happened; it never says what the
-- call says or who sees it. Coordinates come from the reporting player's ped
-- server side, the alert definition comes from config, and the recipient list
-- comes from som-core. A crafted report can, at worst, raise an alert about
-- itself at its own position.

local core = exports['som-core']

Dispatch = {}

-- Keyed by call id, because ps-mdt indexes calls[callid] rather than iterating
-- (ps-mdt/server/main.lua:1402). An array would break every waypoint.
local calls = {}
local nextId = 1

-- cooldowns[source][alertType] = expiry. Nested rather than a flat "src:type"
-- string key so a disconnect clears one table instead of scanning every entry
-- for a prefix, which mis-fires the moment player 1 and player 12 coexist.
local cooldowns = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Makes a string safe to hand to ps-mdt.
---
---ps-mdt builds its call list by INTERPOLATING these fields into an HTML string
---and appending it (`ui/app.js:4448`, `:4454`, `:4589`, `:4595`), not with
---textContent. A comment in this file used to claim the opposite, which is how
---this went unnoticed. The 911 message is free text typed by a player, so
---without this a player could type markup into a 911 call and run script in the
---MDT of every officer who opened it.
---
---Angle brackets are STRIPPED rather than entity-encoded, deliberately. Encoding
---is correct for the interpolated context but shows up as a literal `&amp;` in
---any consumer that uses textContent, which som-dispatch's own NUI will. Nobody
---needs a `<` in a 911 call, so removing them is safe in both places at once.
---@param value any
---@param maxLength number
---@return string|nil
local function sanitise(value, maxLength)
    if type(value) ~= 'string' then return nil end

    local clean = value
        :gsub('[<>]', '')
        -- Control characters, which serve no purpose in a call and can break
        -- the JSON boundary on the way out.
        :gsub('%c', ' ')
        :gsub('%s+', ' ')
        :gsub('^%s*(.-)%s*$', '%1')

    if clean == '' then return nil end

    return clean:sub(1, maxLength or 160)
end

---@param source number
---@param alertType string
---@return boolean whether this player may raise this alert right now
local function offCooldown(source, alertType)
    local def = Config.Alerts[alertType]
    if not def then return false end

    local now = os.time()
    local mine = cooldowns[source]

    if mine and mine[alertType] and now < mine[alertType] then return false end

    if not mine then
        mine = {}
        cooldowns[source] = mine
    end

    mine[alertType] = now + (def.cooldown or 10)
    return true
end

---Everyone currently able to receive a given call.
---@param jobs string[]
---@return table[] players
local function recipients(jobs)
    local out, seen = {}, {}

    for _, job in ipairs(jobs or {}) do
        -- On duty only. An officer who has clocked out is a civilian, and
        -- pushing calls at them defeats the point of a duty toggle.
        for _, player in ipairs(core:getPlayersByJob(job, true) or {}) do
            if not seen[player.source] then
                seen[player.source] = true
                out[#out + 1] = player
            end
        end
    end

    return out
end

---Drops calls that have aged out, and trims to the cap.
---
---Runs on write rather than on a timer: the store only grows when a call is
---added, so that is the only moment it can need trimming.
local function prune()
    local now = os.time()
    local live = {}

    for id, call in pairs(calls) do
        if now - call.createdAt < Config.CallLifetime then live[id] = call end
    end

    calls = live

    -- Oldest first, so a cap breach drops history rather than live incidents.
    local ids = {}
    for id in pairs(calls) do ids[#ids + 1] = id end

    if #ids <= Config.MaxCalls then return end

    table.sort(ids, function(a, b) return calls[a].createdAt < calls[b].createdAt end)

    for i = 1, #ids - Config.MaxCalls do calls[ids[i]] = nil end
end

-- ---------------------------------------------------------------------------
-- Raising a call
-- ---------------------------------------------------------------------------

---@param source number|nil the player it concerns, if any
---@param alertType string a key of Config.Alerts
---@param extra table|nil { coords, plate, model, weapon, information, ... }
---@return number|nil call id
function Dispatch.Create(source, alertType, extra)
    local def = Config.Alerts[alertType]
    if not def then return nil end

    extra = type(extra) == 'table' and extra or {}

    -- Position is taken from the ped, not from the report. A client that says
    -- it fired a gun at the airport while standing in Paleto reports Paleto.
    local coords = extra.coords

    if source and not coords then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then coords = GetEntityCoords(ped) end
    end

    if not coords then return nil end

    local player = source and core:getPlayer(source) or nil

    local id = nextId
    nextId = nextId + 1

    -- Which services this call belongs to, and the state of each.
    --
    -- Per service state on ONE record, rather than a queue per job. An incident
    -- is one incident: "PD cleared, EMS still transporting" has to be
    -- expressible, and two records with two numbers for one shooting cannot say
    -- it. This is the field that makes adding EMS a config change later rather
    -- than a second dispatch system.
    local services = {}

    for _, job in ipairs(def.jobs or {}) do
        services[job] = { status = 'open', closedAt = nil, disposition = nil }
    end

    local message = sanitise(extra.message, 160) or def.label

    -- The shape below is dictated by ps-mdt's UI, not chosen. See
    -- som-dispatch/README.md: `origin` is what SetNewWaypoint reads, and a call
    -- missing `jobs` throws in its renderer because that dereference has no
    -- optional chain.
    local call = {
        id = id,
        callId = id,
        priority = def.priority or 2,
        dispatchCode = def.code,
        code = def.code,
        dispatchMessage = message,
        message = message,

        -- Milliseconds. ps-mdt compares this against Date.now() and hides
        -- anything older than ten minutes, so seconds would hide every call.
        time = os.time() * 1000,
        createdAt = os.time(),

        coords = { x = coords.x, y = coords.y, z = coords.z },
        origin = { x = coords.x, y = coords.y },

        job = def.jobs,
        jobs = def.jobs,

        -- SOM's own. ps-mdt never reads it, so it costs nothing there, and it
        -- is what a close verb and a future EMS view key off.
        services = services,
        status = 'open',

        units = {},
        responses = {},

        -- Every one of these reaches ps-mdt's interpolated markup, so every one
        -- is sanitised. `street` and `weapon` come from the client, `plate` and
        -- `model` from a vehicle a player controls, and `information` embeds a
        -- character name chosen at creation.
        firstStreet = sanitise(extra.street, 64),
        street = sanitise(extra.street, 64),
        plate = sanitise(extra.plate, 12),
        model = sanitise(extra.model, 32),
        weapon = sanitise(extra.weapon, 48),
        gender = player and player.charinfo and player.charinfo.gender or nil,
        information = sanitise(extra.information, 160),
        automaticGunfire = extra.automatic == true,

        alertType = alertType,
        blip = def.blip,
    }

    calls[id] = call
    prune()

    for _, recipient in ipairs(recipients(def.jobs)) do
        -- ps-mdt's own live-call handler. Feeding it means the MDT updates
        -- without being reopened.
        TriggerClientEvent('dispatch:clNotify', recipient.source, call, id)
        TriggerClientEvent('som-dispatch:client:call', recipient.source, call)
    end

    return id
end

-- ---------------------------------------------------------------------------
-- Reports from clients
-- ---------------------------------------------------------------------------

RegisterNetEvent('som-dispatch:server:report', function(alertType, extra)
    local source = source

    if type(alertType) ~= 'string' then return end

    local def = Config.Alerts[alertType]
    if not def then return end

    -- Only alerts the DETECTION path is allowed to raise.
    --
    -- Without this, membership of Config.Alerts was the whole check, so a client
    -- could fire this event with 'emergencyCall' and raise a priority 1 call at
    -- its own position with no cooldown shared with the real 911 path. Anything
    -- a server-side mechanic owns (a bank alarm, an officer down, a store
    -- robbery) must never be reachable from here.
    if not def.reportable then return end

    local player = core:getPlayer(source)
    if not player then return end

    if not offCooldown(source, alertType) then return end

    -- The roll happens HERE. A client deciding whether its own gunshot was
    -- unlucky enough to report would simply always decide no.
    if math.random() > (Config.Alerts[alertType].chance or 1.0) then return end

    extra = type(extra) == 'table' and extra or {}

    Dispatch.Create(source, alertType, {
        street = type(extra.street) == 'string' and extra.street:sub(1, 64) or nil,
        plate = type(extra.plate) == 'string' and extra.plate:sub(1, 12) or nil,
        model = type(extra.model) == 'string' and extra.model:sub(1, 32) or nil,
        weapon = type(extra.weapon) == 'string' and extra.weapon:sub(1, 48) or nil,
        automatic = extra.automatic == true,
        -- Scatter is applied server side for the same reason the roll is.
        coords = extra.scatter and (function()
            local ped = GetPlayerPed(source)
            if not ped or ped == 0 then return nil end

            local at = GetEntityCoords(ped)
            local spread = Config.SuppressedScatter

            return vector3(
                at.x + math.random(-spread, spread),
                at.y + math.random(-spread, spread),
                at.z)
        end)() or nil,
    })
end)

---A deliberate call from a civilian, rather than something detected.
---
---Unlike the detected alerts this always goes through: a person choosing to
---ring the police is not something to roll a chance on. The message is theirs,
---so it is length-capped and never rendered as markup by ps-mdt's UI (which
---uses textContent).
RegisterNetEvent('som-dispatch:server:emergency', function(message)
    local source = source

    if type(message) ~= 'string' then return end

    message = message:gsub('%s+', ' '):gsub('^%s', ''):sub(1, 160)
    if #message < 3 then return end

    local player = core:getPlayer(source)
    if not player then return end

    if not offCooldown(source, 'emergencyCall') then
        return TriggerClientEvent('som:client:notify', source,
            'You have already called that in', 'error')
    end

    local id = Dispatch.Create(source, 'emergencyCall', {
        message = ('911: %s'):format(message),
        information = ('Caller: %s %s'):format(
            player.charinfo.firstname, player.charinfo.lastname),
    })

    TriggerClientEvent('som:client:notify', source,
        id and 'Your call has been passed to dispatch' or 'That could not be sent',
        id and 'success' or 'error')
end)

-- ---------------------------------------------------------------------------
-- The ps-dispatch surface
--
-- `provide` only satisfies dependency checks; it does not forward exports. The
-- __cfx_export_<resource>_<name> event is the actual mechanism, the same one
-- som-compat uses to answer as qb-core.
-- ---------------------------------------------------------------------------

local function publish(name, fn)
    AddEventHandler(('__cfx_export_ps-dispatch_%s'):format(name), function(setCB)
        setCB(fn)
    end)

    exports(name, fn)
end

publish('GetDispatchCalls', function()
    return calls
end)

---The catch-all other resources call.
---
---SERVER side only. A resource calling this has already been trusted by being
---started, so it may name the alert definition and supply coordinates. The
---definition still decides priority, routing and the blip: a caller may say
---WHAT happened, never who hears about it or how loudly.
---
---It used to hard-code `emergencyCall` and keep only message and coords, which
---meant every integration collapsed into a 911 and ps-mdt's own eleven field
---payload was thrown away.
publish('CustomAlert', function(data)
    if type(data) ~= 'table' then return end

    -- Named definition if the caller has one, 911 otherwise. Never a definition
    -- the caller invented.
    local alertType = type(data.alert) == 'string' and Config.Alerts[data.alert]
        and data.alert or 'emergencyCall'

    local coords = data.coords

    if type(coords) == 'table' and coords.x and coords.y then
        coords = vector3(coords.x + 0.0, coords.y + 0.0, (coords.z or 0.0) + 0.0)
    else
        coords = nil
    end

    return Dispatch.Create(nil, alertType, {
        message = data.message or data.dispatchMessage or data.description,
        information = data.description or data.information,
        coords = coords,
        street = data.street or data.firstStreet,
        plate = data.plate,
        model = data.model or data.vehicle,
        weapon = data.weapon,
        automatic = data.automaticGunfire == true,
    })
end)

-- ---------------------------------------------------------------------------
-- The CLIENT half of the ps-dispatch surface
--
-- ps-mdt calls exports['ps-dispatch']:CustomAlert from the CLIENT
-- (client/main.lua:1132) for its traffic stop alert, and cdn-fuel expects a
-- client surface too. Nothing answered there, so those calls error.
--
-- A client caller is NOT trusted the way a server one is. This event takes the
-- text and nothing else: coordinates come from the caller's own ped inside
-- Dispatch.Create, the definition is fixed, and the same cooldown applies as a
-- typed 911. The worst a forged call can do is announce itself where it stands.
-- ---------------------------------------------------------------------------

RegisterNetEvent('som-dispatch:server:customAlert', function(payload)
    local source = source

    if type(payload) ~= 'table' then return end

    local player = core:getPlayer(source)
    if not player then return end

    -- Only jobs that respond may raise one of these, because every current
    -- client caller is an on-duty tool: a traffic stop, a plate scan.
    local job = player.job and player.job.name
    if not job or not Config.RespondingJobs[job] then return end

    if not offCooldown(source, 'emergencyCall') then return end

    Dispatch.Create(source, 'emergencyCall', {
        message = sanitise(payload.message or payload.dispatchMessage, 120),
        information = sanitise(payload.description, 160),
        street = sanitise(payload.street, 64),
        plate = sanitise(payload.plate, 12),
    })
end)

-- ---------------------------------------------------------------------------
-- Events ps-mdt fires at dispatch
--
-- These are plain server-side TriggerEvents in ps-mdt, not exports, so they are
-- handled rather than published. Each takes a callback ps-mdt uses to update
-- its UI, so returning the new count matters.
-- ---------------------------------------------------------------------------

---The identity of an attached unit.
---
---ps-mdt builds its unit payload with `cid` (server/main.lua:1441 and :1512),
---never `citizenid`. Comparing `citizenid` therefore compared nil against nil,
---which is TRUE, so the first unit in the list matched everybody: the second
---officer to attach was silently treated as already attached and never added,
---and any officer detaching removed whoever happened to be first instead of
---themselves.
---
---Exactly the class of fault as the `licences` spelling in 16.3, and hidden the
---same way, by a comparison that quietly succeeds on two nils.
---@param unit table|nil
---@return string|nil
local function unitKey(unit)
    if type(unit) ~= 'table' then return nil end
    return unit.cid or unit.citizenid
end

-- callid arrives from ps-mdt's NUI, which means it has crossed JSON and comes
-- back a STRING. Lua does not treat calls["3"] and calls[3] as the same key, so
-- without this coercion every attach, detach and response silently addressed a
-- call that did not exist and returned as if nothing was wrong.
local function callById(id)
    return calls[tonumber(id) or id]
end

AddEventHandler('dispatch:addUnit', function(callid, playerdata, cb)
    local call = callById(callid)
    if not call then return cb and cb(0) end

    local key = unitKey(playerdata)

    -- Without an identity there is no way to dedupe them now or remove them
    -- later, so refuse rather than add a unit that can never detach.
    if not key then return cb and cb(#call.units) end

    for _, unit in ipairs(call.units) do
        if unitKey(unit) == key then
            return cb and cb(#call.units)
        end
    end

    call.units[#call.units + 1] = playerdata
    if cb then cb(#call.units) end
end)

AddEventHandler('dispatch:removeUnit', function(callid, playerdata, cb)
    local call = callById(callid)
    if not call then return cb and cb(0) end

    local key = unitKey(playerdata)
    if not key then return cb and cb(#call.units) end

    for i, unit in ipairs(call.units) do
        if unitKey(unit) == key then
            table.remove(call.units, i)
            break
        end
    end

    if cb then cb(#call.units) end
end)

AddEventHandler('dispatch:sendCallResponse', function(src, callid, message, time, cb)
    local call = callById(callid)
    if not call then return cb and cb(false) end

    local player = core:getPlayer(src)
    if not player then return cb and cb(false) end

    call.responses[#call.responses + 1] = {
        name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        message = tostring(message):sub(1, 256),
        time = time,
    }

    if cb then cb(true) end
end)

-- ---------------------------------------------------------------------------
-- Exports for other som resources
-- ---------------------------------------------------------------------------

exports('alert', function(source, alertType, extra)
    return Dispatch.Create(source, alertType, extra)
end)

exports('getCalls', function() return calls end)

AddEventHandler('som:server:playerUnloaded', function(source)
    cooldowns[source] = nil
end)
