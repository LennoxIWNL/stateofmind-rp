-- lib.progressBar, replaced with som-ui's.
--
-- NOT loaded by som-ui, and NOT in its client_scripts. Consumers load it
-- themselves, after ox_lib:
--
--     client_scripts {
--         '@som-ui/client/progressbar.lua',
--         'client/whatever.lua',
--     }
--
-- For that include to resolve, this path is listed in som-ui's files{} block.
-- ox_lib does exactly the same with its own init.lua. Without that entry the
-- client never receives the file and every consumer fails to start.
--
-- It has to run inside the calling resource for two reasons. ox_lib gives every
-- resource its own `lib` table, so overriding it from som-ui would only ever
-- override som-ui's own. And progressBar BLOCKS: it yields until the action
-- finishes, and an export cannot yield across a resource boundary, so the
-- waiting has to happen where the caller is.
--
-- The STATE, though, lives in som-ui, not here. A local flag per resource would
-- let som-police and som-compat each believe they owned the one on-screen bar.
--
-- Behaviour is ported from ox_lib's own progress.lua rather than approximated,
-- because callers depend on details that are easy to miss: it interrupts on
-- ragdoll, cuffs, falling and swimming as well as death; it sets invBusy so
-- ox_inventory locks out item use; it QUEUES a second request rather than
-- refusing it; and StopAnimTask needs a Wait(0) after it or it does not take.

if not lib then return end

-- Kept so a stopped som-ui degrades to ox_lib's bar rather than taking custody,
-- searches and every preserved resource down with it.
local oxProgressBar = lib.progressBar
local oxProgressCircle = lib.progressCircle

local ui = exports['som-ui']

-- Only ever one at a time per resource, because som-ui only issues one token at
-- a time across the whole client. Held so onResourceStop can hand it back.
local heldToken = nil

local function uiReady()
    return GetResourceState('som-ui') == 'started'
end

---Ported verbatim from ox_lib. Callers rely on all five, not just death.
---@param data table
---@return boolean
local function interrupted(data)
    if not data.useWhileDead and IsEntityDead(cache.ped) then return true end
    if not data.allowRagdoll and IsPedRagdoll(cache.ped) then return true end
    if not data.allowCuffed and IsPedCuffed(cache.ped) then return true end
    if not data.allowFalling and IsPedFalling(cache.ped) then return true end
    if not data.allowSwimming and IsPedSwimming(cache.ped) then return true end

    return false
end

-- ox_lib's exact control set. Deliberately not a broader one: widening it would
-- change how every existing action feels, and disable.combat in particular has
-- to be DisablePlayerFiring rather than a list of controls, or the player can
-- still shoot.
local CONTROLS = {
    LOOK_LR = 1,
    LOOK_UD = 2,
    SPRINT = 21,
    AIM = 25,
    MOVE_LR = 30,
    MOVE_UD = 31,
    DUCK = 36,
    VEH_MOVE_LEFT = 63,
    VEH_MOVE_RIGHT = 64,
    VEH_ACCELERATE = 71,
    VEH_BRAKE = 72,
    VEH_EXIT = 75,
    VEH_MOUSE_OVERRIDE = 106,
}

---@param disable table
local function applyDisable(disable)
    if disable.mouse then
        DisableControlAction(0, CONTROLS.LOOK_LR, true)
        DisableControlAction(0, CONTROLS.LOOK_UD, true)
        DisableControlAction(0, CONTROLS.VEH_MOUSE_OVERRIDE, true)
    end

    if disable.move then
        DisableControlAction(0, CONTROLS.SPRINT, true)
        DisableControlAction(0, CONTROLS.MOVE_LR, true)
        DisableControlAction(0, CONTROLS.MOVE_UD, true)
        DisableControlAction(0, CONTROLS.DUCK, true)
    end

    if disable.sprint and not disable.move then
        DisableControlAction(0, CONTROLS.SPRINT, true)
    end

    if disable.car then
        DisableControlAction(0, CONTROLS.VEH_MOVE_LEFT, true)
        DisableControlAction(0, CONTROLS.VEH_MOVE_RIGHT, true)
        DisableControlAction(0, CONTROLS.VEH_ACCELERATE, true)
        DisableControlAction(0, CONTROLS.VEH_BRAKE, true)
        DisableControlAction(0, CONTROLS.VEH_EXIT, true)
    end

    if disable.combat then
        DisableControlAction(0, CONTROLS.AIM, true)
        DisablePlayerFiring(cache.playerId, true)
    end
end

