-- =========================================================================
--  Lennox Anti-Cheat v3.0 — Protection Module
--  Economy, Inventory, Permission, Chat, Connection, Entity Protection
-- =========================================================================

local cfg = LACConfig

-- =========================================================================
--  1. Exploitable Event Monitoring
--     These are real events in QBCore that have no server-side validation.
--     We intercept them and validate before allowing through.
-- =========================================================================
local ExploitableEvents = {
    ['qb-inventory:server:recieveItem'] = {
        handler = function(src, item, amount)
            amount = tonumber(amount) or 0
            if amount > (cfg.MaxDumpsterItemAmount or 5) then
                LAC.flagPlayer(src, 'Item Spawn Exploit',
                    ('Tried to receive %d of %s via dumpster'):format(amount, tostring(item)), 15, true)
                LAC.sendDiscord('bans', 'ITEM EXPLOIT',
                    ('**Player:** %s (id: %s)\n**Item:** %s x%d\n**Via:** qb-inventory:server:recieveItem')
                        :format(GetPlayerName(src) or '?', src, tostring(item), amount), 16711680, true)
                return true
            end
        end,
    },
    ['qb-inventory:server:givemoney'] = {
        handler = function(src, money)
            money = tonumber(money) or 0
            if money > (cfg.MaxDumpsterCash or 500) then
                LAC.flagPlayer(src, 'Money Spawn Exploit',
                    ('Tried to give self $%d via dumpster'):format(money), 15, true)
                LAC.sendDiscord('bans', 'MONEY EXPLOIT',
                    ('**Player:** %s (id: %s)\n**Amount:** $%d\n**Via:** qb-inventory:server:givemoney')
                        :format(GetPlayerName(src) or '?', src, money), 16711680, true)
                return true
            end
        end,
    },
}

local EventRateTracker = {}

for eventName, def in pairs(ExploitableEvents) do
    AddEventHandler(eventName, function(...)
        local src = source
        if not src or src <= 0 then return end
        if LAC.isAdmin(src) then return end

        local now = GetGameTimer()
        if not EventRateTracker[src] then EventRateTracker[src] = {} end
        if not EventRateTracker[src][eventName] then EventRateTracker[src][eventName] = { count = 0, reset = now } end
        local er = EventRateTracker[src][eventName]

        if now - er.reset > 10000 then er.count = 0; er.reset = now end
        er.count = er.count + 1

        if er.count > (cfg.ExploitEventRateLimit or 10) then
            LAC.flagPlayer(src, 'Event Abuse',
                ('Triggered %s %d times in 10s'):format(eventName, er.count), 10, true)
            CancelEvent()
            return
        end

        if def.handler then
            local blocked = def.handler(src, ...)
            if blocked then CancelEvent() end
        end
    end)
end

-- =========================================================================
--  2. Permission Escalation Detection
--     Detect players granting themselves admin aces
-- =========================================================================
local DANGEROUS_COMMANDS = {
    'add_ace', 'add_principal', 'remove_ace', 'remove_principal',
    'stop', 'start', 'restart', 'refresh', 'exec',
    'quit', 'load_server_icon',
}

for _, cmd in ipairs(DANGEROUS_COMMANDS) do
    RegisterCommand(cmd, function(source)
        local src = source
        if src > 0 then
            LAC.flagPlayer(src, 'Dangerous Command',
                ('Attempted: %s'):format(cmd), 20, true)
            LAC.sendDiscord('bans', 'PERMISSION ESCALATION ATTEMPT',
                ('**Player:** %s (id: %s)\n**Command:** `%s`\n**Verdict:** Non-console player tried to execute a server management command.')
                    :format(GetPlayerName(src) or '?', src, cmd), 16711680, true)
        end
    end, true)
end

-- =========================================================================
--  3. Chat Spam Protection
-- =========================================================================
local ChatTracker = {}

AddEventHandler('chatMessage', function(src, author, msg)
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end

    local now = GetGameTimer()
    if not ChatTracker[src] then ChatTracker[src] = { count = 0, reset = now, lastMsg = '' } end
    local ct = ChatTracker[src]

    if now - ct.reset > 5000 then ct.count = 0; ct.reset = now end
    ct.count = ct.count + 1

    if ct.count > (cfg.MaxChatMessagesPerWindow or 8) then
        LAC.flagPlayer(src, 'Chat Spam',
            ('%d messages in 5s'):format(ct.count), 3, false)
        CancelEvent()
        return
    end

    if msg == ct.lastMsg and #msg > 3 then
        ct.dupeCount = (ct.dupeCount or 0) + 1
        if ct.dupeCount >= 4 then
            LAC.flagPlayer(src, 'Chat Flood (duplicates)',
                ('Same message x%d'):format(ct.dupeCount), 3, false)
            CancelEvent()
            ct.dupeCount = 0
            return
        end
    else
        ct.dupeCount = 0
    end
    ct.lastMsg = msg
end)

-- =========================================================================
--  4. Connection Flood Protection
-- =========================================================================
local ConnectTracker = {}

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end

    for _, id in ipairs(ids) do
        if ConnectTracker[id] then
            local ct = ConnectTracker[id]
            local now = os.time()
            if now - ct.lastAttempt < 30 then
                ct.count = ct.count + 1
                if ct.count >= (cfg.MaxReconnectsPerMinute or 5) then
                    deferrals.defer()
                    Wait(0)
                    deferrals.done('[Lennox Anti-Cheat] Too many connection attempts. Please wait 60 seconds.')
                    LAC.sendDiscord('connections', 'Connection Flood',
                        ('**Player:** %s\n**Identifier:** %s\n**Attempts:** %d in 30s')
                            :format(name, id, ct.count), 16776960)
                    return
                end
            else
                ct.count = 1
            end
            ct.lastAttempt = now
        else
            ConnectTracker[id] = { count = 1, lastAttempt = os.time() }
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for id, ct in pairs(ConnectTracker) do
            if now - ct.lastAttempt > 120 then ConnectTracker[id] = nil end
        end
    end
