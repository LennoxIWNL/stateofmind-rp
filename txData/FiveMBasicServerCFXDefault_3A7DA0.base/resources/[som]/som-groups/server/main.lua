--- Groups live in memory only: a group is session state, so a restart
--- disbands them and no row can drift from who is actually online. The phone
--- app is the only way in. A job resource asks about a group through the
--- exports at the bottom; it never trusts a client for membership.

local core = exports['som-core']

local groups = {}
local byCitizen = {}
local invites = {}
local nextGroup, nextMember = 1, 1

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function normalise(number)
    if type(number) ~= 'string' or #number > 16 then return nil end

    local d = number:gsub('%D', '')
    if #d ~= 7 then return nil end

    return ('%s-%s'):format(d:sub(1, 3), d:sub(4))
end

local function nameOf(player)
    return ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
end

local function groupOf(player)
    return groups[byCitizen[player.citizenid]]
end

local function memberCount(group)
    local n = 0
    for _ in pairs(group.members) do n = n + 1 end
    return n
end

local function changed(group)
    TriggerEvent('som-groups:server:changed', group.id)
    for cid in pairs(group.members) do
        local member = core:getPlayerByCitizenId(cid)
        if member then TriggerClientEvent('som-phone:client:refresh', member.source) end
    end
end

local function tell(player, text)
    exports['som-phone']:notifyApp(player.source, 'groups', text)
end

local function remove(group, citizenid)
    group.members[citizenid] = nil
    byCitizen[citizenid] = nil

    if memberCount(group) == 0 then
        groups[group.id] = nil
        return
    end

    if group.leader == citizenid then
        local first
        for cid, m in pairs(group.members) do
            if not first or m.id < group.members[first].id then first = cid end
        end
        group.leader = first
        local leader = core:getPlayerByCitizenId(first)
        if leader then tell(leader, 'You are now the group leader') end
    end

    changed(group)
end

local function live(invite)
    return invite and invite.expires > os.time() and groups[invite.group] ~= nil
end

