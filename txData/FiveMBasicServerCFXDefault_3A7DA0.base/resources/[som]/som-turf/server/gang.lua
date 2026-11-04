--- Gang management as a phone app. Only a boss grade may invite, rank or
--- remove people, and a boss never touches a rank at or above their own. Rank
--- changes go through som-core's setGang and are written to the database too,
--- so an offline member can be removed and a crash loses nothing. The gang
--- account is funded by boss deposits from their own bank balance.

local core = exports['som-core']
local Gangs = core:getGangs()

local invites = {}
local rosters = {}

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

local function log(gang, actor, target, action, detail)
    MySQL.insert.await('INSERT INTO som_gang_log (gang, actor, target, action, detail) VALUES (?, ?, ?, ?, ?)',
        { gang, actor, target, action, detail and tostring(detail):sub(1, 120) or nil })
end

local function gradeLabel(gang, grade)
    local g = Gangs[gang]
    return g and g.grades[grade] and g.grades[grade].name or tostring(grade)
end

local function refresh(player)
    if player then TriggerClientEvent('som-phone:client:refresh', player.source) end
end

---Applies a gang and grade to a character, online or not. The UPDATE is
---conditional on the gang they are expected to be in, so a stale request
---cannot move someone who has changed gang meanwhile.
local function assign(citizenid, fromGang, gang, grade)
    local n = MySQL.update.await(
        'UPDATE som_characters SET gang = ?, gang_grade = ? WHERE citizenid = ? AND gang = ?',
        { gang, grade, citizenid, fromGang })
    if (n or 0) < 1 then return false end

    local online = core:getPlayerByCitizenId(citizenid)
    if online then
        core:setGang(online.source, gang, grade)
        refresh(online)
    end
    return true
end

local function roster(gang)
    return MySQL.query.await([[
        SELECT citizenid, firstname, lastname, gang_grade FROM som_characters
        WHERE gang = ? AND slot IS NOT NULL AND deleted = 0
        ORDER BY gang_grade DESC, citizenid LIMIT ?
    ]], { gang, Config.gang.maxMembers }) or {}
end

