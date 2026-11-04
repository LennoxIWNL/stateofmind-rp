--- The desk. It lists what the server says you carry and what is ready; it
--- decides nothing.

local function notify(res)
    TriggerEvent('som:client:notify', res and (res.success and 'Done' or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
end

local Menu

local function deposit(key)
    local res = lib.callback.await('som-launder:server:bills', false, key)
    if not res or not res.success then return notify(res) end
    if #res.bills == 0 then return TriggerEvent('som:client:notify', 'You have nothing to wash', 'inform') end

    local rows = {}
    for _, bill in ipairs(res.bills) do
        rows[#rows + 1] = { type = 'checkbox', label = ('Bill worth %d'):format(bill.worth) }
    end

    local answer = lib.inputDialog('Hand over bills', rows)
    if not answer then return end

    local chosen = {}
    for i, picked in ipairs(answer) do
        if picked then chosen[#chosen + 1] = res.bills[i].uid end
    end

    local done = lib.callback.await('som-launder:server:deposit', false, key, chosen)
    if done and done.success then
        TriggerEvent('som:client:notify',
            ('Ready in %d minutes: %d clean'):format(done.minutes, done.payout), 'success', 8000)
    else
        notify(done)
    end
end

local function collect(key)
    local res = lib.callback.await('som-launder:server:orders', false, key)
    if not res or not res.success then return notify(res) end

    local options = {}
    for _, order in ipairs(res.orders) do
        options[#options + 1] = {
            title = ('Order #%d, %d clean'):format(order.id, order.payout),
            description = order.ready == 1 and 'Ready' or 'Still washing',
            disabled = order.ready ~= 1,
            onSelect = function()
                notify(lib.callback.await('som-launder:server:collect', false, key, order.id))
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'No orders', disabled = true } end

    lib.registerContext({ id = 'launder_orders', title = 'Orders', options = options })
    lib.showContext('launder_orders')
end

Menu = function(key)
    lib.registerContext({
        id = 'launder_front',
        title = Config.Fronts[key].label,
        options = {
            { title = 'Hand over marked bills', onSelect = function() deposit(key) end },
            { title = 'Collect an order', onSelect = function() collect(key) end },
        },
    })
    lib.showContext('launder_front')
end

CreateThread(function()
    for key, front in pairs(Config.Fronts) do
        if front.enabled and front.set then
            exports['som-interact']:addSphereZone({
                name = 'launder:' .. key,
                coords = front.coords,
                radius = front.range,
                options = {
                    {
                        name = 'launder:' .. key,
                        icon = 'fa-solid fa-money-bill-transfer',
                        label = front.label,
                        distance = front.range,
                        onSelect = function() Menu(key) end,
                    },
                },
            })
        end
    end
end)