---@param anim table
local function startAnim(anim)
    if anim.dict then
        -- ox_lib's own loader: it waits, times out and errors rather than
        -- spinning forever on a dict that will never stream.
        local ok = pcall(lib.requestAnimDict, anim.dict)
        if not ok then return end

        TaskPlayAnim(cache.ped, anim.dict, anim.clip,
            anim.blendIn or 3.0, anim.blendOut or 1.0,
            anim.duration or -1, anim.flag or 49,
            anim.playbackRate or 0, anim.lockX, anim.lockY, anim.lockZ)

        RemoveAnimDict(anim.dict)
    elseif anim.scenario then
        TaskStartScenarioInPlace(cache.ped, anim.scenario, 0,
            anim.playEnter == nil or anim.playEnter)
    end
end

---@param anim table
local function stopAnim(anim)
    if anim.dict then
        StopAnimTask(cache.ped, anim.dict, anim.clip, 1.0)
        -- Required. Without it the stop is itself cancelled and a looping
        -- flag-49 animation outlives the bar. ox_lib carries the same comment.
        Wait(0)
    else
        ClearPedTasks(cache.ped)
    end
end

-- Guarantees the token goes back even if something below throws. Without this a
-- single error would leave som-ui permanently claimed and silently kill every
-- progress bar on the client, in every resource, until a restart.
local GUARD = {
    __close = function(self)
        heldToken = nil
        pcall(function() ui:progressRelease(self.token, self.cancelled) end)
    end,
}

---@param data table ox_lib's ProgressProps shape
---@return boolean|nil true completed, false cancelled, nil refused before it began
local function run(data)
    if type(data) ~= 'table' then return false end

    -- Checked before anything is claimed, matching ox_lib, which returns nil
    -- rather than false when the action never started.
    if interrupted(data) then return nil end

    -- Queue, do not refuse. ox_lib waits here, and som-compat in particular
    -- shares one bar across every preserved resource, so refusing would fire
    -- spurious onCancel callbacks the originals never saw.
    local token = ui:progressClaim()

    while not token do
        Wait(0)
        token = ui:progressClaim()
    end

    heldToken = token

    local guard <close> = setmetatable({ token = token, cancelled = false }, GUARD)

    -- Props go through ox_lib's own networked prop system, so other players see
    -- them. Reimplementing it here would have made SOM props invisible to
    -- everyone but the person holding them.
    if data.prop then TriggerServerEvent('ox_lib:progressProps', data.prop) end

    local anim = data.anim
    if anim then startAnim(anim) end

    local duration = tonumber(data.duration) or 1000

    -- Shown only now, after the dict and the prop have streamed, so the bar and
    -- the action start together.
    ui:progressShow(token, data.label, duration, data.canCancel == true)

    local disable = data.disable
    local startTime = GetGameTimer()

    -- Per frame, which the no-busy-loop rule in CLAUDE.md exempts: disabling
    -- controls has to happen every frame or it does not happen at all.
    while true do
        if disable then applyDisable(disable) end

        if interrupted(data) then
            guard.cancelled = true
            break
        end

        if ui:progressCancelled(token) then
            guard.cancelled = true
            break
        end

        if GetGameTimer() - startTime >= duration then break end

        Wait(0)
    end

    if data.prop then TriggerServerEvent('ox_lib:progressProps', nil) end
    if anim then stopAnim(anim) end

    return not guard.cancelled
end

---Blocks until the action finishes, is cancelled, or is interrupted.
---@param data table
---@return boolean|nil completed
function lib.progressBar(data)
    if not uiReady() then return oxProgressBar(data) end
    return run(data)
end

---The same bar. SOM draws one progress shape, so a caller asking for a circle
---gets the bar rather than a second, inconsistent style.
---@param data table
---@return boolean|nil completed
function lib.progressCircle(data)
    if not uiReady() then
        if oxProgressCircle then return oxProgressCircle(data) end
        return oxProgressBar(data)
    end

    return run(data)
end

---True while ANY resource is running a bar, not just this one.
---@return boolean
function lib.progressActive()
    if not uiReady() then return false end
    return ui:progressActive() == true
end

---Cancels the running bar regardless of whether it advertised itself
---cancellable, matching ox_lib. Unlike ox_lib this does not raise when nothing
---is running, because erroring on a redundant cancel helps nobody.
function lib.cancelProgress()
    if not uiReady() then return end
    ui:progressCancel(true)
end

-- Restarting a consumer mid-action would otherwise strand the bar on screen and
-- leave som-ui claimed forever, since the loop above dies with the resource and
-- the to-be-closed guard never runs.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not heldToken then return end

    pcall(function() ui:progressRelease(heldToken, true) end)
    heldToken = nil
end)
