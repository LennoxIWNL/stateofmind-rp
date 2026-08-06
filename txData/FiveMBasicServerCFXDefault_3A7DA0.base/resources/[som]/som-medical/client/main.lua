-- The downed state: what it looks and feels like.
--
-- Thin. It reports a death, then does what the server tells it. It never
-- decides that it is down, when it may get up, or what that costs.
--
-- Down is down: no crawl, no last stand, no getting up on your own. The ped is
-- on the floor, the player can talk, and the only input that does anything is
-- the one that accepts a hospital bed.

local core = exports['som-core']

local isDown = false
local downSince = 0

-- Seconds already served when this client was told it was down. Non-zero only
-- after a reconnect, and it is what makes the client agree with the server
-- about when treatment opens rather than starting its own two minutes.
local downElapsed = 0

local watching = false

-- Where the body fell. Everything that tries to move it is measured against
-- this, so a cancelled animation cannot become a step.
local anchor = nil

-- ---------------------------------------------------------------------------
-- Reporting a death
--
-- The gameplay event rather than a health poll: polling costs a thread forever
-- and still misses the frame a player dies and respawns in.
-- ---------------------------------------------------------------------------

-- Reported once per death. Cleared when the player is back up, so a second
-- death still reports, and set before the event is sent so the damage handler
-- and the poll below cannot both report the same death.
local reported = false

local function reportDeath()
    if isDown or reported then return end
    reported = true

    local weapon
    local ok, hash = pcall(GetPedCauseOfDeath, cache.ped)
    if ok and hash and hash ~= 0 then weapon = tostring(hash) end

    -- The server decides whether this becomes a downed state.
    TriggerServerEvent('som-medical:server:died', weapon)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if isDown or reported then return end
    if args[1] ~= cache.ped then return end

    -- WHICH ARGUMENT CARRIES THE FATAL FLAG IS DISPUTED, and this file is not
    -- going to settle it. The Cfx ped-money-drops sample and PolyZone both read
    -- args[4]; this resource shipped reading args[6] and was confirmed working
    -- in game; som-dispatch documents args[6] as the weapon hash. They cannot
    -- all be right, and picking one on reasoning rather than evidence is how a
    -- working system becomes dead code in a build bump.
    --
    -- So the argument is treated as a HINT and the PED is treated as the truth.
    -- IsPedDeadOrDying is not a decoding of anything: either the ped is dead or
    -- it is not.
    if args[4] ~= 1 and args[6] ~= 1 and not IsPedDeadOrDying(cache.ped, true) then
        return
    end

    reportDeath()
end)

