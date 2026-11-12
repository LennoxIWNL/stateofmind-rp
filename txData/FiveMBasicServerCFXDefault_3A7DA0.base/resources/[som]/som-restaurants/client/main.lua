--- Counter, stations, supplier and self-serve. Everything here is a request: the server checks
--- the job, duty, distance, prices, stock and money. Menus use som-ui, prompts use som-interact.

local zones = {}
local cooking = false

local function say(result)
    if not result then return end
    TriggerEvent('som:client:notify', result.success and 'Done' or (result.error or 'Failed'), result.success and 'success' or 'error')
end

local function call(name, ...) local r = lib.callback.await(name, false, ...); say(r); return r end

local function ask(heading, rows)
    local answer = lib.inputDialog(heading, rows)
    if not answer then return nil end
    for i = 1, #rows do if answer[i] == nil then return nil end end
    return answer
end

local function sortedKeys(map)
    local keys = {}
    for k in pairs(map) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function pretty(item) return (item:gsub('^burgershot_', ''):gsub('_', ' ')) end

local function buildOrder(r)
    local nearest = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), 3.0, false)
    if not nearest then return say({ success = false, error = 'there is nobody at the counter' }) end
    local lines, options = {}, {}

    local function show()
        options = {}
        for _, key in ipairs(sortedKeys(r.menu)) do
            local m = r.menu[key]
            options[#options + 1] = { title = ('%s ($%d)'):format(m.label, m.price), onSelect = function()
                local a = ask(m.label, { { type = 'number', label = 'How many', min = 1, max = m.maxQty, default = 1, required = true } })
                if a then lines[#lines + 1] = { item = key, qty = math.floor(a[1]) } end
                show()
            end }
        end
        options[#options + 1] = { title = ('Send the order (%d lines)'):format(#lines), onSelect = function()
            if #lines > 0 then call('som-restaurants:server:orderCreate', r.id, GetPlayerServerId(nearest), lines) end
        end }
        lib.registerContext({ id = 'som_rest_order', title = 'Take an order', options = options })
        lib.showContext('som_rest_order')
    end
    show()
end

local function openCounter(entry)
    local r = lib.callback.await('som-restaurants:server:open', false, entry.id)
    if type(r) ~= 'table' then return end

    local options = {}
    if r.forSale then
        options[#options + 1] = { title = ('Buy this restaurant for $%d'):format(r.price), onSelect = function()
            if lib.alertDialog({ header = r.label, content = ('Buy it for $%d?'):format(r.price), centered = true, cancel = true }) == 'confirm' then call('som-restaurants:server:buy', r.id) end
        end }
    end

    if r.staff then
        options[#options + 1] = { title = 'Take an order', onSelect = function() buildOrder(r) end }
        for _, o in ipairs(r.queue or {}) do
            options[#options + 1] = { title = ('Ticket %d'):format(o.id), description = o.text .. '. Hand it over', onSelect = function() call('som-restaurants:server:orderServe', r.id, o.id) end }
        end
    end

    if r.fallback then
        options[#options + 1] = { title = 'Nobody is working. Self-serve food is available at the machine', readOnly = true }
    end

    if r.boss then
        if r.away then options[#options + 1] = { title = 'Go back to work here', onSelect = function() call('som-restaurants:server:resume', r.id) end } end
        options[#options + 1] = { title = ('Balance $%d'):format(r.balance), description = ('Takings in the last day $%d, $%d owed on unserved orders'):format(r.takings, r.owed), readOnly = true }
        options[#options + 1] = { title = 'Take money out', onSelect = function()
            local a = ask('Take money out', { { type = 'number', label = 'Amount', min = 1, required = true } })
            if a then call('som-restaurants:server:withdraw', r.id, math.floor(a[1])) end
        end }
        options[#options + 1] = { title = 'Hire the person next to you', onSelect = function()
            local nearest = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), 3.0, false)
            if not nearest then return say({ success = false, error = 'there is nobody next to you' }) end
            call('som-restaurants:server:hire', r.id, GetPlayerServerId(nearest))
        end }
        options[#options + 1] = { title = 'Let the person next to you go', onSelect = function()
            local nearest = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), 3.0, false)
            if not nearest then return say({ success = false, error = 'there is nobody next to you' }) end
            call('som-restaurants:server:fire', r.id, GetPlayerServerId(nearest))
        end }
    end

    if #options == 0 then options[1] = { title = 'Closed', readOnly = true } end
    lib.registerContext({ id = 'som_rest_counter', title = r.label, options = options })
    lib.showContext('som_rest_counter')
end

local function openStation(entry, station, recipes)
    local options = {}
    for _, id in ipairs(sortedKeys(recipes)) do
        local rec = recipes[id]
        if rec.station == station.kind then
            options[#options + 1] = { title = rec.label, description = rec.needs, onSelect = function()
                if cooking then return end
                local started = call('som-restaurants:server:cookStart', entry.id, station.id, id)
                if not started or not started.success then return end
                cooking = true
                local ok = lib.progressBar({ duration = started.duration, label = rec.label, canCancel = true, disable = { move = true, combat = true }, anim = { dict = 'amb@prop_human_bbq@male@base', clip = 'base', flag = 49 } })
                if ok then call('som-restaurants:server:cookFinish') else lib.callback.await('som-restaurants:server:cookFinish', false) end
                cooking = false
            end }
        end
    end
    if #options == 0 then return end
    lib.registerContext({ id = 'som_rest_station', title = station.kind:gsub('^%l', string.upper), options = options })
    lib.showContext('som_rest_station')
end

local function openSupplier(entry, goods)
    local options = {}
    for _, item in ipairs(sortedKeys(goods)) do
        options[#options + 1] = { title = ('%s ($%d)'):format(pretty(item), goods[item]), onSelect = function()
            local a = ask(pretty(item), { { type = 'number', label = 'How many', min = 1, default = 1, required = true } })
            if a then call('som-restaurants:server:supplier', entry.id, item, math.floor(a[1])) end
        end }
    end
    lib.registerContext({ id = 'som_rest_supplier', title = 'Supplier', options = options })
    lib.showContext('som_rest_supplier')
end

local function openSelfServe(entry, goods)
    local options = {}
    for _, item in ipairs(sortedKeys(goods)) do
        options[#options + 1] = { title = ('%s ($%d)'):format(goods[item].label, goods[item].price), onSelect = function()
            local a = ask(goods[item].label, { { type = 'number', label = 'How many', min = 1, default = 1, required = true } })
            if a then call('som-restaurants:server:selfServe', entry.id, item, math.floor(a[1])) end
        end }
    end
    lib.registerContext({ id = 'som_rest_selfserve', title = 'Self-serve', options = options })
    lib.showContext('som_rest_selfserve')
end

local function zone(name, coords, label, icon, onSelect)
    zones[#zones + 1] = exports['som-interact']:addSphereZone({
        name = name, coords = vec3(coords.x, coords.y, coords.z), radius = 1.2,
        options = { { name = name .. '_use', label = label, icon = icon, distance = 2.0, onSelect = onSelect } },
    })
end

local function build()
    for _, z in ipairs(zones) do exports['som-interact']:removeZone(z) end
    zones = {}

    local data = lib.callback.await('som-restaurants:server:list', false)
    if type(data) ~= 'table' then return end
    local info = lib.callback.await('som-restaurants:server:info', false)
    if type(info) ~= 'table' then return end

    for _, r in ipairs(data.restaurants or {}) do
        zone('som_rest_' .. r.id, r.coords, r.label, 'fa-solid fa-burger', function() openCounter(r) end)
        for _, s in ipairs(r.stations) do
            zone('som_rest_' .. r.id .. '_' .. s.id, s.coords, 'Use the ' .. s.kind, 'fa-solid fa-fire-burner', function() openStation(r, s, info.recipes) end)
        end
        if r.selfServe then zone('som_rest_' .. r.id .. '_self', r.selfServe, 'Self-serve', 'fa-solid fa-cart-shopping', function() openSelfServe(r, info.fallback) end) end
        if data.supplier then zone('som_rest_' .. r.id .. '_supplier', data.supplier, 'Supplier', 'fa-solid fa-truck', function() openSupplier(r, info.goods) end) end
        if r.fridge then
            zone('som_rest_' .. r.id .. '_fridge', r.fridge, 'Open the fridge', 'fa-solid fa-snowflake', function() exports.ox_inventory:openInventory('stash', 'restaurant_' .. r.id) end)
        end
    end
end

RegisterNetEvent('som-restaurants:client:offer', function(orderId, label, text, total)
    if type(orderId) ~= 'number' or type(label) ~= 'string' or type(text) ~= 'string' or type(total) ~= 'number' then return end
    local answer = lib.alertDialog({ header = label, content = ('%s\n\nTotal $%d'):format(text, total), centered = true, cancel = true })
    say(lib.callback.await(answer == 'confirm' and 'som-restaurants:server:orderPay' or 'som-restaurants:server:orderDecline', false, orderId))
end)

RegisterNetEvent('som-restaurants:client:ticket', function(orderId, text)
    if type(orderId) ~= 'number' or type(text) ~= 'string' then return end
    TriggerEvent('som:client:notify', ('New order %d: %s'):format(orderId, text), 'inform')
end)

RegisterNetEvent('som-restaurants:client:hireOffer', function(label)
    if type(label) ~= 'string' then return end
    local answer = lib.alertDialog({ header = label, content = 'You are offered a job here. The pay comes with the normal paycheck.', centered = true, cancel = true })
    say(lib.callback.await('som-restaurants:server:answerHire', false, answer == 'confirm'))
end)

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(3500); build() end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then for _, z in ipairs(zones) do exports['som-interact']:removeZone(z) end end
end)
