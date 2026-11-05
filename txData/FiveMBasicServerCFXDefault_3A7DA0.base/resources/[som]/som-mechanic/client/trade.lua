--- Offer a kit to the person you are facing, and the roadside desk. The server
--- checks the job, the price limits, the distance and the item.

local function say(result)
    if not result then return end
    TriggerEvent('som:client:notify', result.success and 'Offer sent' or (result.error or 'Failed'), result.success and 'success' or 'error')
end

local core = exports['som-core']

local function offer(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if player == -1 then return end

    local items = lib.callback.await('som-mechanic:server:tradeInfo', false)
    if type(items) ~= 'table' or #items == 0 then return end

    local options = {}
    for _, i in ipairs(items) do options[#options + 1] = { value = i.item, label = ('%s ($%d to $%d)'):format(i.item:gsub('_', ' '), i.min, i.max) } end
    local answer = lib.inputDialog('Offer an item', {
        { type = 'select', label = 'Item', options = options, required = true },
        { type = 'number', label = 'Price', min = 1, required = true },
    })
    if not answer or not answer[1] or not answer[2] then return end
    say(lib.callback.await('som-mechanic:server:offer', false, GetPlayerServerId(player), answer[1], answer[2]))
end

exports['som-interact']:addGlobalPed({
    {
        name = 'som_mechanic_offer', label = 'Offer a kit', icon = 'fa-solid fa-tags', distance = 2.5,
        canInteract = function(entity)
            local job = core:getJob()
            return job ~= nil and job.name == 'mechanic' and job.onduty == true and IsPedAPlayer(entity)
        end,
        onSelect = function(data) offer(data.entity) end,
    },
})

local zone
local function build()
    if zone then exports['som-interact']:removeZone(zone); zone = nil end
    local info = lib.callback.await('som-mechanic:server:fallbackInfo', false)
    if type(info) ~= 'table' then return end
    zone = exports['som-interact']:addSphereZone({
        name = 'som_mechanic_fallback',
        coords = vec3(info.coords.x, info.coords.y, info.coords.z),
        radius = 1.5,
        options = { { name = 'som_mechanic_fallback_buy', label = ('%s: %s ($%d)'):format(info.label, info.item:gsub('_', ' '), info.price), icon = 'fa-solid fa-truck-medical', distance = 2.0,
            onSelect = function()
                local result = lib.callback.await('som-mechanic:server:fallbackBuy', false)
                TriggerEvent('som:client:notify', result.success and 'Bought' or (result.error or 'Failed'), result.success and 'success' or 'error')
            end } },
    })
end

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(3500); build() end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and zone then exports['som-interact']:removeZone(zone) end
end)
