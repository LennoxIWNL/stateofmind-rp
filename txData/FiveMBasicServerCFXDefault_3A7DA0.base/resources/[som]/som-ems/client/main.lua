--- The "Treat" option on downed players and the progress bar. The server has
--- already checked the job, the patient, the kit and the time.

local core = exports['som-core']
local busy = false

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function treat(ped)
    local index = NetworkGetPlayerIndexFromPed(ped)
    if index == -1 then return end
    local target = GetPlayerServerId(index)
    if target <= 0 then return end

    busy = true
    local began = lib.callback.await('som-ems:server:begin', false, target)
    if not began or not began.success then
        busy = false
        return say(began and began.error or 'Failed', 'error')
    end

    local ok = lib.progressBar({
        duration = Config.revive.seconds * 1000, label = 'Treating the patient', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
    })
    if not ok then
        busy = false
        return
    end

    local result = lib.callback.await('som-ems:server:revive', false, target)
    busy = false
    if result and not result.success then say(result.error or 'Failed', 'error') end
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'som_ems_treat', label = 'Treat', icon = 'fa-solid fa-kit-medical', distance = Config.distance,
            canInteract = function(entity)
                if busy then return false end
                local job = core:getJob()
                if not job or job.name ~= Config.job or not job.onduty then return false end
                local index = NetworkGetPlayerIndexFromPed(entity)
                if index == -1 then return false end
                return Player(GetPlayerServerId(index)).state['som:downed'] ~= nil and Player(GetPlayerServerId(index)).state['som:downed'] ~= false
            end,
            onSelect = function(data)
                if data and data.entity then treat(data.entity) end
            end,
        },
    })
end)
