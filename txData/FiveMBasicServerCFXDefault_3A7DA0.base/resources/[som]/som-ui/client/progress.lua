-- Progress: the authoritative state, and the drawing.
--
-- This resource holds the state rather than the shim, and that is the whole
-- point. ox_lib serialised every progress bar through the single ox_lib
-- resource, so two resources could never draw at once. A shim keeping its state
-- in a local would give every consumer its own copy, and som-police and
-- som-compat would happily run two bars over one on-screen element, each
-- hiding the other's.
--
-- So: one claim, one token, one bar. The blocking half lives in
-- client/progressbar.lua and is loaded BY consumers, because it has to yield in
-- their context. See that file's header.
--
-- Never takes NUI focus. The player is mid-action and must keep the mouse.

local MIN_DURATION = 100
local MAX_DURATION = 600000

local playerState = LocalPlayer.state

local activeToken = nil
local activeCancellable = false
local cancelRequested = false
local previousInvBusy = nil
local nextToken = 0

---Reserves the bar without drawing anything.
---
---Split from showing it so a caller can stream its animation and prop first and
---only then start the countdown. Drawing at claim time made the bar finish up to
---two seconds before the action did, on any dict not already in memory.
---@return number|nil token, or nil if another resource holds the bar
local function claim()
    if activeToken then return nil end

    nextToken = nextToken + 1
    activeToken = nextToken
    activeCancellable = false
    cancelRequested = false

    -- ox_lib set this for the duration of every bar and ox_inventory mirrors it
    -- to block item use, the weapon loop and the inventory itself. Dropping it
    -- would have let a player eat, drink or draw a weapon mid-search.
    previousInvBusy = playerState.invBusy
    playerState.invBusy = true

    return activeToken
end

---@param token number
---@param label string
---@param duration number milliseconds
---@param canCancel boolean|nil
local function show(token, label, duration, canCancel)
    if token ~= activeToken then return end

    duration = tonumber(duration) or 1000
    if duration < MIN_DURATION then duration = MIN_DURATION end
    if duration > MAX_DURATION then duration = MAX_DURATION end

    activeCancellable = canCancel == true

    SendNUIMessage({
        action = 'progress:start',
        label = type(label) == 'string' and label or '',
        duration = duration,
        canCancel = activeCancellable,
    })
end

---@param token number
---@param cancelled boolean|nil
local function release(token, cancelled)
    -- A stale token means a bar that has already been superseded. Ignoring it is
    -- what stops a short action's cleanup from tearing down a longer one.
    if token ~= activeToken then return end

    activeToken = nil
    activeCancellable = false
    cancelRequested = false

    playerState.invBusy = previousInvBusy
    previousInvBusy = nil

    SendNUIMessage({
        action = 'progress:stop',
        cancelled = cancelled == true,
    })
end

---@param token number
---@return boolean
local function isCancelled(token)
    return token == activeToken and cancelRequested
end

---@param force boolean|nil ignore whether the bar advertised itself cancellable
local function requestCancel(force)
    if not activeToken then return end
    if not force and not activeCancellable then return end

    cancelRequested = true
end

---@return boolean
local function isActive()
    return activeToken ~= nil
end

exports('progressClaim', claim)
exports('progressShow', show)
exports('progressRelease', release)
exports('progressCancelled', isCancelled)
exports('progressCancel', requestCancel)

-- Read by the shim's lib.progressActive, so every resource gets one truthful
-- answer instead of its own private one.
exports('progressActive', isActive)

-- The cancel key.
--
-- A keybind rather than a polled control index, matching ox_lib, so it appears
-- in the FiveM keybind menu and the player can rebind it. ox_lib still has its
-- own 'cancelprogress' on X; that one now never fires, because ox_lib's own
-- progress state is always empty once the shim is in place.
RegisterCommand('somcancelprogress', function()
    requestCancel(false)
end, false)

RegisterKeyMapping('somcancelprogress', 'Cancel current action', 'keyboard', 'x')

-- A restart while a bar is up would otherwise leave it painted there forever and
-- leave invBusy stuck true, which silently disables item use for the rest of the
-- session.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not activeToken then return end

    release(activeToken, true)
end)
