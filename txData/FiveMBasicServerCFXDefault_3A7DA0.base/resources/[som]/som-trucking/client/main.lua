--- Shows where the trailer waits and where the yard is, and asks the server to
--- hand in or abandon. Nothing here decides pay, damage or distance.

local zone, blips = nil, {}
local active = false

local function clear()
    if zone then exports['som-interact']:removeZone(zone) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    zone, blips, active = nil, {}, false
end

local function blip(c, sprite, colour, label, route)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, colour)
    if route then SetBlipRoute(b, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
end

RegisterNetEvent('som-trucking:client:objective', function(goal)
    clear()
    if type(goal) ~= 'table' or not goal.coords or not goal.depot then return end

    active = true
    local c = goal.coords
    blip(goal.depot, 479, 5, 'Trailer pickup', false)
    blip(c, 477, 2, goal.label or 'Freight yard', true)

    zone = exports['som-interact']:addSphereZone({
        name = 'som_trucking_yard',
        coords = vec3(c.x, c.y, c.z),
        radius = 8.0,
        options = {
            {
                name = 'som_trucking_deliver',
                label = 'Hand in the trailer',
                icon = 'fa-solid fa-truck',
                distance = 8.0,
                onSelect = function()
                    local done = lib.progressBar({
                        duration = 5000,
                        label = 'Unhooking',
                        canCancel = true,
                        disable = { move = true, combat = true },
                    })
                    if not done then return end

                    local result = lib.callback.await('som-trucking:server:deliver', false)
                    if result and not result.success and result.error then
                        TriggerEvent('som:client:notify', result.error, 'error')
                    end
                end,
            },
        },
    })
end)

RegisterCommand('abandonhaul', function()
    if not active then return TriggerEvent('som:client:notify', 'You have no haul', 'error') end

    local answer = lib.alertDialog({
        header = 'Abandon the haul?',
        content = 'No pay, the truck and trailer are removed, and your crew waits a while before the next one.',
        centered = true,
        cancel = true,
    })
    if answer ~= 'confirm' then return end

    local result = lib.callback.await('som-trucking:server:abandon', false)
    if result and not result.success and result.error then
        TriggerEvent('som:client:notify', result.error, 'error')
    end
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
