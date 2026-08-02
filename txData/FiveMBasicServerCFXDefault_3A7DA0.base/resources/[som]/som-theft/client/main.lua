-- Registers the "Steal Cash" option on players.
--
-- The option is filtered client side purely so the menu is not cluttered with
-- actions that would fail. The server re-checks every condition, so hiding or
-- showing this entry grants nothing.

local busy = false

---@param targetPed number
---@return boolean
local function victimLooksRobbable(targetPed)
    -- Cheap local read to keep the menu tidy. Not a permission check.
    return IsPedDeadOrDying(targetPed, true)
        or IsPedCuffed(targetPed)
        or IsPedRagdoll(targetPed)
        or Entity(targetPed).state['som:handsup'] == true
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'som_steal_cash',
            label = 'Steal Cash',
            icon = 'fa-solid fa-sack-dollar',
            distance = Config.MaxDistance,
            canInteract = function(entity)
                if busy then return false end
                return victimLooksRobbable(entity)
            end,
            onSelect = function(data)
                local targetPed = data and data.entity
                if not targetPed then return end

                local targetId = NetworkGetPlayerIndexFromPed(targetPed)
                if targetId == -1 then return end

                local serverId = GetPlayerServerId(targetId)
                if serverId <= 0 then return end

                busy = true

                local completed = lib.progressBar({
                    duration = Config.SearchDuration,
                    label = 'Searching pockets',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, combat = true },
                    anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                })

                if not completed then
                    busy = false
                    return
                end

                local result = lib.callback.await('som-theft:server:stealCash', false, serverId)
                busy = false

                -- The server sends its own notification on success. Only the
                -- refusal path needs surfacing here.
                if result and not result.success and result.error then
                    TriggerEvent('som:client:notify', result.error, 'error')
                end
            end,
        },
    })
end)