end)

-- =========================================================================
--  5. Mass Entity Deletion Detection
-- =========================================================================
local EntityDeleteTracker = {}

AddEventHandler('entityRemoved', function(entity)
    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 then return end
    if LAC.isAdmin(owner) then return end

    local now = GetGameTimer()
    if not EntityDeleteTracker[owner] then EntityDeleteTracker[owner] = { count = 0, reset = now } end
    local et = EntityDeleteTracker[owner]

    if now - et.reset > 5000 then et.count = 0; et.reset = now end
    et.count = et.count + 1

    if et.count > (cfg.MaxEntityDeletionsPer5Sec or 30) then
        LAC.flagPlayer(owner, 'Mass Entity Deletion',
            ('%d entities deleted in 5s'):format(et.count), 8, false)
        LAC.sendDiscord('events', 'Mass Entity Deletion',
            ('**Player:** %s (id: %s)\n**Deleted:** %d entities in 5s')
                :format(GetPlayerName(owner) or '?', owner, et.count), 16711680)
    end
end)

-- =========================================================================
--  6. Screenshot on Ban (requires screenshot-basic)
-- =========================================================================
local origBanPlayer = LAC.banPlayer

LAC.banPlayer = function(src, reason, details, bypassImmunity)
    src = tonumber(src)
    if not src then return end

    if cfg.ScreenshotOnBan and GetResourceState('screenshot-basic') == 'started' then
        pcall(function()
            exports['screenshot-basic']:requestClientScreenshot(src, {
                encoding = 'png',
                quality = 0.8,
            }, function(err, data)
                if not err and data then
                    LAC.sendDiscord('bans', 'Ban Screenshot — ' .. (GetPlayerName(src) or '?'),
                        ('**Player:** %s (id: %s)\n**Reason:** %s\n[Screenshot captured at time of ban]')
                            :format(GetPlayerName(src) or '?', src, reason), 16711680)
                end
            end)
        end)
    end

    return origBanPlayer(src, reason, details, bypassImmunity)
end

-- =========================================================================
--  7. Weapon Give Event Monitoring
-- =========================================================================
local WeaponGiveTracker = {}

AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end

    if data and data.weaponType then
        local now = GetGameTimer()
        if not WeaponGiveTracker[src] then WeaponGiveTracker[src] = {} end
        local wt = WeaponGiveTracker[src]

        if not wt[data.weaponType] then
            wt[data.weaponType] = { first = now, count = 0 }
        end
        local entry = wt[data.weaponType]
        entry.count = entry.count + 1

        if entry.count > 200 and (now - entry.first) < 60000 then
            LAC.flagPlayer(src, 'Weapon Damage Spam',
                ('Weapon 0x%X: %d hits in %ds'):format(data.weaponType, entry.count, (now - entry.first) / 1000),
                5, false)
            entry.count = 0
            entry.first = now
        end
    end
end)

-- =========================================================================
--  8. Inventory Transaction Audit
--     Track total items added per player per session for anomaly detection
-- =========================================================================
local ItemAudit = {}

AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    ItemAudit[src] = { totalAdded = 0, totalRemoved = 0, startTime = GetGameTimer() }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local audit = ItemAudit[src]
    if audit then
        local elapsed = (GetGameTimer() - audit.startTime) / 60000
        if elapsed > 5 and audit.totalAdded > 500 then
            LAC.sendDiscord('events', 'High Item Volume (Session End)',
                ('**Player:** %s (id: %s)\n**Items Added:** %d\n**Items Removed:** %d\n**Session:** %.0f min')
                    :format(GetPlayerName(src) or '?', src, audit.totalAdded, audit.totalRemoved, elapsed),
                16776960)
        end
    end
    ItemAudit[src] = nil
    EventRateTracker[src] = nil
    ChatTracker[src] = nil
    EntityDeleteTracker[src] = nil
    WeaponGiveTracker[src] = nil
end)

-- =========================================================================
--  9. Resource Stop/Start Monitoring
--     Alert if non-AC resources are stopped/started during runtime
-- =========================================================================
local RuntimeResources = {}
local resourcesLoaded = false

CreateThread(function()
    Wait(30000)
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            RuntimeResources[name] = true
        end
    end
    resourcesLoaded = true
end)

AddEventHandler('onResourceStart', function(res)
    if not resourcesLoaded then return end
    if res == GetCurrentResourceName() then return end
    if not RuntimeResources[res] then
        LAC.sendDiscord('connections', 'NEW RESOURCE STARTED AT RUNTIME',
            ('**Resource:** `%s`\n**Action:** Started after server boot — could indicate injection or unauthorized access.')
                :format(res), 16776960, true)
    end
    RuntimeResources[res] = true
end)

AddEventHandler('onResourceStop', function(res)
    if not resourcesLoaded then return end
    if res == GetCurrentResourceName() then return end
    LAC.sendDiscord('connections', 'RESOURCE STOPPED AT RUNTIME',
        ('**Resource:** `%s` was stopped during runtime.')
            :format(res), 16776960)
end)

-- =========================================================================
--  10. Server-Side Wanted Level Monitoring
-- =========================================================================
CreateThread(function()
    Wait(20000)
    while true do
        Wait(10000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local wanted = GetPlayerWantedLevel(src) or 0
                if wanted > 5 then
                    LAC.flagPlayer(src, 'Invalid Wanted Level',
                        ('Wanted: %d (max 5)'):format(wanted), 5, true)
                end
            end
        end
    end
end)
