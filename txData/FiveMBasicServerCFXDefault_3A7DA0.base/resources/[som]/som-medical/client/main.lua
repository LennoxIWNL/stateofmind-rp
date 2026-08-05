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
local watching = false

-- ---------------------------------------------------------------------------
-- Reporting a death
--
-- The gameplay event rather than a health poll: polling costs a thread forever
-- and still misses the frame a player dies and respawns in.
-- ---------------------------------------------------------------------------

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if isDown then return end

    local victim, killer, isFatal = args[1], args[2], args[6]

    if victim ~= cache.ped then return end
    if isFatal ~= 1 then return end

    local weapon
    local ok, hash = pcall(GetPedCauseOfDeath, cache.ped)
    if ok and hash and hash ~= 0 then weapon = tostring(hash) end

    -- The server decides whether this becomes a downed state.
    TriggerServerEvent('som-medical:server:died', weapon)
end)

-- ---------------------------------------------------------------------------
-- Being down
-- ---------------------------------------------------------------------------

---Holds the ped on the floor.
---
---Ragdoll rather than an animation, deliberately for now: it needs no dict to
---stream, it cannot fail to load, and it reads unambiguously as incapacitated.
---A proper down animation is a polish pass, recorded in the roadmap, and it
---changes nothing about the state machine when it lands.
local function holdDown()
    if watching then return end
    watching = true

    CreateThread(function()
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

            if not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 2000, 2000, 0, false, false, false)
            end

            -- Everything except talking. Movement, combat, entering vehicles
            -- and the weapon wheel are all gone; there is no crawl to enable.
            DisableAllControlActions(0)
            EnableControlAction(0, Config.RespawnKey, true)
            -- Push to talk and the radio stay live, or being able to speak
            -- would be a promise the controls break.
            EnableControlAction(0, 249, true)   -- INPUT_PUSH_TO_TALK
            EnableControlAction(0, 46, true)    -- INPUT_TALK

            Wait(0)
        end

        -- Handed back exactly what was taken.
        SetEntityInvincible(cache.ped, false)
        ClearPedTasksImmediately(cache.ped)
        watching = false
    end)
end

---@param since number server epoch seconds
RegisterNetEvent('som-medical:client:down', function(since)
    if isDown then return end

    isDown = true
    downSince = GetGameTimer()

    holdDown()

    SendNUIMessage({
        action = 'down',
        data = {
            offeredAfter = Config.RespawnOfferedAfter,
            forcedAfter = Config.ForceRespawnAfter,
            fee = Config.RespawnFee,
            holdMs = Config.RespawnHoldMs,
        },
    })

    exports['som-ui']:playSound('error')
end)

RegisterNetEvent('som-medical:client:revive', function()
    if not isDown then return end

    isDown = false
    SetEntityInvincible(cache.ped, false)
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

    local res = lib.callback.await('som-medical:server:respawn', false)

    requesting = false

    if not res or not res.success then
        if res and res.error then
            TriggerEvent('som:client:notify', res.error, 'error')
        end
        return
    end

    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end

    isDown = false
    SetEntityInvincible(cache.ped, false)
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

    if res.charged and res.charged > 0 then
        TriggerEvent('som:client:notify',
            ('Treated at %s. $%s.'):format(res.label, res.charged), 'inform', 7000)
    else
        TriggerEvent('som:client:notify',
            ('Treated at %s. Nothing to collect.'):format(res.label), 'inform', 7000)
    end
end

RegisterNetEvent('som-medical:client:forceRespawn', function()
    if not isDown then return end
    CreateThread(requestRespawn)
end)

-- Held, not tapped, so a stray keypress cannot cash in a medic already on the
-- way. The NUI draws the progress; this decides when it counts.
CreateThread(function()
    local held = 0

    while true do
        if isDown and not requesting then
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
    ClearPedTasksImmediately(cache.ped)
end)
