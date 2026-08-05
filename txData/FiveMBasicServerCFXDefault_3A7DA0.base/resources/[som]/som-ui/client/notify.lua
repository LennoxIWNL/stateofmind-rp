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

---@param message string
---@param notifyType string|nil success, error, info, warning
---@param duration number|nil milliseconds
local function notify(message, notifyType, duration)
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
end

-- One handler only. RegisterNetEvent with a function both marks the event as
-- net-callable AND registers the handler, so adding a second one with
-- AddEventHandler made every local TriggerEvent fire twice and show duplicate
-- notifications. This single registration already serves both local
-- TriggerEvent and server TriggerClientEvent.
RegisterNetEvent('som:client:notify', function(message, notifyType, duration)
    notify(message, notifyType, duration)
end)

exports('notify', notify)
