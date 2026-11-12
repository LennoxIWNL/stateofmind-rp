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
                local down = Player(GetPlayerServerId(index)).state['som:downed']
                return down ~= nil and down ~= false
            end,
            onSelect = function(data)
                if data and data.entity then treat(data.entity) end
            end,
        },
    })
end)

local zone
local function buildLocker()
    if zone then exports['som-interact']:removeZone(zone); zone = nil end
    local info = lib.callback.await('som-ems:server:lockerInfo', false)
    if type(info) ~= 'table' then return end
    zone = exports['som-interact']:addSphereZone({
        name = 'som_ems_locker',
        coords = vec3(info.coords.x, info.coords.y, info.coords.z),
        radius = 1.5,
        options = { { name = 'som_ems_locker_take', label = info.label, icon = 'fa-solid fa-suitcase-medical', distance = 2.0,
            onSelect = function()
                local result = lib.callback.await('som-ems:server:lockerTake', false)
                say(result.success and 'Kit taken' or (result.error or 'Failed'), result.success and 'success' or 'error')
            end } },
    })
end

AddEventHandler('som:client:playerLoaded', buildLocker)
CreateThread(function() Wait(3500); buildLocker() end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and zone then exports['som-interact']:removeZone(zone) end
end)