local function view(player)
    local group = groupOf(player)
    local sections, buttons = {}, {}

    local invite = invites[player.citizenid]
    if not group and live(invite) then
        sections[#sections + 1] = { title = 'Invitation', rows = {
            { title = ('%s invited you'):format(invite.from), sub = 'Accept to join their group', action = 'accept' },
        } }
        buttons[#buttons + 1] = { label = 'Decline', action = 'decline', danger = true }
    end

    if not group then
        buttons[#buttons + 1] = { label = 'Create a group', action = 'create' }
        return { sections = sections, buttons = buttons, empty = 'You are not in a group' }
    end

    local rows = {}
    for cid, m in pairs(group.members) do
        local row = { title = m.name .. (cid == group.leader and ' (leader)' or ''), sub = m.ready and 'Ready' or 'Not ready', order = m.id }
        if group.leader == player.citizenid and cid ~= player.citizenid then
            row.action, row.payload = 'kick', { member = m.id }
        end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b) return a.order < b.order end)
    for _, row in ipairs(rows) do row.order = nil end

    sections[#sections + 1] = { title = group.busy and ('Group: ' .. group.busy) or 'Your group', rows = rows }

    local me = group.members[player.citizenid]
    buttons[#buttons + 1] = { label = me.ready and 'Not ready' or 'Ready up', action = 'ready', payload = { ready = not me.ready } }
    if group.leader == player.citizenid then
        buttons[#buttons + 1] = { label = 'Invite by number', action = 'invite', prompt = { field = 'number', label = 'Phone number', maxLength = 8 } }
    end
    buttons[#buttons + 1] = { label = 'Leave group', action = 'leave', danger = true }

    return { sections = sections, buttons = buttons }
end

local actions = {}

function actions.view(_, _, player)
    return done(true, nil, { view = view(player) })
end

function actions.create(_, _, player)
    if groupOf(player) then return done(false, 'you are already in a group') end

    local id = nextGroup
    nextGroup = nextGroup + 1
    groups[id] = { id = id, leader = player.citizenid, members = {}, busy = nil }
    groups[id].members[player.citizenid] = { id = nextMember, name = nameOf(player), ready = false }
    nextMember = nextMember + 1
    byCitizen[player.citizenid] = id
    invites[player.citizenid] = nil

    changed(groups[id])
    return done(true)
end

function actions.invite(_, payload, player)
    local group = groupOf(player)
    if not group or group.leader ~= player.citizenid then return done(false, 'only the leader can invite') end
    if group.busy then return done(false, 'your group is on a job') end

    local number = normalise(payload.number)
    if not number then return done(false, 'a seven digit number is needed') end
    if memberCount(group) >= Config.maxSize then return done(false, 'the group is full') end

    local row = MySQL.single.await('SELECT citizenid FROM som_characters WHERE phone = ? AND slot IS NOT NULL', { number })
    local target = row and core:getPlayerByCitizenId(row.citizenid)
    if not target then return done(false, 'that person is not around') end
    if target.citizenid == player.citizenid then return done(false, 'that is you') end
    if byCitizen[target.citizenid] then return done(false, 'they are already in a group') end

    invites[target.citizenid] = { group = group.id, from = nameOf(player), expires = os.time() + Config.inviteSeconds }
    tell(target, ('%s invited you to a group'):format(nameOf(player)))
    TriggerClientEvent('som-phone:client:refresh', target.source)
    return done(true)
end

function actions.accept(_, _, player)
    if groupOf(player) then return done(false, 'you are already in a group') end

    local invite = invites[player.citizenid]
    if not live(invite) then
        invites[player.citizenid] = nil
        return done(false, 'that invitation is gone')
    end

    local group = groups[invite.group]
    if group.busy then return done(false, 'that group is on a job') end
    if memberCount(group) >= Config.maxSize then return done(false, 'that group is full') end

    invites[player.citizenid] = nil
    group.members[player.citizenid] = { id = nextMember, name = nameOf(player), ready = false }
    nextMember = nextMember + 1
    byCitizen[player.citizenid] = group.id

    changed(group)
    return done(true)
end

function actions.decline(_, _, player)
    invites[player.citizenid] = nil
    return done(true)
end

function actions.leave(_, _, player)
    local group = groupOf(player)
    if not group then return done(false, 'you are not in a group') end

    remove(group, player.citizenid)
    return done(true)
end

function actions.kick(_, payload, player)
    local group = groupOf(player)
    if not group or group.leader ~= player.citizenid then return done(false, 'only the leader can remove people') end

    local id = math.floor(tonumber(payload.member) or 0)
    for cid, m in pairs(group.members) do
        if m.id == id and cid ~= player.citizenid then
            local gone = core:getPlayerByCitizenId(cid)
            remove(group, cid)
            if gone then
                tell(gone, 'You were removed from the group')
                TriggerClientEvent('som-phone:client:refresh', gone.source)
            end
            return done(true)
        end
    end

    return done(false, 'they are not in the group')
end

function actions.ready(_, payload, player)
    local group = groupOf(player)
    if not group then return done(false, 'you are not in a group') end
    if group.busy then return done(false, 'your group is on a job') end
    if type(payload.ready) ~= 'boolean' then return done(false, 'bad request') end

    group.members[player.citizenid].ready = payload.ready
    changed(group)
    return done(true)
end

local app = {
    id = 'groups', label = 'Groups', icon = 'contacts', colour = '#64d2ff', order = 60,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end

        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
}

exports['som-phone']:registerApp(app)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end

    invites[citizenid] = nil

    local group = groups[byCitizen[citizenid]]
    if group then remove(group, citizenid) end
end)

-- ---------------------------------------------------------------------------
-- For job resources
-- ---------------------------------------------------------------------------

---@param source number
---@return table|nil { id, leader, allReady, busy, members = { { source, citizenid, name, ready } } }
local function describe(source)
    local player = core:getPlayer(source)
    local group = player and groupOf(player)
    if not group then return nil end

    local out = { id = group.id, busy = group.busy, allReady = true, members = {} }
    for cid, m in pairs(group.members) do
        local member = core:getPlayerByCitizenId(cid)
        out.members[#out.members + 1] = { source = member and member.source, citizenid = cid, name = m.name, ready = m.ready }
        if cid == group.leader then out.leader = member and member.source end
        if not m.ready then out.allReady = false end
    end

    return out
end

exports('getGroup', describe)

---Marks a group as on a job (nil clears it). Blocks invites and ready changes
---while set. Returns false if the group is gone.
---@param groupId number
---@param label string|nil
---@return boolean
exports('setBusy', function(groupId, label)
    local group = groups[groupId]
    if not group then return false end

    group.busy = type(label) == 'string' and label:sub(1, 32) or nil
    if group.busy == nil then
        for _, m in pairs(group.members) do m.ready = false end
    end

    changed(group)
    return true
end)
