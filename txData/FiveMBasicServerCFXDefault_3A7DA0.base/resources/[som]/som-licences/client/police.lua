--- Officer options on a person in front of you. A UI filter only: the server
--- checks duty, rank and distance again for every one.

local core = exports['som-core']

local function isOfficer()
    local job = core:getJob()
    return job ~= nil and job.name == Config.job and job.onduty == true
end

local function targetOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function act(id)
    local pick = lib.inputDialog('Licence action', {
        { type = 'select', label = 'Licence', required = true, options = {
            { value = 'driver', label = Config.types.driver.label },
            { value = 'weapon', label = Config.types.weapon.label },
        } },
        { type = 'select', label = 'Action', required = true, options = {
            { value = 'suspend', label = 'Suspend' },
            { value = 'revoke', label = 'Revoke' },
            { value = 'reinstate', label = 'Reinstate' },
        } },
        { type = 'number', label = 'Days (suspend only)', default = 3, min = 1, max = Config.police.maxSuspendDays },
    })
    if not pick then return end

    local r = lib.callback.await('som-licences:server:act', false, id, pick[1], pick[2], math.floor(tonumber(pick[3]) or 0))
    notify(r and r.success and 'Done' or (r and r.error or 'Failed'), r and r.success and 'success' or 'error')
end

CreateThread(function()
    local base = { distance = Config.police.distance, canInteract = isOfficer }
    local function opt(o) for k, v in pairs(base) do o[k] = v end return o end

    exports['som-interact']:addGlobalPlayer({
        opt({
            name = 'licences:check',
            icon = 'fa-solid fa-id-card',
            label = 'Check licences',
            onSelect = function(data)
                local id = targetOf(data.entity)
                local r = id and lib.callback.await('som-licences:server:check', false, id)
                if not r or not r.success then return notify(r and r.error or 'Nobody there') end
                lib.alertDialog({ header = r.name, content = table.concat(r.lines, '\n\n') })
            end,
        }),
        opt({
            name = 'licences:act',
            icon = 'fa-solid fa-ban',
            label = 'Suspend, revoke or reinstate a licence',
            onSelect = function(data)
                local id = targetOf(data.entity)
                if id then act(id) end
            end,
        }),
        opt({
            name = 'licences:weapon',
            icon = 'fa-solid fa-gun',
            label = 'Issue a weapon licence',
            onSelect = function(data)
                local id = targetOf(data.entity)
                local r = id and lib.callback.await('som-licences:server:issueWeapon', false, id)
                if r then notify(r.success and 'Offer sent, waiting for them' or r.error, r.success and 'success' or 'error') end
            end,
        }),
    })
end)
