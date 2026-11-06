--- Process serving. The server picks the paper from the court's own table,
--- checks both people and the distance at the final step, claims the service
--- with one atomic insert, and only then moves the courts' money.

local core = exports['som-core']

local holds = {}
local holderOf = {}
local started = {}
local lastCall = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function limited(source)
    local now = GetGameTimer()
    if lastCall[source] and now - lastCall[source] < Config.callMs then return true end
    lastCall[source] = now
    return false
end

local EXCLUDING_PARTIES = [[
    SELECT c.id, c.defendant_cid, ch.firstname, ch.lastname, TIMESTAMPDIFF(MINUTE, NOW(), c.hearing_at) AS minutes
    FROM som_court_cases c
    JOIN som_characters ch ON ch.citizenid = c.defendant_cid
    WHERE c.status = 'scheduled' AND c.hearing_at > DATE_ADD(NOW(), INTERVAL ? MINUTE)
      AND NOT EXISTS (SELECT 1 FROM som_court_service s WHERE s.case_id = c.id)
      AND c.defendant_cid <> ? AND c.filed_by <> ?
      AND (c.prosecutor_cid IS NULL OR c.prosecutor_cid <> ?)
      AND (c.judge_cid IS NULL OR c.judge_cid <> ?)
      AND (c.defender_cid IS NULL OR c.defender_cid <> ?)
]]

local function release(citizenid)
    local hold = holds[citizenid]
    if hold then holderOf[hold.case] = nil end
    holds[citizenid] = nil
end

local function liveHold(citizenid)
    local hold = holds[citizenid]
    if hold and hold.untilAt <= os.time() then
        release(citizenid)
        return nil
    end
    return hold
end

local function funded()
    return exports['som-economy']:getBusinessBalance(Config.business) >= Config.fee
end

local function nameOf(row)
    return ('%s %s'):format(row.firstname, row.lastname)
end

local function eligible(cid, caseId)
    return MySQL.single.await(EXCLUDING_PARTIES .. ' AND c.id = ?',
        { Config.hearingMinutes, cid, cid, cid, cid, cid, caseId })
end

local function hourSpent(cid)
    return MySQL.scalar.await(
        'SELECT COALESCE(SUM(fee), 0) FROM som_court_service WHERE server_cid = ? AND served_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)',
        { cid }) or 0
end

local function recentlyServed(defendant)
    return (MySQL.scalar.await(
        'SELECT COUNT(*) FROM som_court_service WHERE defendant_cid = ? AND served_at > DATE_SUB(NOW(), INTERVAL ? HOUR)',
        { defendant, Config.defendantHours }) or 0) > 0
end