-- The fallback the handover called for.
--
-- The damage event fires for damage. Drowning, a long fall, a scripted kill and
-- anything else that empties the health bar without a damage event attached
-- would otherwise produce the stock GTA death screen, which is precisely the
-- vanilla behaviour som-medical exists to replace.
--
-- Half a second, not a frame. This is a backstop for the rare path, and the
-- event catches the common one within the same tick.
CreateThread(function()
    while true do
        Wait(500)

        -- The ped is legitimately dead during character select and the switch
        -- into the world, and reporting then would down a player who has not
        -- spawned yet.
        if not isDown and not reported
            and core:isPlayerLoaded()
            and IsPedDeadOrDying(cache.ped, true) then
            reportDeath()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Being down
-- ---------------------------------------------------------------------------

-- Controls that survive being down.
--
-- LOOK_LR and LOOK_UD are the reason this is a list rather than a single key:
-- a player pinned on the floor with a frozen camera is looking at whatever the
-- fall happened to leave them pointing at, for up to ten minutes. Being able to
-- turn and watch what is happening to you is most of what makes the state
-- bearable, and it grants no ability to act.
local ALLOWED = {
    1,      -- INPUT_LOOK_LR
    2,      -- INPUT_LOOK_UD
    249,    -- INPUT_PUSH_TO_TALK
    46,     -- INPUT_TALK
}

---Puts the down animation back on the ped, and keeps it there.
---
---Called every frame on purpose. The dict is requested rather than waited on,
---so a slow stream costs a few frames of ragdoll instead of a hung thread.
---@param ped number
---@param first boolean whether this is the collapse rather than a re-assert
local function ensureAnim(ped, first)
    local anim = Config.DownAnim
    if not anim or not anim.dict then return end

    if IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then return end

    if not HasAnimDictLoaded(anim.dict) then
        RequestAnimDict(anim.dict)
        return
    end

    TaskPlayAnim(ped, anim.dict, anim.clip,
        first and (anim.blendIn or 2.0) or (anim.reblendIn or 8.0),
        anim.blendOut or 4.0,
        -1, anim.flag or 1, 0, false, false, false)
end

---Holds the ped on the floor.
---
---Per frame, which the no-busy-loop rule in CLAUDE.md exempts for exactly this
---reason: control disabling and animation re-assertion only work if they happen
---every frame. Anything slower IS the exploit window.
local function holdDown()
    if watching then return end
    watching = true

    CreateThread(function()
        local first = true

        while isDown do
            local ped = cache.ped

            -- Alive, so voice keeps working. A dead ped cannot talk, and
            -- talking is the entire point of this state.
            if GetEntityHealth(ped) < Config.DownedHealth then
                SetEntityHealth(ped, Config.DownedHealth)
            end

            if Config.InvincibleWhileDown then
                -- No second death. A body on the floor is not a killstreak.
                SetEntityInvincible(ped, true)
            end

            -- Ragdoll is now the enemy rather than the presentation. A car
            -- clipping the body, an explosion nearby or a stray shove would
            -- otherwise knock the ped out of the animation, and the recovery
            -- from a ragdoll is a stand up, which is a free revive.
            SetPedCanRagdoll(ped, false)

            ensureAnim(ped, first)
            first = false

            -- Put back where they fell.
            --
            -- The animation itself has a little root motion and a passing
            -- vehicle has a lot, but the case this exists for is the emote
            -- cancel keybind: RegisterKeyMapping commands are dispatched from
            -- the raw key, NOT through the control system, so DisableControl
            -- does not touch them. dpemotes binds X to cancelemote, which calls
            -- ClearPedTasks. Without this, spamming X is a walk.
            if anchor then
                local at = GetEntityCoords(ped)

                if #(at - anchor) > (Config.AnchorRadius or 0.75) then
                    SetEntityCoordsNoOffset(ped, anchor.x, anchor.y, anchor.z,
                        false, false, false)
                end
            end

            -- Everything except looking and talking. Movement, combat,
            -- entering vehicles and the weapon wheel are all gone; there is no
            -- crawl to enable.
            DisableAllControlActions(0)

            for i = 1, #ALLOWED do
                EnableControlAction(0, ALLOWED[i], true)
            end

            EnableControlAction(0, Config.RespawnKey, true)

            -- Belt to the controls' braces. Aim and fire have their own path
            -- that a disabled control does not always close.
            DisablePlayerFiring(cache.playerId, true)

            Wait(0)
        end

        -- Handed back exactly what was taken.
        local ped = cache.ped

        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
        ClearPedTasksImmediately(ped)

        anchor = nil
        watching = false
    end)
end

---@param since number server epoch seconds
---@param elapsed number|nil seconds already spent down, non-zero only for a
---       player who reconnected while down. Derived on the server, because the
---       client has no server clock to subtract `since` from.
RegisterNetEvent('som-medical:client:down', function(since, elapsed)
    if isDown then return end

    isDown = true
    downSince = GetGameTimer()
    downElapsed = tonumber(elapsed) or 0

    -- Asked for before the resurrect so it has the fade and the resurrect frame
    -- to stream in. holdDown re-requests if it is not ready.
    if Config.DownAnim and Config.DownAnim.dict then
        RequestAnimDict(Config.DownAnim.dict)
    end

    -- Resurrected IN PLACE, immediately.
    --
    -- The ped is genuinely dead by the time this fires, and SetEntityHealth on
    -- a dead ped does nothing at all: without this the player lies there as a
    -- corpse, the hold loop fights a body that cannot be healed, and voice is
    -- gone, which defeats the one thing this state exists to preserve.
    --
    -- Position and heading are kept, so being revived where you fell is exactly
    -- what it looks like. The two booleans are p4 (keep tasks) and p5 (do not
    -- reset the camera).
    local at = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)

    NetworkResurrectLocalPlayer(at.x, at.y, at.z, heading, true, false)
    SetEntityHealth(cache.ped, Config.DownedHealth)

    -- Read after the resurrect, not before: the resurrect is what settles the
    -- ped, and anchoring to a pre-resurrect coordinate would have the hold loop
    -- fighting the engine over the first half metre.
    anchor = GetEntityCoords(cache.ped)

    holdDown()

    SendNUIMessage({
        action = 'down',
        data = {
            offeredAfter = Config.RespawnOfferedAfter,
            forcedAfter = Config.ForceRespawnAfter,
            fee = Config.RespawnFee,
            holdMs = Config.RespawnHoldMs,
            elapsed = tonumber(elapsed) or 0,
        },
    })

    exports['som-ui']:playSound('error')
end)

