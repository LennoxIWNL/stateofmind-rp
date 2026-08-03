-- Phone server: app registry, settings, and the callbacks the NUI uses.

local registered = {}

---Apps other resources ship, so this resource does not need to know about
---every feature. som-jobs, som-gangs and the Twitter app in 4b-2 all arrive
---this way rather than being added here.
---@param app table { id, label, icon, colour, order, perk }
exports('registerApp', function(app)
    if type(app) ~= 'table' or type(app.id) ~= 'string' then return false end

    registered[app.id] = {
        id = app.id,
        label = app.label or app.id,
        icon = app.icon or '?',
        colour = app.colour or '#ff1493',
        order = app.order or 50,
        perk = app.perk,
        resource = GetInvokingResource(),
    }

    return true
end)

---@param source number
---@return table[] apps this player may see
local function appsFor(source)
    local list = {}

    local function consider(app)
        -- Perk-gated apps are filtered SERVER side. Sending them and hiding
        -- them in the UI would mean the client decides what it is entitled to.
        if app.perk and not exports['som-core']:hasPerk(source, app.perk) then return end
        list[#list + 1] = app
    end

    for _, app in ipairs(Config.Apps) do consider(app) end
    for _, app in pairs(registered) do consider(app) end

    table.sort(list, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return list
end

---@param source number
---@return table
local function settingsFor(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return { theme = 'default', wallpaper = 'default' } end

    local row = MySQL.single.await(
        'SELECT theme, wallpaper FROM som_phone_settings WHERE citizenid = ?',
        { player.citizenid })

    return row or { theme = 'default', wallpaper = 'default' }
end

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

lib.callback.register('som-phone:server:open', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    -- The phone is an item, so having one is checked here rather than assumed.
    if Config.RequireItem and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(source, Config.Item)
        if not count or count < 1 then
            return { success = false, error = 'You do not have a phone' }
        end
    end

    -- Home screen badges. One scalar per app rather than loading the app
    -- itself, so an unread count is visible without opening anything.
    local pendingBills = MySQL.scalar.await(
        'SELECT COUNT(*) FROM som_phone_bills WHERE to_citizenid = ? AND status = ?',
        { player.citizenid, 'pending' }) or 0

    return {
        success = true,
        apps = appsFor(source),
        settings = settingsFor(source),
        themes = Config.Themes,
        owner = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        number = player.charinfo.phone,
        badges = { bank = pendingBills },
    }
end)

lib.callback.register('som-phone:server:bank', function(source)
    return Bank.GetOverview(source)
end)

lib.callback.register('som-phone:server:shareAccount', function(source)
    local ok, result = Bank.ShareAccount(source)
    return { success = ok, error = not ok and result or nil, shared = ok and result or 0 }
end)

lib.callback.register('som-phone:server:createBill', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local ok, err = Bank.CreateBill(source, data.accountNo, data.amount, data.reason)
    return { success = ok, error = not ok and err or nil }
end)

lib.callback.register('som-phone:server:payBill', function(source, billId)
    local ok, err = Bank.PayBill(source, billId)
    return { success = ok, error = err }
end)

lib.callback.register('som-phone:server:declineBill', function(source, billId)
    local ok, err = Bank.DeclineBill(source, billId)
    return { success = ok, error = err }
end)

lib.callback.register('som-phone:server:transfer', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local ok, err = Bank.Transfer(source, data.accountNo, data.amount)
    return { success = ok, error = err }
end)

lib.callback.register('som-phone:server:setTheme', function(source, theme)
    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false } end

    local def = Config.Themes[theme]
    if not def then return { success = false, error = 'unknown theme' } end

    -- Themes are a supporter perk, so entitlement is checked here. The client
    -- listing a theme does not mean it may select it.
    if def.perk and not exports['som-core']:hasPerk(source, def.perk) then
        return { success = false, error = 'That theme is not unlocked' }
    end

    MySQL.insert.await([[
        INSERT INTO som_phone_settings (citizenid, theme) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE theme = VALUES(theme)
    ]], { player.citizenid, theme })

    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(2000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_phone_bills LIMIT 1')
    end)

    if not ok then
        print('[som-phone] som_phone_* tables are missing. Import setup.sql before starting.')
        return
    end

    -- Auto collection sweep. Nothing sets auto_collect yet; som-police will,
    -- for fines. Harmless until then.
    while true do
        Wait(Config.Bank.bill.autoCollectInterval * 60000)
        pcall(Bank.CollectOverdue)
    end
end)

-- ---------------------------------------------------------------------------
-- App notifications
--
-- The one way another resource puts a notification ON THE PHONE. It exists so
-- callers name an APP rather than an icon, which keeps the icon and the label
-- decided here instead of in every resource that wants to say something.
--
-- WHAT BELONGS HERE, and what does not:
--
-- The phone is not the notification system. "You are now on duty", "too far
-- away" and "you do not have permission" are world feedback and belong in the
-- som-ui toast via som:client:notify, because they are the game talking to the
-- player, not an app talking to them.
--
-- A phone notification is for something that would genuinely reach you through
-- a device: a bill, a bank transfer, a message, a dispatch call, a job offer.
-- The test is whether it would still make sense if the player had left their
-- phone at home. If it would, it is not a phone notification.
-- ---------------------------------------------------------------------------

---Icons are resolved from Config.Apps so an app only declares its icon once.
---@param appId string
---@return string label, string icon
local function appIdentity(appId)
    for _, app in ipairs(Config.Apps or {}) do
        if app.id == appId then return app.label, app.icon end
    end

    -- An unknown app still notifies rather than failing silently. `system` is
    -- the catch-all for anything without an app of its own yet.
    return 'System', 'settings'
end

---@param source number
---@param appId string an id from Config.Apps, or 'system'
---@param text string
---@return boolean
exports('notifyApp', function(source, appId, text)
    if type(text) ~= 'string' or text == '' then return false end

    local id = tonumber(source)
    if not id or id <= 0 then return false end

    local label, icon = appIdentity(type(appId) == 'string' and appId or 'system')

    TriggerClientEvent('som-phone:client:banner', id, label, text, icon)
    return true
end)
