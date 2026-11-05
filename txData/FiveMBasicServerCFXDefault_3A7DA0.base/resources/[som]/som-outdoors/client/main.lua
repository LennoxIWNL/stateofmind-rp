--- Cast, wait, reel and sell. The server picks the bite time and the catch.

local zones = {}

local function say(result)
    if not result then return end
    if result.success then
        TriggerEvent('som:client:notify', result.paid and ('Sold for $%d'):format(result.paid) or 'Done', 'success')
    elseif result.error then
        TriggerEvent('som:client:notify', result.error, 'error')
    end
end

local function fish()
    local cast = lib.callback.await('som-outdoors:server:cast', false)
    if not cast or not cast.success then return say(cast) end

    local waited = lib.progressBar({
        duration = cast.wait * 1000, label = 'Waiting for a bite', canCancel = true,
        disable = { move = true, combat = true },
    })
    if not waited then return end

    local reel = lib.callback.await('som-outdoors:server:reel', false)
    if reel and reel.success then
        TriggerEvent('som:client:notify', 'You caught something', 'success')
    else
        say(reel)
    end
end

local function clear()
    for _, id in ipairs(zones) do exports['som-interact']:removeZone(id) end
    zones = {}
end

local function build()
    clear()
    for _, s in ipairs(lib.callback.await('som-outdoors:server:fishSpots', false) or {}) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_fish_' .. s.name,
            coords = vec3(s.center.x, s.center.y, s.center.z),
            radius = s.radius,
            options = { { name = 'som_fish_cast', label = 'Fish here', icon = 'fa-solid fa-fish', distance = s.radius, onSelect = fish } },
        })
    end
    for _, b in ipairs(lib.callback.await('som-outdoors:server:buyers', false) or {}) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_buyer_' .. b.name,
            coords = vec3(b.coords.x, b.coords.y, b.coords.z),
            radius = 1.5,
            options = { { name = 'som_buyer_sell', label = 'Sell: ' .. b.label, icon = 'fa-solid fa-sack-dollar', distance = 2.0,
                onSelect = function() say(lib.callback.await('som-outdoors:server:sell', false, b.name)) end } },
        })
    end
end

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(3000); build() end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clear() end end)
