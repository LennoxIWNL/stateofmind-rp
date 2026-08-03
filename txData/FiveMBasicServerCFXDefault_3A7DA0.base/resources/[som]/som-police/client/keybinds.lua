-- Officer keybinds.
--
-- Neither reference script has these: qbx_police has exactly one keybind in the
-- entire resource, for a spike strip, and qb-policejob has none. This is an
-- addition rather than something copied, so two rules keep it from becoming a
-- back door.
--
-- 1. A KEYBIND CALLS THE SAME REQUEST THE EYE CALLS. Every one of these goes
--    through Custody.Request, which is the identical validated path. It is a
--    faster way to send an identical message, never a shortcut around a check:
--    handcuffs, proximity and cuffed state are all still verified server side.
--
-- 2. REGISTERED ONCE, DISABLED OFF DUTY. lib.addKeybind cannot be unregistered,
--    and re-registering on every duty change would stack handlers, so they are
--    created at start and toggled. Civilians keep the eye interactions and get
--    no binds at all, so an arrow key can never quietly do something to a
--    passer-by.
--
-- They are rebindable in FiveM's own key settings, which lib.addKeybind gives
-- for free.

local binds = {}

---The person this keybind acts on: the nearest player within reach.
---
---Resolved HERE only to fill in the request. The server re-measures the
---distance itself, so a client naming somebody across the map achieves nothing.
---@return number|nil server id
local function nearest()
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped),
        Config.Custody.distance, false)

    if not playerId then return nil end

    return GetPlayerServerId(playerId)
end

---@param fn function
---@return function guarded handler
local function guarded(fn)
    return function()
        -- Belt and braces: the binds are disabled off duty, but a disabled
        -- keybind that somehow fires still must not act.
        if not Duty.IsOnDuty() then return end
        if Custody.IsCuffed() then return end

        local targetId = nearest()
        if not targetId then
            return TriggerEvent('som:client:notify', 'Nobody within reach', 'error')
        end

        fn(targetId)
    end
end

CreateThread(function()
    if not Config.Keybinds.enabled then return end

    -- Cuff and uncuff share a key, so which verb it means has to be resolved
    -- before the progress bar starts: both Custody.Request paths run their own
    -- bar, and picking the verb from the refusal afterwards would make cuffing
    -- by key instant while cuffing by eye took three seconds.
    --
    -- The state is asked of the SERVER rather than cached locally, because a
    -- client has no honest way to know whether somebody else is restrained.
    binds.cuff = lib.addKeybind({
        name = 'som_police_cuff',
        description = Config.Keybinds.cuff.description,
        defaultKey = Config.Keybinds.cuff.key,
        onPressed = guarded(function(targetId)
            local state = lib.callback.await('som-police:server:custodyState', false, targetId)

            if not state or not state.success then
                return TriggerEvent('som:client:notify',
                    (state and state.error) or 'Cannot reach them', 'error')
            end

            if state.cuffed then
                Custody.Request.uncuff(targetId)
            else
                Custody.Request.cuff(targetId)
            end
        end),
    })

    binds.vehicle = lib.addKeybind({
        name = 'som_police_vehicle',
        description = Config.Keybinds.vehicle.description,
        defaultKey = Config.Keybinds.vehicle.key,
        onPressed = guarded(function(targetId)
            -- In a vehicle means take them out; otherwise put them in. Read
            -- from the target's ped, which is local information about a visible
            -- thing rather than a claim about their state.
            local player = GetPlayerFromServerId(targetId)
            local ped = player ~= -1 and GetPlayerPed(player) or nil

            if ped and IsPedInAnyVehicle(ped, false) then
                Custody.Request.pullFromVehicle(targetId)
            else
                Custody.Request.putInVehicle(targetId)
            end
        end),
    })

    binds.escort = lib.addKeybind({
        name = 'som_police_escort',
        description = Config.Keybinds.escort.description,
        defaultKey = Config.Keybinds.escort.key,
        onPressed = guarded(function(targetId)
            Custody.Request.escort(targetId)
        end),
    })

    -- Stopping an escort needs no target, so it does not go through `guarded`.
    binds.release = lib.addKeybind({
        name = 'som_police_release',
        description = Config.Keybinds.release.description,
        defaultKey = Config.Keybinds.release.key,
        onPressed = function()
            if not Duty.IsOnDuty() then return end
            Custody.Request.stopEscort()
        end,
    })

    -- Off until proven on duty. A fresh spawn is not an officer.
    for _, bind in pairs(binds) do bind:disable(true) end
end)

AddEventHandler('som-police:client:dutyChanged', function(onDuty)
    for _, bind in pairs(binds) do
        bind:disable(not onDuty)
    end
end)