local function view(player)
    local gang = player.gang
    local sections, buttons = {}, {}

    local invite = invites[player.citizenid]
    if gang.name == 'none' then
        if invite and invite.expires > os.time() then
            sections[1] = { title = 'Invitation', rows = { { title = ('%s invited you to %s'):format(invite.from, Gangs[invite.gang].label), sub = 'Accept to join', action = 'accept' } } }
            buttons[1] = { label = 'Decline', action = 'decline', danger = true }
        end
        return { sections = sections, buttons = buttons, empty = 'You are not in a gang' }
    end

    local list = roster(gang.name)
    rosters[player.citizenid] = {}
    local rows = {}
    for i, m in ipairs(list) do
        rosters[player.citizenid][i] = { citizenid = m.citizenid, grade = m.gang_grade }
        rows[#rows + 1] = { title = ('%d. %s %s'):format(i, m.firstname, m.lastname), sub = gradeLabel(gang.name, m.gang_grade) }
    end
    sections[1] = { title = ('%s, $%d in the account'):format(gang.label, core:getGangBalance(gang.name)), rows = rows }

    if gang.isboss then
        buttons[#buttons + 1] = { label = 'Invite by number', action = 'invite', prompt = { field = 'number', label = 'Phone number', maxLength = 8 } }
        buttons[#buttons + 1] = { label = 'Promote member', action = 'rank', payload = { step = 1 }, prompt = { field = 'member', label = 'Member number', maxLength = 3 } }
        buttons[#buttons + 1] = { label = 'Demote member', action = 'rank', payload = { step = -1 }, prompt = { field = 'member', label = 'Member number', maxLength = 3 } }
        buttons[#buttons + 1] = { label = 'Remove member', action = 'kick', danger = true, prompt = { field = 'member', label = 'Member number', maxLength = 3 } }
        buttons[#buttons + 1] = { label = 'Deposit to account', action = 'deposit', prompt = { field = 'amount', label = 'Amount', maxLength = 7 } }
    end
    buttons[#buttons + 1] = { label = 'Leave the gang', action = 'leave', danger = true }
    return { sections = sections, buttons = buttons }
end

local actions = {}

function actions.view(_, _, player) return done(true, nil, { view = view(player) }) end

local function boss(player)
    return player.gang.name ~= 'none' and player.gang.isboss
end

---The roster entry a boss pointed at, only if it is below their own rank.
local function target(player, payload)
    local n = math.floor(tonumber(payload.member) or 0)
    local entry = rosters[player.citizenid] and rosters[player.citizenid][n]
    if not entry then return nil, 'open the app again, then pick a member' end
    if entry.citizenid == player.citizenid then return nil, 'that is you' end

    local grade = MySQL.scalar.await('SELECT gang_grade FROM som_characters WHERE citizenid = ? AND gang = ?',
        { entry.citizenid, player.gang.name })
    if not grade then return nil, 'they are not in the gang any more' end
    if grade >= player.gang.grade then return nil, 'they outrank you or match your rank' end
    return { citizenid = entry.citizenid, grade = grade }
end

function actions.invite(_, payload, player)
    if not boss(player) then return done(false, 'only a boss can invite') end
    local number = normalise(payload.number)
    if not number then return done(false, 'that is not a phone number') end

    local row = MySQL.single.await('SELECT citizenid FROM som_characters WHERE phone = ? AND slot IS NOT NULL', { number })
    local other = row and core:getPlayerByCitizenId(row.citizenid)
    if not other then return done(false, 'that person is not around') end
    if other.citizenid == player.citizenid then return done(false, 'that is you') end
    if other.gang.name ~= 'none' then return done(false, 'they are already in a gang') end

    local ped, tped = GetPlayerPed(player.source), GetPlayerPed(other.source)
    if ped == 0 or tped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(tped)) > Config.gang.inviteDistance then
        return done(false, 'they need to be next to you')
    end
    if #roster(player.gang.name) >= Config.gang.maxMembers then return done(false, 'the gang is full') end

    invites[other.citizenid] = { gang = player.gang.name, from = nameOf(player), expires = os.time() + Config.gang.inviteSeconds }
    exports['som-phone']:notifyApp(other.source, 'gang', ('%s invited you to %s'):format(nameOf(player), player.gang.label))
    refresh(other)
    return done(true)
end

function actions.accept(_, _, player)
    local invite = invites[player.citizenid]
    invites[player.citizenid] = nil
    if player.gang.name ~= 'none' then return done(false, 'you are already in a gang') end
    if not invite or invite.expires <= os.time() then return done(false, 'that invitation is gone') end
    if #roster(invite.gang) >= Config.gang.maxMembers then return done(false, 'that gang is full') end

    if not assign(player.citizenid, 'none', invite.gang, 0) then return done(false, 'could not join') end
    log(invite.gang, player.citizenid, player.citizenid, 'join')
    return done(true)
end

function actions.decline(_, _, player)
    invites[player.citizenid] = nil
    return done(true)
end

function actions.leave(_, _, player)
    local gang = player.gang.name
    if gang == 'none' then return done(false, 'you are not in a gang') end
    if player.gang.isboss then
        local bosses = 0
        for _, m in ipairs(roster(gang)) do
            if Gangs[gang].grades[m.gang_grade] and Gangs[gang].grades[m.gang_grade].isboss then bosses = bosses + 1 end
        end
        if bosses <= 1 then return done(false, 'promote someone to boss before you leave') end
    end

    if not assign(player.citizenid, gang, 'none', 0) then return done(false, 'could not leave') end
    log(gang, player.citizenid, player.citizenid, 'leave')
    return done(true)
end

function actions.kick(_, payload, player)
    if not boss(player) then return done(false, 'only a boss can remove people') end
    local entry, err = target(player, payload)
    if not entry then return done(false, err) end

    if not assign(entry.citizenid, player.gang.name, 'none', 0) then return done(false, 'they are not in the gang any more') end
    log(player.gang.name, player.citizenid, entry.citizenid, 'kick')
    return done(true)
end

function actions.rank(_, payload, player)
    if not boss(player) then return done(false, 'only a boss can change ranks') end
    local step = payload.step
    if step ~= 1 and step ~= -1 then return done(false, 'bad request') end

    local entry, err = target(player, payload)
    if not entry then return done(false, err) end

    local new = entry.grade + step
    local def = Gangs[player.gang.name].grades[new]
    if not def or new < 0 then return done(false, 'there is no rank that way') end
    if new > player.gang.grade then return done(false, 'you cannot promote above your own rank') end

    if not assign(entry.citizenid, player.gang.name, player.gang.name, new) then return done(false, 'they are not in the gang any more') end
    log(player.gang.name, player.citizenid, entry.citizenid, 'rank', def.name)
    return done(true)
end

function actions.deposit(_, payload, player)
    if not boss(player) then return done(false, 'only a boss can pay in') end
    local amount = tonumber(payload.amount)
    if not amount or amount % 1 ~= 0 or amount < 1 or amount > Config.gang.depositMax then
        return done(false, ('between 1 and %d'):format(Config.gang.depositMax))
    end

    if not core:removeMoney(player.source, 'bank', amount, 'gang:deposit') then return done(false, 'not enough in your bank') end
    local ok = core:gangTransact(player.gang.name, amount, 'gang:deposit')
    if not ok then
        core:addMoney(player.source, 'bank', amount, 'gang:deposit_refund')
        return done(false, 'the account could not take it')
    end

    log(player.gang.name, player.citizenid, nil, 'deposit', amount)
    return done(true)
end

local app = {
    id = 'gang', label = 'Gang', icon = 'contacts', colour = '#ff9f0a', order = 65,
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
    rosters[citizenid] = nil
end)
