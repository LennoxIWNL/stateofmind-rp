--- A counter and a menu. The job list, the checks and the cooldown are the server's.

local zone

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function menu()
    local data = lib.callback.await('som-welcome:server:jobs', false)
    if not data or not data.success then return notify(data and data.error or 'Not available') end

    local options = {}
    for _, job in ipairs(data.jobs) do
        options[#options + 1] = {
            title = job.label,
            description = job.name == data.current and 'Your job now' or nil,
            disabled = job.name == data.current,
            onSelect = function()
                local r = lib.callback.await('som-welcome:server:setJob', false, job.name)
                if r and r.success then notify('You have a new job', 'success') else notify(r and r.error or 'Not available') end
            end,
        }
    end
    if data.current ~= 'unemployed' then
        options[#options + 1] = {
            title = 'Leave my job',
            onSelect = function()
                local r = lib.callback.await('som-welcome:server:setJob', false, 'unemployed')
                if r and r.success then notify('You have left your job', 'success') else notify(r and r.error or 'Not available') end
            end,
        }
    end

    lib.registerContext({ id = 'som_welcome_jobs', title = 'Job centre', options = options })
    lib.showContext('som_welcome_jobs')
end

CreateThread(function()
    local d = lib.callback.await('som-welcome:server:desk', false)
    if type(d) ~= 'table' then return end
    zone = exports['som-interact']:addSphereZone({
        name = 'som_welcome_desk',
        coords = vec3(d.coords.x, d.coords.y, d.coords.z),
        radius = d.distance,
        options = { { name = 'som_welcome_use', label = d.label, icon = 'fa-solid fa-briefcase', distance = d.distance, onSelect = menu } },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and zone then exports['som-interact']:removeZone(zone) end
end)
