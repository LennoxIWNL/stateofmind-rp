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

--- Downed players cannot use anything.
---
--- SERVER SIDE, because that is the only side that counts. A client gate stops
--- an honest player pressing a key; it does nothing about a crafted event, and
--- "bleeding out" is exactly the state somebody has a reason to cheat their way
--- out of.
---
--- Guarded on the resource being started so the phone still runs without
--- som-medical, and defaults to NOT downed in that case rather than locking
--- everyone out if medical is missing.
local function isDowned(source)
    if GetResourceState('som-medical') ~= 'started' then return false end
    return exports['som-medical']:isDowned(source) == true
end

lib.callback.register('som-phone:server:open', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    if isDowned(source) then
        return { success = false, error = 'You are in no state to use a phone' }
    end

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

    -- REGISTERED APPS TOO. This used to scan Config.Apps only, so every app
    -- added through the registerApp export bannered as "System" with the
    -- settings gear no matter what it declared, directly contradicting the
    -- comment beside registerApp that says an app declares its icon once.
    for _, app in pairs(registered or {}) do
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

-- ---------------------------------------------------------------------------
-- Card alerts
--
-- som-core fires som:server:moneyChanged on the ONE choke point every money
-- movement passes through, so this needs no cooperation from the resources that
-- spend money and cannot be forgotten by a new one.
--
-- Aggregated per player per label. Buying three things at the armoury inside the
-- window produces one banner reading "Purchase  -$1,450  (3)" rather than three
-- banners, which is the difference between an alert and a phone that buzzes
-- continuously while you shop.
--
-- The label comes from Bank.StatementLabel, the same whitelist the statement
-- uses. A banner is bank UI, so the rule that a raw ledger slug never reaches a
-- player applies here exactly as it does there.
-- ---------------------------------------------------------------------------

-- pending[source][account .. '|' .. label] = { account, label, out, inn,
--                                              outCount, inCount }
--
-- Money out and money in are accumulated SEPARATELY rather than summed into one
-- signed total. Summing looked tidier and was wrong: som-police charges for an
-- armoury item and then refunds the identical amount milliseconds later if
-- ox_inventory has no room, always inside the same window, so the two netted to
-- zero and the banner read "+$0 (2)". som-rentals has the same charge-then-
-- refund pair. Partial offsets were worse, silently hiding two real movements
-- behind one misleading number.
--
-- Keyed by ACCOUNT as well as label now that cash alerts too. Keying by label
-- alone would merge a cash purchase and a card purchase of the same kind into
-- one line, and then have to pick one of the two tags to put on it.
local pending = {}

---Thousands separators.
---
---The aggregation comment upstream has always claimed the banner reads
---"Purchase  -$1,450". It read "-$1450": the amount went through %s as a raw
---number. Every other money string a player sees on this server is grouped.
---@param amount number
---@return string
local function comma(amount)
    local whole = ('%d'):format(math.floor(tonumber(amount) or 0))
    local out = whole:reverse():gsub('(%d%d%d)', '%1,'):reverse()

    -- The reverse-and-group leaves a leading comma on exact multiples of three
    -- digits, so 1000 comes back as ",1,000".
    return (out:gsub('^,', ''))
end

---@param reason string
local function debugDrop(source, reason)
    if not Config.CardAlerts or not Config.CardAlerts.debug then return end
    print(('[som-phone] card alert for %s dropped: %s'):format(source, reason))
end

-- A monotonic token per scheduled flush rather than a boolean. Server ids are
-- recycled on reconnect, so a timer armed for a player who then disconnects
-- would otherwise fire against whoever inherited the id, clear their guard, and
-- leave two timers racing until every movement flushed on its own.
local flushToken = {}
local nextToken = 0

---@param source number
---@param token number
local function flushCardAlerts(source, token)
    -- Not ours any more. The player this was armed for has gone.
    if flushToken[source] ~= token then return end

    local mine = pending[source]

    pending[source] = nil
    flushToken[source] = nil

    if not mine then return end

    for _, entry in pairs(mine) do
        local tag = entry.tag and ('  %s'):format(entry.tag) or ''

        -- One line per direction, so a charge and a refund under one label are
        -- both stated instead of cancelling.
        if entry.out > 0 then
            local times = entry.outCount > 1 and ('  (%d)'):format(entry.outCount) or ''
            exports['som-phone']:notifyApp(source, 'bank',
                ('%s  -$%s%s%s'):format(entry.label, comma(entry.out), tag, times))
        end

        if entry.inn > 0 then
            local times = entry.inCount > 1 and ('  (%d)'):format(entry.inCount) or ''
            exports['som-phone']:notifyApp(source, 'bank',
                ('%s  +$%s%s%s'):format(entry.label, comma(entry.inn), tag, times))
        end
    end
end

AddEventHandler('som:server:moneyChanged', function(source, _, account, delta, _, reason)
    local cfg = Config.CardAlerts
    if not cfg or not cfg.enabled then return end

    local rule = cfg.accounts[account]
    if not rule then return end

    delta = tonumber(delta) or 0
    if math.abs(delta) < (cfg.minAmount or 1) then return end

    source = tonumber(source)
    if not source or source <= 0 then return end

    -- The phone is an item that can be lost, stolen or confiscated, and
    -- som-phone:server:open already refuses to open without one. A card alert
    -- buzzing in the pocket of somebody whose phone was just taken off them in
    -- custody would contradict that outright.
    if Config.RequireItem and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(source, Config.Item)
        if not count or count < 1 then
            debugDrop(source, ('no %s in inventory'):format(Config.Item))
            return
        end
    end

    local label = Bank.StatementLabel and Bank.StatementLabel(reason) or 'Transaction'
    local key = ('%s|%s'):format(account, label)

    local mine = pending[source]

    if not mine then
        mine = {}
        pending[source] = mine
    end

    local entry = mine[key]

    if not entry then
        entry = {
            label = label,
            tag = rule.tag,
            out = 0, inn = 0, outCount = 0, inCount = 0,
        }
        mine[key] = entry
    end

    if delta < 0 then
        entry.out = entry.out + math.abs(delta)
        entry.outCount = entry.outCount + 1
    else
        entry.inn = entry.inn + delta
        entry.inCount = entry.inCount + 1
    end

    -- One timer per player per window, not one per movement. Without this guard
    -- every purchase would schedule its own flush and the aggregation would
    -- fire once per transaction anyway, which is the bug it exists to prevent.
    if flushToken[source] then return end

    nextToken = nextToken + 1
    local token = nextToken
    flushToken[source] = token

    SetTimeout(cfg.window or 4000, function() flushCardAlerts(source, token) end)
end)

-- A player who leaves mid-window has nothing to be told and no client to tell.
--
-- The armed timer cannot be cancelled, so clearing the token is what disarms
-- it: the flush checks the token still matches before doing anything.
AddEventHandler('playerDropped', function()
    local source = source
    pending[source] = nil
    flushToken[source] = nil
end)

-- ---------------------------------------------------------------------------
-- Testing the notification peek
--
-- A phone notification is hard to exercise deliberately: the real ones fire on
-- a bill arriving or a transfer landing, which needs a second player and a
-- reason. This raises one on demand so the peek animation, the app icon and the
-- routing can be checked in isolation.
--
-- Registered UNRESTRICTED and permission-checked in the handler, for the reason
-- documented on som-core's Permissions.AddCommand: lib.addCommand's `restricted`
-- hands the check to FiveM's ACE, which refuses the command before any Lua runs
-- and prints nothing anywhere.
-- ---------------------------------------------------------------------------

lib.addCommand('testphone', {
    help = 'Send yourself a test phone notification',
    params = {
        { name = 'app', type = 'string', help = 'App id, or "system"', optional = true },
        { name = 'text', type = 'longString', help = 'Message', optional = true },
    },
}, function(source, args)
    if source == 0 then return end

    if not exports['som-core']:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source,
            'You do not have permission to do that', 'error')
    end

    local app = args.app or 'bank'
    local text = args.text or 'This is a test notification.'

    local sent = exports['som-phone']:notifyApp(source, app, text)

    -- Says which app it resolved to, because an unknown id silently falls back
    -- to System and looking at the wrong icon while wondering why is a waste of
    -- a test.
    TriggerClientEvent('som:client:notify', source,
        sent and ('Sent as "%s". Close the phone to see the peek.'):format(app)
            or 'Could not send that',
        sent and 'success' or 'error')
end)

-- The world toast, for comparison. The two are different systems on purpose and
-- seeing them back to back is the quickest way to confirm the split is right.
lib.addCommand('testnotify', {
    help = 'Send yourself a test world notification (not the phone)',
    params = {
        { name = 'text', type = 'longString', help = 'Message', optional = true },
    },
}, function(source, args)
    if source == 0 then return end

    if not exports['som-core']:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source,
            'You do not have permission to do that', 'error')
    end

    TriggerClientEvent('som:client:notify', source,
        args.text or 'This is a world notification, not a phone one.', 'inform', 6000)
end)

--- The Properties app.
---
--- A READ-ONLY VIEW over som-housing. Every number here is resolved by that
--- resource from its own tables; the phone renders and decides nothing, which
--- is why there is no property id in the request and no way to act on one.
--- Buying, keys and mortgages all happen at the door, in person.
lib.callback.register('som-phone:server:properties', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false } end

    if GetResourceState('som-housing') ~= 'started' then
        return { success = false, error = 'Properties is unavailable' }
    end

    local owned = exports['som-housing']:listFor(player.citizenid) or {}
    local finance = exports['som-housing']:financeListFor(player.citizenid) or {}

    return { success = true, properties = owned, finance = finance }
end)
