--- Contacts, messages and calls. Each is an app run through the pipeline in
--- core.lua, so none repeats the phone, downed, lock, rate and size checks.
--- Numbers resolve to a character on the server; a client never names a source.

local core = exports['som-core']
local ox = exports.ox_inventory

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

---Makes player written text safe for the page and the MDT.
---@param value any
---@param maxLength number
---@return string|nil
local function clean(value, maxLength)
    if type(value) ~= 'string' then return nil end

    local text = value:gsub('[<>]', ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
    if text == '' then return nil end

    return text:sub(1, maxLength)
end

---@param number any
---@return string|nil
local function normalise(number)
    if type(number) ~= 'string' or #number > 16 then return nil end

    local d = number:gsub('%D', '')
    if #d ~= 7 then return nil end

    return ('%s-%s'):format(d:sub(1, 3), d:sub(4))
end

---@param number string
---@return table|nil row { citizenid }
local function owner(number)
    return MySQL.single.await('SELECT citizenid FROM som_characters WHERE phone = ? AND slot IS NOT NULL', { number })
end

---The online player for a number who is carrying a phone, or nil.
---@param number string
---@return table|nil player
local function reachable(number)
    local row = owner(number)
    if not row then return nil end

    local player = core:getPlayerByCitizenId(row.citizenid)
    if not player then return nil end

    if Config.RequireItem and (ox:Search(player.source, 'count', Config.Item) or 0) < 1 then return nil end

    return player
end

local function isBlocked(citizenid, number)
    return MySQL.scalar.await('SELECT 1 FROM som_phone_blocks WHERE citizenid = ? AND number = ?', { citizenid, number }) ~= nil
end

local function nameFor(citizenid, number)
    return MySQL.scalar.await('SELECT name FROM som_phone_contacts WHERE citizenid = ? AND number = ?', { citizenid, number })
end

-- ---------------------------------------------------------------------------
-- Contacts
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'contacts', label = 'Contacts', icon = 'contacts', colour = '#34c759', order = 30,
    actions = {
        list = { fn = function(_, _, player)
            return { contacts = MySQL.query.await(
                'SELECT number, name FROM som_phone_contacts WHERE citizenid = ? ORDER BY name LIMIT ?',
                { player.citizenid, Config.Contacts.max }) or {} }
        end },
        save = { writes = true, fn = function(_, payload, player)
            local number = normalise(payload.number)
            local name = clean(payload.name, Config.Contacts.nameLength)
            if not number or not name then return done(false, 'a name and a seven digit number are needed') end

            local have = MySQL.scalar.await('SELECT COUNT(*) FROM som_phone_contacts WHERE citizenid = ?', { player.citizenid })
            local exists = nameFor(player.citizenid, number) ~= nil
            if not exists and (tonumber(have) or 0) >= Config.Contacts.max then return done(false, 'your contacts are full') end

            MySQL.insert.await([[
                INSERT INTO som_phone_contacts (citizenid, number, name) VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE name = VALUES(name)
            ]], { player.citizenid, number, name })
            return { success = true }
        end },
        remove = { writes = true, fn = function(_, payload, player)
            local number = normalise(payload.number)
            if not number then return done(false, 'bad number') end

            MySQL.update.await('DELETE FROM som_phone_contacts WHERE citizenid = ? AND number = ?', { player.citizenid, number })
            return { success = true }
        end },
        block = { writes = true, fn = function(_, payload, player)
            local number = normalise(payload.number)
            if not number then return done(false, 'bad number') end

            if payload.blocked == false then
                MySQL.update.await('DELETE FROM som_phone_blocks WHERE citizenid = ? AND number = ?', { player.citizenid, number })
            else
                MySQL.insert.await('INSERT IGNORE INTO som_phone_blocks (citizenid, number) VALUES (?, ?)', { player.citizenid, number })
            end
            return { success = true }
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------

---Threads: the latest message per other number, with unread counts.
local function threads(player)
    local me = player.charinfo.phone

    local rows = MySQL.query.await([[
        SELECT other, MAX(id) AS last_id, SUM(unread) AS unread FROM (
            SELECT IF(from_number = ?, to_number, from_number) AS other, id,
                   IF(to_number = ? AND read_at IS NULL, 1, 0) AS unread
            FROM som_phone_messages WHERE from_number = ? OR to_number = ?
        ) t GROUP BY other ORDER BY last_id DESC LIMIT ?
    ]], { me, me, me, me, Config.Messages.threadLimit }) or {}

    for _, row in ipairs(rows) do
        local last = MySQL.single.await('SELECT body, from_number FROM som_phone_messages WHERE id = ?', { row.last_id })
        row.body = last and last.body
        row.mine = last and last.from_number == me
        row.name = nameFor(player.citizenid, row.other)
        row.unread = tonumber(row.unread) or 0
    end

    return rows
end

Phone.Register({
    id = 'messages', label = 'Messages', icon = 'message', colour = '#30d158', order = 15,
    actions = {
        threads = { fn = function(_, _, player) return { threads = threads(player) } end },
        thread = { fn = function(_, payload, player)
            local other = normalise(payload.number)
            if not other then return done(false, 'bad number') end

            local me = player.charinfo.phone
            local rows = MySQL.query.await([[
                SELECT id, from_number, body, created_at FROM som_phone_messages
                WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)
                ORDER BY id DESC LIMIT ?
            ]], { me, other, other, me, Config.Messages.historyLimit }) or {}

            MySQL.update.await(
                'UPDATE som_phone_messages SET read_at = NOW() WHERE to_number = ? AND from_number = ? AND read_at IS NULL',
                { me, other })

            local out = {}
            for i = #rows, 1, -1 do out[#out + 1] = { id = rows[i].id, mine = rows[i].from_number == me, body = rows[i].body, at = rows[i].created_at } end

            return { number = other, name = nameFor(player.citizenid, other), messages = out }
        end },
        send = { writes = true, fn = function(source, payload, player)
            local to = normalise(payload.number)
            local body = clean(payload.body, Config.Messages.maxLength)
            if not to or not body then return done(false, 'a number and a message are needed') end

            local me = player.charinfo.phone
            if to == me then return done(false, 'you cannot message yourself') end

            local target = owner(to)
            if not target then return done(false, 'no such number') end

            -- A block is silent: the sender is told it was sent, so a block cannot be probed.
            if isBlocked(target.citizenid, me) then return { success = true } end

            MySQL.insert.await('INSERT INTO som_phone_messages (from_number, to_number, body) VALUES (?, ?, ?)', { me, to, body })

            local receiver = reachable(to)
            if receiver then
                local label = nameFor(receiver.citizenid, me) or me
                exports['som-phone']:notifyApp(receiver.source, 'messages', ('%s: %s'):format(label, body:sub(1, 80)))
                TriggerClientEvent('som-phone:client:refresh', receiver.source)
            end

            return { success = true }
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Calls
-- ---------------------------------------------------------------------------

Calls = { byId = {}, ofPlayer = {}, nextId = 1 }

local function voice(source, channel)
    if GetResourceState('pma-voice') ~= 'started' then return end
    pcall(function() exports['pma-voice']:setPlayerCall(source, channel) end)
end

local function push(source, state, call, other)
    if not source then return end
    TriggerClientEvent('som-phone:client:call', source, {
        state = state, id = call and call.id, number = other and other.number, name = other and other.name,
    })
end

local function logCall(call, status)
    MySQL.insert.await(
        'INSERT INTO som_phone_calls (from_number, to_number, status, answered) VALUES (?, ?, ?, ?)',
        { call.from.number, call.to.number, status, call.answeredAt and 1 or 0 })
end

---Ends a call for both sides and frees the voice channel. Safe to call twice.
---@param call table
---@param status string 'answered', 'missed', 'declined' or 'unavailable'
function Calls.End(call, status)
    if not Calls.byId[call.id] then return end
    Calls.byId[call.id] = nil

    for _, side in ipairs({ call.from, call.to }) do
        if Calls.ofPlayer[side.source] == call.id then Calls.ofPlayer[side.source] = nil end
        if call.answeredAt then voice(side.source, 0) end
        push(side.source, 'ended', call, side == call.from and call.to or call.from)
    end

    logCall(call, status)
end

---@param source number
---@return table|nil call
function Calls.Of(source)
    return Calls.byId[Calls.ofPlayer[source]]
end

Phone.Register({
    id = 'phone', label = 'Phone', icon = 'phone', colour = '#34c759', order = 5,
    actions = {
        recents = { fn = function(_, _, player)
            local me = player.charinfo.phone
            local rows = MySQL.query.await([[
                SELECT from_number, to_number, status, created_at FROM som_phone_calls
                WHERE from_number = ? OR to_number = ? ORDER BY id DESC LIMIT ?
            ]], { me, me, Config.Calls.historyLimit }) or {}

            for _, row in ipairs(rows) do
                row.outgoing = row.from_number == me
                row.number = row.outgoing and row.to_number or row.from_number
                row.name = nameFor(player.citizenid, row.number)
                row.from_number, row.to_number = nil, nil
            end
            return { recents = rows }
        end },
        dial = { writes = true, fn = function(source, payload, player)
            local to = normalise(payload.number)
            if not to then return done(false, 'dial a seven digit number') end

            local me = player.charinfo.phone
            if to == me then return done(false, 'you cannot call yourself') end
            if Calls.Of(source) then return done(false, 'you are already on a call') end

            local mine = { source = source, number = me, name = nil }
            local receiver = reachable(to)

            local call = { id = Calls.nextId, from = mine, to = { source = receiver and receiver.source, number = to }, startedAt = os.time() }
            Calls.nextId = Calls.nextId + 1

            if not receiver or isBlocked(receiver.citizenid, me) then
                logCall(call, 'unavailable')
                return done(false, 'that number is not available')
            end

            if Calls.Of(receiver.source) then
                logCall(call, 'missed')
                return done(false, 'that line is busy')
            end

            call.to.name, call.from.name = nameFor(player.citizenid, to), nameFor(receiver.citizenid, me)
            Calls.byId[call.id] = call
            Calls.ofPlayer[source], Calls.ofPlayer[receiver.source] = call.id, call.id

            push(source, 'dialling', call, call.to)
            push(receiver.source, 'ringing', call, call.from)

            local id = call.id
            SetTimeout(Config.Calls.ringSeconds * 1000, function()
                local c = Calls.byId[id]
                if c and not c.answeredAt then Calls.End(c, 'missed') end
            end)

            return { success = true }
        end },
        answer = { writes = true, fn = function(source)
            local call = Calls.Of(source)
            if not call or call.to.source ~= source or call.answeredAt then return done(false, 'there is no call to answer') end

            call.answeredAt = os.time()
            call.channel = math.random(Config.Calls.channelMin, Config.Calls.channelMax)

            voice(call.from.source, call.channel)
            voice(call.to.source, call.channel)
            push(call.from.source, 'active', call, call.to)
            push(call.to.source, 'active', call, call.from)

            return { success = true }
        end },
        hangup = { writes = true, fn = function(source)
            local call = Calls.Of(source)
            if not call then return done(false, 'you are not on a call') end

            Calls.End(call, call.answeredAt and 'answered' or (call.from.source == source and 'missed' or 'declined'))
            return { success = true }
        end },
    },
})

---A dropped player, or one who went down, ends their call.
local function leave(source)
    local call = Calls.Of(source)
    if call then Calls.End(call, call.answeredAt and 'answered' or 'missed') end
end

AddEventHandler('playerDropped', function() leave(source) end)
AddEventHandler('som:server:playerDowned', function(src) leave(src) end)
