--- The shop counter. Everything here is a request: the server checks ownership, distance, prices
--- and money. One counter option opens the buy menu, and the owner also gets a manage menu.

local zones = {}

local function pretty(item) return (item:gsub('_', ' ')) end

local function say(result)
    if not result then return end
    TriggerEvent('som:client:notify', result.success and 'Done' or (result.error or 'Failed'), result.success and 'success' or 'error')
end

local function call(name, ...) say(lib.callback.await(name, false, ...)) end

local function ask(heading, rows)
    local answer = lib.inputDialog(heading, rows)
    if not answer then return nil end
    for i = 1, #rows do if answer[i] == nil then return nil end end
    return answer
end

local function itemOptions(s, onlyStocked)
    local out = {}
    for item, limits in pairs(s.items) do
        local have
        for _, row in ipairs(s.stock or {}) do if row.item == item then have = row end end
        if not onlyStocked or have then
            out[#out + 1] = { value = item, label = ('%s ($%d to $%d)'):format(pretty(item), limits.min, limits.max) }
        end
    end
    table.sort(out, function(a, b) return a.value < b.value end)
    return out
end

local function manage(s)
    local o = s.overview
    local options = {
        { title = ('Balance $%d'):format(o.balance), description = ('Takings in the last day: $%d'):format(o.takings), readOnly = true },
        { title = 'Stock an item', onSelect = function()
            local a = ask('Stock an item', {
                { type = 'select', label = 'Item', options = itemOptions(s), required = true },
                { type = 'number', label = 'How many', min = 1, required = true },
                { type = 'number', label = 'Price each', min = 1, required = true },
            })
            if a then call('som-shops:server:stock', s.id, a[1], math.floor(a[2]), math.floor(a[3])) end
        end },
        { title = 'Change a price', onSelect = function()
            local a = ask('Change a price', {
                { type = 'select', label = 'Item', options = itemOptions(s, true), required = true },
                { type = 'number', label = 'New price', min = 1, required = true },
            })
            if a then call('som-shops:server:setPrice', s.id, a[1], math.floor(a[2])) end
        end },
        { title = 'Take stock back', onSelect = function()
            local a = ask('Take stock back', {
                { type = 'select', label = 'Item', options = itemOptions(s, true), required = true },
                { type = 'number', label = 'How many', min = 1, required = true },
            })
            if a then call('som-shops:server:retrieve', s.id, a[1], math.floor(a[2])) end
        end },
        { title = 'Take money out', onSelect = function()
            local a = ask('Take money out', { { type = 'number', label = 'Amount', min = 1, required = true } })
            if a then call('som-shops:server:withdraw', s.id, math.floor(a[1])) end
        end },
        { title = 'Hire the person next to you', onSelect = function()
            local player = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), 3.0, false)
            if not player then return say({ success = false, error = 'there is nobody next to you' }) end
            local a = ask('Hire', { { type = 'number', label = 'Pay an hour', min = 1, required = true } })
            if a then call('som-shops:server:hire', s.id, GetPlayerServerId(player), math.floor(a[1])) end
        end },
    }

    for _, w in ipairs(o.staff) do
        options[#options + 1] = { title = ('%s %s: $%d an hour'):format(w.firstname, w.lastname, w.hourly_pay), description = 'Change the pay or let them go', onSelect = function()
            local a = ask('Staff', { { type = 'number', label = 'New pay an hour, or 0 to let them go', min = 0, required = true } })
            if not a then return end
            if a[1] == 0 then call('som-shops:server:fire', s.id, w.citizenid) else call('som-shops:server:setPay', s.id, w.citizenid, math.floor(a[1])) end
        end }
    end

    options[#options + 1] = { title = ('Sell the shop back for $%d'):format(s.refund), onSelect = function()
        if lib.alertDialog({ header = s.label, content = ('Sell it back to the city for $%d?'):format(s.refund), centered = true, cancel = true }) == 'confirm' then call('som-shops:server:sellShop', s.id) end
    end }

    lib.registerContext({ id = 'som_shops_manage', title = 'Manage ' .. s.label, menu = 'som_shops', options = options })
end

local function openShop(id)
    local s = lib.callback.await('som-shops:server:open', false, id)
    if type(s) ~= 'table' then return end

    local options = {}
    if not s.owned then
        options[1] = { title = ('Buy this shop for $%d'):format(s.price), onSelect = function()
            if lib.alertDialog({ header = s.label, content = ('Buy it for $%d?'):format(s.price), centered = true, cancel = true }) == 'confirm' then call('som-shops:server:buyShop', id) end
        end }
    else
        for _, row in ipairs(s.stock or {}) do
            if row.qty > 0 then
                options[#options + 1] = { title = ('%s ($%d)'):format(pretty(row.item), row.price), description = ('%d in stock'):format(row.qty), onSelect = function()
                    local a = ask(pretty(row.item), { { type = 'number', label = 'How many', min = 1, default = 1, required = true } })
                    if a then call('som-shops:server:buy', id, row.item, math.floor(a[1])) end
                end }
            end
        end
        if #options == 0 then options[1] = { title = 'Nothing for sale right now', readOnly = true } end
    end

    if s.owner then
        manage(s)
        options[#options + 1] = { title = 'Manage the shop', menu = 'som_shops_manage', arrow = true }
    end

    lib.registerContext({ id = 'som_shops', title = s.label, options = options })
    lib.showContext('som_shops')
end

local function build()
    for _, zone in ipairs(zones) do exports['som-interact']:removeZone(zone) end
    zones = {}

    local list = lib.callback.await('som-shops:server:list', false)
    if type(list) ~= 'table' then return end

    for _, shop in ipairs(list) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_shop_' .. shop.id,
            coords = vec3(shop.coords.x, shop.coords.y, shop.coords.z),
            radius = 1.5,
            options = { { name = 'som_shop_use_' .. shop.id, label = shop.label, icon = 'fa-solid fa-store', distance = 2.0, onSelect = function() openShop(shop.id) end } },
        })
    end
end

RegisterNetEvent('som-shops:client:hireOffer', function(shopLabel, ownerName, pay)
    if type(shopLabel) ~= 'string' or type(ownerName) ~= 'string' or type(pay) ~= 'number' then return end
    local answer = lib.alertDialog({
        header = shopLabel,
        content = ('%s offers you a job for $%d an hour.'):format(ownerName, pay),
        centered = true, cancel = true,
    })
    say(lib.callback.await('som-shops:server:answerHire', false, answer == 'confirm'))
end)

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(3500); build() end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then for _, zone in ipairs(zones) do exports['som-interact']:removeZone(zone) end end
end)
