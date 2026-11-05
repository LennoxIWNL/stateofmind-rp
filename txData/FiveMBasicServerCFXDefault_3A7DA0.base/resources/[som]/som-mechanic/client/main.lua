--- The vehicle options for mechanics, the progress bar, and applying the
--- health the server granted. The server has already checked the job, the
--- parts and the damage.

local core = exports['som-core']

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function work(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local info = lib.callback.await('som-mechanic:server:inspect', false, netId)
    if not info or not info.success then return say(info and info.error or 'No vehicle', 'error') end

    local options = {}
    for _, r in ipairs(info.repairs) do
        if r.damaged then options[#options + 1] = { value = r.kind, label = ('%s ($%d)'):format(r.label, r.price), seconds = r.seconds } end
    end
    if #options == 0 then return say('Nothing needs fixing', 'inform') end

    local answer = lib.inputDialog('Repair', { { type = 'select', label = 'Work', options = options, required = true } })
    if not answer or not answer[1] then return end

    local seconds = 10
    for _, o in ipairs(options) do if o.value == answer[1] then seconds = o.seconds end end

    local ok = lib.progressBar({
        duration = seconds * 1000, label = 'Working on it', canCancel = true,
        disable = { move = true, combat = true },
    })
    if not ok then return end

    local result = lib.callback.await('som-mechanic:server:repair', false, netId, answer[1])
    if result and not result.success then say(result.error or 'Failed', 'error') end
end

RegisterNetEvent('som-mechanic:client:apply', function(netId, kind, to)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if kind == 'engine' then SetVehicleEngineHealth(vehicle, to + 0.0) else SetVehicleBodyHealth(vehicle, to + 0.0) end
    if kind == 'body' then SetVehicleDeformationFixed(vehicle) end
    say('Repair done', 'success')
end)

exports['som-interact']:addGlobalVehicle({
    {
        name = 'som_mechanic_repair', label = 'Repair', icon = 'fa-solid fa-wrench', distance = 3.0,
        canInteract = function()
            local job = core:getJob()
            return job ~= nil and job.name == 'mechanic' and job.onduty == true
        end,
        onSelect = function(data) work(data.entity) end,
    },
})
