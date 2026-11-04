--- Places the tag and sell points the server reports and asks the server to
--- act. Ownership, prices and distances are all decided server side.

local placed = {}

local function notify(result)
    if not result then return end
    if result.success and result.message then
        TriggerEvent('som:client:notify', result.message, 'success')
    elseif result.error then
        TriggerEvent('som:client:notify', result.error, 'error')
    end
end

local function clear()
    for _, id in ipairs(placed) do exports['som-interact']:removeZone(id) end
    placed = {}
end

local function tag(zone)
    local began = lib.callback.await('som-turf:server:tagBegin', false, zone.name)
    if not began or not began.success then return notify(began) end

    local ok = lib.progressBar({
        duration = 20000, label = 'Tagging the wall', canCancel = true,
        disable = { move = true, combat = true },
    })
    if not ok then return end
    notify(lib.callback.await('som-turf:server:tagFinish', false, zone.name))
end

local function sell(zone, drugs)
    local options = {}
    for _, d in ipairs(drugs) do options[#options + 1] = { value = d.item, label = d.label } end
    local answer = lib.inputDialog('Sell to a local', {
        { type = 'select', label = 'What', options = options, required = true },
    })
    if not answer or not answer[1] then return end
    notify(lib.callback.await('som-turf:server:sell', false, zone.name, answer[1]))
end

local function build()
    clear()
    local data = lib.callback.await('som-turf:server:zones', false)
    if type(data) ~= 'table' then return end

    for _, z in ipairs(data.zones) do
        placed[#placed + 1] = exports['som-interact']:addSphereZone({
            name = 'som_turf_tag_' .. z.name,
            coords = vec3(z.tag.x, z.tag.y, z.tag.z),
            radius = 1.5,
            options = { {
                name = 'som_turf_tag', label = 'Tag the wall', icon = 'fa-solid fa-spray-can', distance = 2.0,
                onSelect = function() tag(z) end,
            } },
        })
        placed[#placed + 1] = exports['som-interact']:addSphereZone({
            name = 'som_turf_sell_' .. z.name,
            coords = vec3(z.center.x, z.center.y, z.center.z),
            radius = z.radius,
            options = { {
                name = 'som_turf_sell', label = 'Sell to a local', icon = 'fa-solid fa-hand-holding-dollar', distance = z.radius,
                onSelect = function() sell(z, data.drugs) end,
            } },
        })
    end
end

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(2000); build() end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clear() end end)
