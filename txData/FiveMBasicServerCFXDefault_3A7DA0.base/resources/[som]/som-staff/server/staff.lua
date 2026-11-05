--- Staff tools: a report queue for players, and goto, bring and spectate for
--- staff. Every staff action checks ACE on the server and writes an audit row.
--- The client menu only asks; it never decides who may see or do anything.

local core = exports['som-core']

local lastReport = {}

local function notify(source, text, kind)
    TriggerClientEvent('som:client:notify', source, text, kind or 'inform')
end

local function isStaff(source) return core:hasPermission(source, 'som.mod') end

local function clean(text, max)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if text == '' then return nil end
    return text:sub(1, max)
end

local function actor(source)
    local player = core:getPlayer(source)
    return (player and player.citizenid) or ('source:%d'):format(source)
end

local function audit(source, action, target, detail)
    MySQL.insert.await('INSERT INTO som_staff_audit (staff, action, target, detail) VALUES (?, ?, ?, ?)',
        { actor(source), action, target and tostring(target):sub(1, 48) or nil, detail and tostring(detail):sub(1, 200) or nil })
end

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

lib.addCommand('report', {
    help = 'Ask staff for help',
    params = { { name = 'message', type = 'longString' } },
}, function(source, args)
    local player = core:getPlayer(source)
    if not player then return end

    local text = clean(args.message, Config.reportMax)
    if not text then return notify(source, 'Say what the problem is', 'error') end

    local now = GetGameTimer()
    if lastReport[player.citizenid] and now - lastReport[player.citizenid] < Config.reportCooldown * 1000 then
        return notify(source, 'Wait a moment before sending another report', 'error')
    end
    lastReport[player.citizenid] = now

    local id = MySQL.insert.await(
        [[INSERT INTO som_reports (citizenid, name, message)
          SELECT ?, ?, ? FROM DUAL
          WHERE NOT EXISTS (SELECT 1 FROM som_reports WHERE citizenid = ? AND status <> 'closed')]],
        { player.citizenid, (GetPlayerName(source) or 'unknown'):sub(1, 64), text, player.citizenid })
    if not id or id < 1 then return notify(source, 'You already have an open report', 'error') end

    notify(source, ('Report #%d sent'):format(id), 'success')
    for _, id2 in ipairs(GetPlayers()) do
        local staff = tonumber(id2)
        if staff and isStaff(staff) then notify(staff, ('New report #%d'):format(id)) end
    end
end)

lib.callback.register('som-staff:server:reports', function(source)
    if not isStaff(source) then return nil end
    return MySQL.query.await(
        [[SELECT id, citizenid, name, message, status, claimed_by FROM som_reports
          WHERE status <> 'closed' ORDER BY id LIMIT ?]], { Config.listMax }) or {}
end)

