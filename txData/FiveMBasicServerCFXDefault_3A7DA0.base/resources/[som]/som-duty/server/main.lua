local core = exports['som-core']

local last = {}

lib.callback.register('som-duty:server:toggle', function(source)
    local player = core:getPlayer(source)
    if not player or not player.job then return { success = false, error = 'not loaded' } end

    local name = player.job.name
    if Config.excluded[name] or not core:getJobs()[name] then
        return { success = false, error = 'your job has no clock in' }
    end

    local now = GetGameTimer()
    if last[source] and now - last[source] < Config.cooldownSeconds * 1000 then
        return { success = false, error = 'one moment' }
    end
    last[source] = now

    local going = not player.job.onduty
    local ok, err = core:setDuty(source, going)
    if not ok then return { success = false, error = err or 'could not change duty' } end

    return { success = true, onduty = going }
end)

local function registerRadial()
    if GetResourceState('som-radial') ~= 'started' then return end

    exports['som-radial']:register({
        id = 'duty.toggle',
        section = 'job',
        label = 'Clock in or out',
        icon = 'badge',
        order = 5,
        export = 'som-duty.toggle',
    })
end

AddEventHandler('onResourceStart', function(name)
    if name == 'som-radial' or name == GetCurrentResourceName() then registerRadial() end
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
