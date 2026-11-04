--- The worker's side of community service. It only shows spots and plays an
--- animation; the server decides whether a task counted.

local zones = {}
local working = false

local function clear()
    for _, id in ipairs(zones) do exports['som-interact']:removeZone(id) end
    zones = {}
end

local function doTask(spot)
    if working then return end
    working = true

    local started = lib.callback.await('som-jail:server:svc:begin', false, spot.id)
    if not started or not started.success then
        working = false
        return TriggerEvent('som:client:notify', started and started.error or 'could not start', 'error')
    end

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, started.scenario, 0, true)

    lib.progressBar({
        duration = started.duration,
        label = started.label,
        canCancel = false,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasks(ped)

    local res = lib.callback.await('som-jail:server:svc:finish', false)
    working = false

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'that did not count', 'error')
    end

    if not res.done then
        TriggerEvent('som:client:notify', ('%d tasks left'):format(res.remaining), 'inform')
    end
end

local function show()
    if #zones > 0 then return end

    for _, spot in ipairs(Config.Service.spots) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'jail:svc:' .. spot.id,
            coords = spot.coords,
            radius = Config.Service.range,
            options = {
                {
                    name = 'jail:svc:' .. spot.id,
                    icon = 'fa-solid fa-broom',
                    label = Config.Service.kinds[spot.kind].label,
                    distance = Config.Service.range,
                    onSelect = function() doTask(spot) end,
                },
            },
        })
    end
end

RegisterNetEvent('som-jail:client:serviceStarted', function(tasks)
    show()
    JailTeleportTo(Config.Service.spawn)
    TriggerEvent('som:client:notify', ('Community service: %d tasks'):format(tasks), 'inform', 8000)
end)

RegisterNetEvent('som-jail:client:serviceResume', function(remaining)
    show()
    TriggerEvent('som:client:notify', ('Community service: %d tasks left'):format(remaining), 'inform', 8000)
end)

RegisterNetEvent('som-jail:client:serviceReturn', function(spawn)
    JailTeleportTo(spawn)
    TriggerEvent('som:client:notify', 'Stay in the work area', 'error')
end)

RegisterNetEvent('som-jail:client:serviceEnded', function(completed, release)
    clear()
    if completed and release then
        TriggerEvent('som:client:notify', 'Community service complete', 'success')
        JailTeleportTo(release)
    end
end)
