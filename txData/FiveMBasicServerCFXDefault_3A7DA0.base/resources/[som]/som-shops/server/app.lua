--- The owner's phone view: balance, the last day's takings, stock and staff. Reading only, plus
--- letting a worker go. Anyone who owns no shop sees an empty page. Made by Lennox.

local core = exports['som-core']
local done = Shops.Done

local function ownedShop(player)
    local id = MySQL.scalar.await('SELECT shop_id FROM som_shops WHERE owner = ?', { player.citizenid })
    for _, shop in ipairs(Config.shops) do
        if shop.id == id then return shop end
    end
end

local function view(player)
    local shop = ownedShop(player)
    if not shop then return { sections = {}, empty = 'You do not own a shop' } end

    local o = Shops.Overview(shop)
    local stock, staff = {}, {}
    for _, s in ipairs(o.stock) do stock[#stock + 1] = { title = ('%s x%d'):format(s.item:gsub('_', ' '), s.qty), sub = ('$%d each'):format(s.price) } end
    for _, w in ipairs(o.staff) do
        staff[#staff + 1] = { title = ('%s %s'):format(w.firstname, w.lastname), sub = ('$%d an hour, tap to let go'):format(w.hourly_pay), action = 'fire', payload = { citizenid = w.citizenid } }
    end

    return { sections = {
        { title = shop.label, rows = {
            { title = ('Balance $%d'):format(o.balance) },
            { title = ('Takings, last day $%d'):format(o.takings) },
        } },
        { title = 'Stock', rows = stock },
        { title = 'Staff', rows = staff },
    }, empty = 'Nothing here yet' }
end

local actions = {}

function actions.view(_, _, player) return done(true, nil, { view = view(player) }) end

function actions.fire(_, payload, player)
    local shop = ownedShop(player)
    if not shop or type(payload.citizenid) ~= 'string' then return done(false, 'not available') end

    local gone = MySQL.update.await('DELETE FROM som_shop_staff WHERE shop_id = ? AND citizenid = ?', { shop.id, payload.citizenid })
    if (gone or 0) < 1 then return done(false, 'they do not work here') end
    return done(true)
end

exports['som-phone']:registerApp({
    id = 'shop', label = 'My Shop', icon = 'receipt', colour = '#30d158', order = 66,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})
