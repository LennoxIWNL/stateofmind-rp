-- interact-sound, with its net events validated.
--
-- PATCHED for State of Mind RP. See AUDIT.md 19.4 item 3 for why.
--
-- Every handler here took a filename, a volume and, in one case, a target
-- player straight from the client and passed all three on untouched. That gave
-- any client three primitives worth having:
--
--   PlayOnOne          play any file at any volume in ONE named player's ears
--   PlayOnAll          play any file at any volume in EVERY player's ears
--   PlayWithinDistance the same, to everyone inside a radius they also chose
--
-- The distance limit that does exist was defeated by an accident: the file
-- registered PlayWithinDistance TWICE, and RegisterNetEvent adds a handler
-- rather than replacing one, so both ran. The first had no limit at all, which
-- meant the checked version could refuse a request that the unchecked version
-- standing next to it had already granted.
--
-- Nothing in this file changes what a legitimate caller sends, so the shipped
-- callers (qb-smallresources' seatbelt, r14-evidence, cdn-fuel) keep working
-- unchanged. Note that interact-sound is not currently ensured in som.cfg;
-- this is patched on its own merits, before it is.

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

-- Loudest a client may ask for.
--
-- Every real caller in the tree asks for between 0.1 and 0.4, so this is well
-- above legitimate use and well below "in your ears". Howler and the Audio
-- element both take 0 to 1, and out of range values throw rather than clamp,
-- so an unvalidated volume was a way to silently kill the NUI as well as a way
-- to shout through it.
local MAX_VOLUME = 0.6
local DEFAULT_VOLUME = 0.3

-- Furthest a client may ask to be heard from. Unchanged from the value the
-- resource already used, so nothing that works today stops working.
local MAX_DISTANCE = 300.0

-- Plays allowed per player per window. A validated sound spammed sixty times a
-- second is still a denial of service, so the rate is part of the validation
-- rather than a separate concern.
local RATE_LIMIT = 8
local RATE_WINDOW = 3000

---Sound names are used to build a URL inside the NUI: './sounds/' .. name ..
---'.ogg'. Anything outside this set can leave that directory, so the pattern is
---the whole of the path safety: no slashes, no dots, no backslashes, no colons,
---nothing percent encoded.
---@param name any
---@return string|nil
local function safeSound(name)
    if type(name) ~= 'string' then return nil end
    if #name < 1 or #name > 48 then return nil end
    if not name:match('^[%w_%-]+$') then return nil end

    return name
end

---@param volume any
---@return number
local function safeVolume(volume)
    local value = tonumber(volume)
    if not value or value ~= value then return DEFAULT_VOLUME end

    if value < 0 then return 0 end
    if value > MAX_VOLUME then return MAX_VOLUME end

    return value
end

---@param distance any
---@return number|nil
local function safeDistance(distance)
    local value = tonumber(distance)
    if not value or value ~= value then return nil end
    if value <= 0 or value > MAX_DISTANCE then return nil end

    return value
end

-- rate[source] = { count = number, since = ms }
local rate = {}

---@param source number
---@return boolean allowed
local function allowed(source)
    local now = GetGameTimer()
    local entry = rate[source]

    if not entry or now - entry.since > RATE_WINDOW then
        rate[source] = { count = 1, since = now }
        return true
    end

    entry.count = entry.count + 1

    return entry.count <= RATE_LIMIT
end

AddEventHandler('playerDropped', function()
    rate[source] = nil
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

---Play in one named player's ears.
---
---The target still comes from the client, because the shipped callers rely on
---that and there is no way to derive it. What it can no longer be is an
---arbitrary number: it has to name a player who is actually connected, so this
---cannot be used to probe for valid ids either.
RegisterNetEvent('InteractSound_SV:PlayOnOne', function(clientNetId, soundFile, soundVolume)
    local src = source
    if not allowed(src) then return end

    local sound = safeSound(soundFile)
    if not sound then return end

    local target = tonumber(clientNetId)
    if not target or target <= 0 then return end

    -- GetPlayerName returns nil for an id nobody holds.
    if not GetPlayerName(target) then return end

    TriggerClientEvent('InteractSound_CL:PlayOnOne', target, sound, safeVolume(soundVolume))
end)

---Play in the caller's own ears. Nothing to validate but the sound itself: the
---target is the source, which the client does not get to choose.
RegisterNetEvent('InteractSound_SV:PlayOnSource', function(soundFile, soundVolume)
    local src = source
    if not allowed(src) then return end

    local sound = safeSound(soundFile)
    if not sound then return end

    TriggerClientEvent('InteractSound_CL:PlayOnOne', src, sound, safeVolume(soundVolume))
end)

---Play in EVERY player's ears.
---
---Left registered, because removing an event a third party might call is a
---worse failure than a loud noise, but nothing in this tree calls it: the only
---callers of interact-sound use PlayWithinDistance and PlayOnSource. It is
---therefore rate limited hardest, and it is the first thing to delete outright
---if it is ever seen being used.
RegisterNetEvent('InteractSound_SV:PlayOnAll', function(soundFile, soundVolume)
    local src = source
    if not allowed(src) then return end

    local sound = safeSound(soundFile)
    if not sound then return end

    TriggerClientEvent('InteractSound_CL:PlayOnAll', -1, sound, safeVolume(soundVolume))
end)

---Play for everyone within a radius of the caller.
---
---ONE registration. There were two, and the unchecked one ran first.
RegisterNetEvent('InteractSound_SV:PlayWithinDistance', function(maxDistance, soundFile, soundVolume)
    local src = source
    if not allowed(src) then return end

    local sound = safeSound(soundFile)
    if not sound then return end

    local distance = safeDistance(maxDistance)
    if not distance then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    -- The COORDS are derived here rather than accepted, which they already were
    -- and which is the one thing the original got right: a client cannot claim
    -- to be somewhere it is not in order to be heard there.
    TriggerClientEvent('InteractSound_CL:PlayWithinDistance', -1,
        GetEntityCoords(ped), distance, sound, safeVolume(soundVolume))
end)