local function view(player)
    local hold = liveHold(player.citizenid)
    if hold then
        return {
            sections = { { title = 'Your paper', rows = { {
                title = ('Serve %s'):format(hold.name),
                sub = ('Find them in person. Hearing in about %s, $%d on service'):format(hold.when, Config.fee),
            } } } },
            buttons = { { label = 'Hand it back', action = 'drop', danger = true } },
        }
    end

    if not funded() then return { empty = 'The courts cannot pay for service right now' } end

    local cid = player.citizenid
    local rows = {}
    for _, row in ipairs(MySQL.query.await(EXCLUDING_PARTIES .. ' ORDER BY c.hearing_at LIMIT ?',
        { Config.hearingMinutes, cid, cid, cid, cid, cid, Config.listSize }) or {}) do
        if not (holderOf[row.id] and liveHold(holderOf[row.id])) then
            rows[#rows + 1] = {
                title = nameOf(row),
                sub = ('Hearing in %dh %dm, $%d'):format(row.minutes // 60, row.minutes % 60, Config.fee),
                action = 'take', payload = { case = row.id },
            }
        end
    end

    return { sections = { { title = 'Papers to serve', rows = rows } }, empty = 'No papers need serving right now' }
end

local actions = {}

function actions.view(_, _, player)
    return done(true, nil, { view = view(player) })
end

function actions.take(source, payload, player)
    local caseId = math.floor(tonumber(payload.case) or 0)
    if caseId < 1 then return done(false, 'bad request') end
    if not funded() then return done(false, 'the courts cannot pay for service right now') end
    if liveHold(player.citizenid) then return done(false, 'you are already holding a paper') end
    if holderOf[caseId] and liveHold(holderOf[caseId]) then return done(false, 'someone else has that paper') end

    -- Reserved before the next query yields, so two takes cannot both pass the checks above.
    local hold = { case = caseId, untilAt = os.time() + Config.holdMinutes * 60 }
    holds[player.citizenid] = hold
    holderOf[caseId] = player.citizenid

    local row = eligible(player.citizenid, caseId)
    local refusal = (not row and 'that paper is gone')
        or (recentlyServed(row.defendant_cid) and 'they were served recently')
        or (hourSpent(player.citizenid) + Config.fee > Config.hourlyCap and 'you have served enough for this hour')
    if refusal then
        release(player.citizenid)
        return done(false, refusal)
    end

    hold.defendant, hold.name = row.defendant_cid, nameOf(row)
    hold.when = ('%dh %dm'):format(row.minutes // 60, row.minutes % 60)
    TriggerClientEvent('som-serving:client:hold', source, true)
    return done(true, nil, { view = view(player) })
end

function actions.drop(source, _, player)
    release(player.citizenid)
    TriggerClientEvent('som-serving:client:hold', source, false)
    return done(true, nil, { view = view(player) })
end

exports['som-phone']:registerApp({
    id = 'papers', label = 'Papers', icon = 'note', colour = '#bf5af2', order = 62,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end

        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

local function inReach(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.distance
end

---The defendant named on the held paper, if loaded and standing close enough.
local function defendantAt(source, player, target)
    local hold = liveHold(player.citizenid)
    if not hold then return nil, 'you are not holding a paper' end

    target = math.floor(tonumber(target) or 0)
    local defendant = target > 0 and target ~= source and core:getPlayer(target)
    if not defendant or defendant.citizenid ~= hold.defendant then return nil, 'that is not the person on the paper' end
    if not inReach(source, target) then return nil, 'you are too far away' end

    return hold, nil, target
end

lib.callback.register('som-serving:server:begin', function(source, target)
    if limited(source) then return done(false, 'slow down') end

    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local hold, err, id = defendantAt(source, player, target)
    if not hold then return done(false, err) end

    started[source] = { target = id, case = hold.case, at = GetGameTimer() }
    return done(true)
end)

lib.callback.register('som-serving:server:finish', function(source, target)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local run = started[source]
    started[source] = nil
    local age = run and GetGameTimer() - run.at
    if not run or run.target ~= tonumber(target) or age < Config.seconds * 900 or age > Config.staleSeconds * 1000 then
        return done(false, 'the papers were not handed over')
    end

    local hold, err, id = defendantAt(source, player, target)
    if not hold or hold.case ~= run.case then return done(false, err or 'the papers were not handed over') end

    local cid = player.citizenid
    if not eligible(cid, hold.case) then
        release(cid)
        TriggerClientEvent('som-serving:client:hold', source, false)
        return done(false, 'that paper is gone')
    end

    local rowId = MySQL.insert.await([[
        INSERT IGNORE INTO som_court_service (case_id, defendant_cid, server_cid, fee)
        SELECT ?, ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_court_service WHERE defendant_cid = ? AND served_at > DATE_SUB(NOW(), INTERVAL ? HOUR))
          AND (SELECT COALESCE(SUM(fee), 0) FROM som_court_service WHERE server_cid = ? AND served_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)) + ? <= ?
    ]], { hold.case, hold.defendant, cid, Config.fee, hold.defendant, Config.defendantHours, cid, Config.fee, Config.hourlyCap })
    if not rowId or rowId < 1 then return done(false, 'these papers cannot be paid for now') end

    local ok, paid = pcall(function()
        if not exports['som-economy']:businessSpend(Config.business, Config.fee, 'court-service') then return false end
        if core:addMoney(source, 'bank', Config.fee, 'court-service') then return true end

        core:businessTransact(Config.business, Config.fee, 'court-service:refund')
        return false
    end)

    if not ok or not paid then
        if not ok then print(('[som-serving] payout failed: %s'):format(tostring(paid))) end
        MySQL.update.await('DELETE FROM som_court_service WHERE id = ?', { rowId })
        return done(false, 'the courts could not pay for this service')
    end

    release(cid)
    TriggerClientEvent('som-serving:client:hold', source, false)
    TriggerClientEvent('som:client:notify', source, ('Served: $%d'):format(Config.fee), 'success')
    TriggerClientEvent('som:client:notify', id, ('You were served court papers for hearing #%d'):format(hold.case), 'inform')
    TriggerClientEvent('som-phone:client:refresh', source)
    return done(true)
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then release(citizenid) end
end)

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
    started[source] = nil
end)
