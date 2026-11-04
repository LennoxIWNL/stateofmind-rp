--- Shows the current objective and asks the server to complete it. The hack
--- puzzle itself is som-hack's, run from the server; nothing here decides a
--- result, a payout or whether the player is close enough.

local zone, blip, current

local function clear()
    if zone then exports['som-interact']:removeZone(zone) end
    if blip then RemoveBlip(blip) end
    zone, blip, current = nil, nil, nil
end

RegisterNetEvent('som-heists:client:objective', function(goal)
    clear()
    if type(goal) ~= 'table' or not goal.coords then return end

    current = goal
    local c = goal.coords

    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(goal.label or 'Heist')
    EndTextCommandSetBlipName(blip)

    zone = exports['som-interact']:addSphereZone({
        name = 'som_heist_objective',
        coords = vec3(c.x, c.y, c.z),
        radius = 2.5,
        options = {
            {
                name = 'som_heist_do',
                label = goal.kind == 'hack' and 'Use the Trojan USB' or 'Take the cash',
                icon = goal.kind == 'hack' and 'fa-solid fa-usb' or 'fa-solid fa-sack-dollar',
                distance = 2.5,
                onSelect = function()
                    local kind = current and current.kind
                    if not kind then return end

                    if kind == 'loot' then
                        local ok = lib.progressBar({
                            duration = 6000, label = 'Taking the cash', canCancel = true,
                            disable = { move = true, combat = true },
                        })
                        if not ok then return end
                    end

                    local result = lib.callback.await('som-heists:server:interact', false, kind)
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
