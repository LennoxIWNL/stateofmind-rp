-- Notifications.
--
-- som-core and som-compat both fire som:client:notify, so this is the one
-- implementation behind that event. Replaces som-notify and som-lib.
--
-- Never takes NUI focus: a notification must not steal the player's mouse.

local VALID_TYPES = {
    success = true,
    error = true,
    info = true,
    warning = true,
}

-- 18 call sites across 10 som-* resources say 'inform' rather than 'info'.
-- Nothing looked broken, because an unknown type already falls back to 'info',
-- which is what they all wanted. That made the fallback load bearing: changing
-- it, or giving unknown types a distinct style, would have quietly restyled
-- eighteen notifications at once. Named here so the intent is explicit rather
-- than accidental.
local ALIASES = {
    inform = 'info',
}

local DEFAULT_DURATION = 4000
local MAX_DURATION = 15000

-- The sound half of a notification, by severity.
--
-- THIS IS THE FEEDBACK SWEEP FROM 18.11, and it is here rather than at each of
-- the call sites on purpose. The remaining list was garage take and store, the
-- mod bay, rentals, fines, doors and custody, and every one of those already
-- ends by notifying success or failure. Adding playSound next to each notify
-- would have been thirty edits that the thirty-first new feature would forget,
-- which is precisely how the gap opened in the first place. Sounding the
-- notification itself means an action is audible because it reported itself,
-- and every feature written from here is covered without being told to be.
--
-- Info is deliberately silent. Most notifications are informational chatter and
-- a server that pings for every line of text is worse than one that never
-- pings at all.
--
-- Warning borrows the error sound. It IS the "no" sound, which is what a
-- warning is saying, and inventing a second audio string to sit beside it would
-- put an unverified sound on the server for a distinction nobody has asked for.
local NOTIFY_SOUNDS = {
    success = 'success',
    error = 'error',
    warning = 'error',
}

---@param message string
---@param notifyType string|nil success, error, info, warning
---@param duration number|nil milliseconds
---@param silent boolean|nil suppress the sound, for callers that play their own
local function notify(message, notifyType, duration, silent)
    if type(message) ~= 'string' or message == '' then return end

    notifyType = ALIASES[notifyType] or notifyType
    if not VALID_TYPES[notifyType] then notifyType = 'info' end

    duration = tonumber(duration) or DEFAULT_DURATION
    if duration < 500 then duration = 500 end
    if duration > MAX_DURATION then duration = MAX_DURATION end

    SendNUIMessage({
        action = 'notify',
        message = message,
        type = notifyType,
        duration = duration,
    })

    -- `silent` is for callers that have already said it better. The armoury is
    -- the model: it distinguishes a $95,000 rifle from a free bandage with two
    -- different sounds, and a generic success on top would flatten a
    -- distinction it went to some trouble to make.
    if silent then return end

    local sound = NOTIFY_SOUNDS[notifyType]
    if sound and Feedback then Feedback.play(sound) end
end

-- One handler only. RegisterNetEvent with a function both marks the event as
-- net-callable AND registers the handler, so adding a second one with
-- AddEventHandler made every local TriggerEvent fire twice and show duplicate
-- notifications. This single registration already serves both local
-- TriggerEvent and server TriggerClientEvent.
RegisterNetEvent('som:client:notify', function(message, notifyType, duration, silent)
    notify(message, notifyType, duration, silent)
end)

exports('notify', notify)