lib.callback.register('som-staff:server:reportAction', function(source, id, action)
    if not isStaff(source) then return { success = false, error = 'no permission' } end
    id = math.type(id) == 'integer' and id or nil
    if not id or (action ~= 'claim' and action ~= 'close') then return { success = false, error = 'bad request' } end

    local n
    if action == 'claim' then
        n = MySQL.update.await("UPDATE som_reports SET status = 'claimed', claimed_by = ? WHERE id = ? AND status = 'open'", { actor(source), id })
    else
        n = MySQL.update.await("UPDATE som_reports SET status = 'closed' WHERE id = ? AND status <> 'closed'", { id })
    end
    if (n or 0) < 1 then return { success = false, error = 'that report changed, look again' } end
    audit(source, 'report_' .. action, id)
    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Goto, bring, spectate
-- ---------------------------------------------------------------------------

local function targetOf(source, args)
    if not isStaff(source) then
        notify(source, 'You do not have permission to do that', 'error')
        return
    end
    local target = args.target
    if not target or GetPlayerPed(target) == 0 or target == source then
        notify(source, 'No such player', 'error')
        return
    end
    return target
end

local function move(who, to)
    local pos = GetEntityCoords(GetPlayerPed(to))
    SetEntityCoords(GetPlayerPed(who), pos.x, pos.y, pos.z, false, false, false, false)
end

lib.addCommand('goto', { help = 'Go to a player', params = { { name = 'target', type = 'playerId' } } }, function(source, args)
    local target = targetOf(source, args)
    if not target then return end
    move(source, target)
    audit(source, 'goto', actor(target))
end)

lib.addCommand('bring', { help = 'Bring a player to you', params = { { name = 'target', type = 'playerId' } } }, function(source, args)
    local target = targetOf(source, args)
    if not target then return end
    move(target, source)
    audit(source, 'bring', actor(target))
end)

lib.addCommand('spectate', { help = 'Watch a player, again to stop', params = { { name = 'target', type = 'playerId', optional = true } } }, function(source, args)
    if not isStaff(source) then return notify(source, 'You do not have permission to do that', 'error') end
    if not args.target then return TriggerClientEvent('som-staff:client:spectate', source, nil) end

    local target = targetOf(source, args)
    if not target then return end
    TriggerClientEvent('som-staff:client:spectate', source, target)
    audit(source, 'spectate', actor(target))
end)

-- ---------------------------------------------------------------------------
-- Kick, ban, freeze, audit
-- ---------------------------------------------------------------------------

local frozen = {}

local function admin(source)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then
        notify(source, 'You do not have permission to do that', 'error')
        return false
    end
    return true
end

local function playerIdentifiers(target)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(target) - 1 do
        local id = Whitelist.Normalise(GetPlayerIdentifier(target, i))
        if id then ids[#ids + 1] = id end
    end
    return ids
end

local function cleanReason(text)
    return clean(text, 120) or 'No reason given'
end

lib.addCommand('kick', {
    help = 'Remove a player from the server',
    params = { { name = 'target', type = 'playerId' }, { name = 'reason', type = 'longString', optional = true } },
}, function(source, args)
    local target = targetOf(source, args)
    if not target then return end

    local reason = cleanReason(args.reason)
    audit(source, 'kick', actor(target), reason)
    DropPlayer(target, 'Kicked: ' .. reason)
end)

lib.addCommand('ban', {
    help = 'Ban a player. Hours 0 is permanent',
    params = {
        { name = 'target', type = 'playerId' },
        { name = 'hours', type = 'number' },
        { name = 'reason', type = 'longString', optional = true },
    },
}, function(source, args)
    if not admin(source) then return end
    if source ~= 0 and (args.target == source or GetPlayerPed(args.target) == 0) then return notify(source, 'No such player', 'error') end

    local hours = math.floor(tonumber(args.hours) or -1)
    if hours < 0 or hours > 24 * 365 then return notify(source, 'Hours must be 0 (permanent) to 8760', 'error') end

    local reason = cleanReason(args.reason)
    local ids = playerIdentifiers(args.target)
    if #ids == 0 then return notify(source, 'That player has no identifiers to ban', 'error') end

    local who = source == 0 and 'console' or actor(source)
    for _, id in ipairs(ids) do
        MySQL.insert.await(
            'INSERT INTO som_bans (identifier, reason, banned_by, expires_at) VALUES (?, ?, ?, IF(? = 0, NULL, DATE_ADD(NOW(), INTERVAL ? HOUR)))',
            { id, reason, who, hours, hours })
    end

    if source ~= 0 then audit(source, 'ban', ids[1], ('%dh %s'):format(hours, reason)) end
    DropPlayer(args.target, 'Banned: ' .. reason)
end)

lib.addCommand('unban', {
    help = 'Lift every active ban on an identifier',
    params = { { name = 'identifier', type = 'string' } },
}, function(source, args)
    if not admin(source) then return end

    local id = Whitelist.Normalise(args.identifier)
    if not id then return notify(source, 'Not a valid identifier', 'error') end

    local n = MySQL.update.await('UPDATE som_bans SET revoked = 1 WHERE identifier = ? AND revoked = 0', { id })
    if source ~= 0 then audit(source, 'unban', id) end
    local text = (n or 0) > 0 and 'Ban lifted' or 'No active ban for that identifier'
    if source == 0 then print('[som-staff] ' .. text) else notify(source, text) end
end)

lib.addCommand('freeze', { help = 'Freeze or release a player', params = { { name = 'target', type = 'playerId' } } }, function(source, args)
    local target = targetOf(source, args)
    if not target then return end

    frozen[target] = not frozen[target] or nil
    TriggerClientEvent('som-staff:client:freeze', target, frozen[target] == true)
    audit(source, frozen[target] and 'freeze' or 'unfreeze', actor(target))
end)

AddEventHandler('playerDropped', function()
    frozen[source] = nil
end)

lib.callback.register('som-staff:server:audit', function(source)
    if not isStaff(source) then return nil end
    return MySQL.query.await('SELECT staff, action, target, detail FROM som_staff_audit ORDER BY id DESC LIMIT ?', { Config.listMax }) or {}
end)