RegisterNetEvent('som-medical:client:revive', function()
    if not isDown then return end

    isDown = false
    anchor = nil
    -- Armed again for the next death. Without this the second death of a
    -- session is never reported and the player gets the stock death screen.
    reported = false

    -- Restored here as well as in the hold loop's tail. The loop is mid Wait(0)
    -- when this fires, so relying on it alone leaves a frame in which the player
    -- is up, invincible and unable to ragdoll.
    SetEntityInvincible(cache.ped, false)
    SetPedCanRagdoll(cache.ped, true)
    ClearPedTasksImmediately(cache.ped)
    SetEntityHealth(cache.ped, Config.RespawnHealth or 150)

    SendNUIMessage({ action = 'up' })
    exports['som-ui']:playSound('success')
end)

-- ---------------------------------------------------------------------------
-- The hospital
-- ---------------------------------------------------------------------------

local requesting = false

local function requestRespawn()
    if not isDown or requesting then return end
    requesting = true

    -- pcall, because an ox_lib callback REJECTS as well as resolves: an invalid
    -- response, or the 300 second callback timeout, makes Citizen.Await raise.
    -- Unwinding past the reset below would leave `requesting` stuck true, and
    -- with it stuck the hold thread never runs and forceRespawn returns early,
    -- so the player is pinned on the floor with no escape but a reconnect.
    local ok, res = pcall(lib.callback.await, 'som-medical:server:respawn', false)

    requesting = false

    if not ok then
        TriggerEvent('som:client:notify', 'The hospital did not answer. Try again.', 'error')
        return
    end

    if not res or not res.success then
        if res and res.error then
            TriggerEvent('som:client:notify', res.error, 'error')
        end
        return
    end

    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end

    isDown = false
    anchor = nil
    reported = false

    SetEntityInvincible(cache.ped, false)
    SetPedCanRagdoll(cache.ped, true)
    ClearPedTasksImmediately(cache.ped)

    -- Resurrect BEFORE moving, or the ped is placed and then reset to where it
    -- fell by the resurrect itself.
    NetworkResurrectLocalPlayer(res.coords.x, res.coords.y, res.coords.z,
        res.coords.w, true, false)

    SetEntityHealth(cache.ped, res.health or 150)
    SetEntityCoordsNoOffset(cache.ped, res.coords.x, res.coords.y, res.coords.z, false, false, false)
    SetEntityHeading(cache.ped, res.coords.w)

    SendNUIMessage({ action = 'up' })

    Wait(400)
    DoScreenFadeIn(800)

    -- The AMOUNT is deliberately not repeated here. The fee is billed to the
    -- card, so som-phone's card alert states it, in the app that took it, with
    -- the same label the statement will carry. Saying it twice in two places in
    -- two formats is how a number starts looking like two numbers.
    if res.charged and res.charged > 0 then
        TriggerEvent('som:client:notify',
            ('Treated at %s. Billed to your card.'):format(res.label), 'inform', 7000)
    else
        TriggerEvent('som:client:notify',
            ('Treated at %s. Nothing to collect.'):format(res.label), 'inform', 7000)
    end
end

RegisterNetEvent('som-medical:client:forceRespawn', function()
    if not isDown then return end
    CreateThread(requestRespawn)
end)

---Whether the hospital will actually take the request yet.
---
---Checked HERE as well as on the server, and this is not a duplicated authority
---check: the server still refuses early requests and always will. It is that E
---is a key people rest on, and without this the hold completed every 1.2
---seconds for the whole two minute wait, each one earning a refusal toast and
---an error sound, with no hold bar on screen to explain any of it. Roughly
---ninety error notifications for holding a common key.
---@return boolean
local function offerOpen()
    if not isDown then return false end

    local served = downElapsed + (GetGameTimer() - downSince) / 1000

    return served >= (Config.RespawnOfferedAfter or 120)
end

-- Held, not tapped, so a stray keypress cannot cash in a medic already on the
-- way. The NUI draws the progress; this decides when it counts.
CreateThread(function()
    local held = 0

    while true do
        if isDown and not requesting and offerOpen() then
            if IsDisabledControlPressed(0, Config.RespawnKey)
                or IsControlPressed(0, Config.RespawnKey) then
                held = held + 100

                local needed = Config.RespawnHoldMs or 1200
                SendNUIMessage({ action = 'hold', percent = (held / needed) * 100 })

                if held >= needed then
                    held = 0
                    SendNUIMessage({ action = 'hold', percent = 0 })
                    CreateThread(requestRespawn)
                end
            elseif held > 0 then
                held = 0
                -- Snaps back rather than draining, so letting go reads as
                -- cancelling rather than as slowly losing progress.
                SendNUIMessage({ action = 'hold', percent = 0 })
            end

            Wait(100)
        else
            held = 0
            Wait(500)
        end
    end
end)

exports('isDowned', function() return isDown end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not isDown then return end

    SetEntityInvincible(cache.ped, false)
    SetPedCanRagdoll(cache.ped, true)
    ClearPedTasksImmediately(cache.ped)
end)
