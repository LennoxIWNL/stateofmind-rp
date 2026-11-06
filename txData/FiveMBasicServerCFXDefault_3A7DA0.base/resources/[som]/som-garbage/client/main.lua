--- Shows the stop's bins and the dump points and asks the server to count a
--- bag or tip a load. Nothing here decides the count, the sort or the pay.

local zones, blips = {}, {}
local active = false

local function clear()
    for _, z in ipairs(zones) do exports['som-interact']:removeZone(z) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    zones, blips, active = {}, {}, false
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

local function bagOption(binId, choice, label)
    return {
        name = ('som_garbage_%s_%s'):format(binId, choice),
        label = label,
        icon = 'fa-solid fa-trash',
        distance = 3.0,
        onSelect = function()
            local done = lib.progressBar({
                duration = 3000,
                label = 'Emptying the bin',
                canCancel = true,
                disable = { move = true, combat = true },
                anim = { dict = 'anim@heists@narcotics@trash', clip = 'throw_b' },
            })
            if not done then return end

            local result = lib.callback.await('som-garbage:server:bag', false, binId, choice)
            if not result then return end
            if not result.success then return TriggerEvent('som:client:notify', result.error, 'error') end
            if not result.sorted then TriggerEvent('som:client:notify', 'Wrong bin: that bag is general waste now', 'error') end
        end,
    }
end

local function bayOption(kind)
    return {
        name = 'som_garbage_tip_' .. kind,
        label = kind == 'recycle' and 'Tip the recycling' or 'Tip the general waste',
        icon = 'fa-solid fa-dumpster',
        distance = 6.0,
        onSelect = function()
            local result = lib.callback.await('som-garbage:server:tip', false, kind)
            if result and not result.success and result.error then
                TriggerEvent('som:client:notify', result.error, 'error')
            end
        end,
    }
end

RegisterNetEvent('som-garbage:client:objective', function(goal)
    clear()
    if type(goal) ~= 'table' then return end

    active = true
    if goal.kind == 'stop' then
        blip(goal.coords, 318, 25, goal.label or 'Pickup', true)
        for _, bin in ipairs(goal.bins) do
            local c = bin.coords
            zones[#zones + 1] = exports['som-interact']:addSphereZone({
                name = 'som_garbage_bin_' .. bin.id,
                coords = vec3(c.x, c.y, c.z),
                radius = 2.0,
                options = {
                    bagOption(bin.id, 'general', (bin.kind == 'recycle' and 'Blue bin' or 'Black bin') .. ': general waste'),
                    bagOption(bin.id, 'recycle', (bin.kind == 'recycle' and 'Blue bin' or 'Black bin') .. ': recycling'),
                },
            })
        end
    elseif goal.kind == 'dump' then
        for _, bay in ipairs(goal.bays) do
            local c = bay.coords
            blip(c, 318, bay.kind == 'recycle' and 2 or 25, bay.kind == 'recycle' and 'Recycling centre' or 'Landfill', true)
            zones[#zones + 1] = exports['som-interact']:addSphereZone({
                name = 'som_garbage_bay_' .. bay.kind,
                coords = vec3(c.x, c.y, c.z),
                radius = 8.0,
                options = { bayOption(bay.kind) },
            })
        end
    end
end)

RegisterCommand('abandonround', function()
    if not active then return TriggerEvent('som:client:notify', 'You have no round', 'error') end

    local answer = lib.alertDialog({
        header = 'Abandon the round?',
        content = 'No more pay, the truck is removed, and your crew waits a while before the next one.',
        centered = true,
        cancel = true,
    })
    if answer ~= 'confirm' then return end

    local result = lib.callback.await('som-garbage:server:abandon', false)
    if result and not result.success and result.error then
        TriggerEvent('som:client:notify', result.error, 'error')
    end
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
