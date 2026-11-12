--- Shows the current objective and asks the server to complete it. Nothing
--- here decides pay, stage or whether the player is close enough.

local zone, blip
local current

local function clear()
    if zone then exports['som-interact']:removeZone(zone) end
    if blip then RemoveBlip(blip) end
    zone, blip, current = nil, nil, nil
end

RegisterNetEvent('som-courier:client:objective', function(goal)
    clear()
    if type(goal) ~= 'table' or not goal.coords then return end

    current = goal
    local c = goal.coords

    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(goal.label or 'Delivery')
    EndTextCommandSetBlipName(blip)

    zone = exports['som-interact']:addSphereZone({
        name = 'som_courier_objective',
        coords = vec3(c.x, c.y, c.z),
        radius = 3.0,
        options = {
            {
                name = 'som_courier_do',
                label = goal.kind == 'pickup' and 'Load the parcels' or 'Hand over the parcels',
                icon = 'fa-solid fa-box',
                distance = 3.0,
                onSelect = function()
                    local kind = current and current.kind
                    if not kind then return end

                    local done = lib.progressBar({
                        duration = 4000,
                        label = kind == 'pickup' and 'Loading' or 'Handing over',
                        canCancel = true,
                        disable = { move = true, combat = true },
                        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
                    })
                    if not done then return end

                    local result = lib.callback.await('som-courier:server:interact', false, kind)
                    if result and not result.success and result.error then
                        TriggerEvent('som:client:notify', result.error, 'error')
                    end
                end,
            },
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
