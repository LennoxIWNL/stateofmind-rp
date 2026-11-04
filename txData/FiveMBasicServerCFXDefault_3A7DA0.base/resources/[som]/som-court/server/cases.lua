--- Cases: filing, the docket, and the pre-trial steps. Every status change is a
--- conditional UPDATE whose affected-row count decides who won.

local core = exports['som-core']

Court = {}

---@param source number
---@param role string key of Config.Jobs
---@return table|nil player, string|nil error
function Court.Actor(source, role)
    local player = core:getPlayer(source)
    if not player then return nil, 'not loaded' end
    if player.job.name ~= Config.Jobs[role] then return nil, 'not permitted' end
    if not player.job.onduty then return nil, 'you are off duty' end
    return player
end

---@param player table
---@param grade number
---@return boolean
function Court.HasGrade(player, grade)
    return (player.job.grade or 0) >= grade
end

---@param text string
function Court.Log(text)
    local url = GetConvar('som_court_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }),
        { ['Content-Type'] = 'application/json' })
end

---@param caseId number
---@param actor string citizenid
---@param action string
---@param detail string|nil
function Court.Event(caseId, actor, action, detail)
    MySQL.insert.await(
        'INSERT INTO som_court_events (case_id, actor_cid, action, detail) VALUES (?, ?, ?, ?)',
        { caseId, actor, action, detail })
    Court.Log(('case #%d %s by %s%s'):format(caseId, action, actor, detail and (': ' .. detail) or ''))
end

---@param id any
---@return table|nil
function Court.Get(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM som_court_cases WHERE id = ?', { id })
end

---@return boolean
local function inRange(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= Config.FileRange
end

local function fail(err) return { success = false, error = err } end

lib.callback.register('som-court:server:file', function(source, data)
    if type(data) ~= 'table' then return fail('bad request') end

    local officer, err = Court.Actor(source, 'police')
    if not officer then return fail(err) end

    local targetSource = tonumber(data.target)
    local target = targetSource and core:getPlayer(targetSource)
    if not target then return fail('they are not here') end
    if target.citizenid == officer.citizenid then return fail('you cannot file against yourself') end
    if not inRange(source, targetSource) then return fail('too far away') end

    if type(data.class) ~= 'string' or not Config.Classes[data.class] then return fail('unknown charge class') end

    local charges = type(data.charges) == 'string' and data.charges:sub(1, 500) or ''
    if #charges < 3 then return fail('charges are required') end

    local incident = math.floor(tonumber(data.incidentId) or 0)

    local open = MySQL.scalar.await(
        "SELECT COUNT(*) FROM som_court_cases WHERE defendant_cid = ? AND status IN ('filed','accepted','scheduled')",
        { target.citizenid })
    if (tonumber(open) or 0) >= Config.MaxOpenPerDefendant then
        return fail('they already have the maximum open cases')
    end

    local id = MySQL.insert.await([[
        INSERT INTO som_court_cases (defendant_cid, filed_by, incident_id, charges, class)
        VALUES (?, ?, ?, ?, ?)
    ]], { target.citizenid, officer.citizenid, incident > 0 and incident or nil, charges, data.class })

    Court.Event(id, officer.citizenid, 'filed', data.class)

    return { success = true, id = id }
end)

--- The caller's role decides the view; the client never names one.
lib.callback.register('som-court:server:docket', function(source)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local limit, cid, job = Config.DocketSize, player.citizenid, player.job.name
    local rows

    if job == Config.Jobs.judge then
        rows = MySQL.query.await(
            "SELECT * FROM som_court_cases WHERE status IN ('accepted','scheduled','convicted') ORDER BY id DESC LIMIT ?",
            { limit })
    elseif job == Config.Jobs.prosecutor then
        rows = MySQL.query.await(
            "SELECT * FROM som_court_cases WHERE status IN ('filed','accepted') ORDER BY id DESC LIMIT ?",
            { limit })
    elseif job == Config.Jobs.defender then
        rows = MySQL.query.await(
            "SELECT * FROM som_court_cases WHERE (defender_cid = ? OR defender_cid IS NULL) AND status IN ('filed','accepted','scheduled') ORDER BY id DESC LIMIT ?",
            { cid, limit })
    elseif job == Config.Jobs.police then
        rows = MySQL.query.await(
            'SELECT * FROM som_court_cases WHERE filed_by = ? ORDER BY id DESC LIMIT ?', { cid, limit })
    else
        return fail('not permitted')
    end

    return { success = true, role = job, cases = rows or {} }
end)

lib.callback.register('som-court:server:myCases', function(source)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    return { success = true, cases = MySQL.query.await(
        'SELECT * FROM som_court_cases WHERE defendant_cid = ? ORDER BY id DESC LIMIT ?',
        { player.citizenid, Config.DocketSize }) or {} }
end)

---Runs one claim and records it. `query` is a conditional UPDATE whose first
---parameter is the actor's citizenid and whose remaining parameters are `rest`.
local function claim(source, role, id, query, rest, action, detail)
    local actor, err = Court.Actor(source, role)
    if not actor then return fail(err) end

    if not tonumber(id) then return fail('no such case') end

    local params = { actor.citizenid }
    for _, value in ipairs(rest) do params[#params + 1] = value end

    if MySQL.update.await(query, params) ~= 1 then return fail('that case cannot be changed that way') end

    Court.Event(tonumber(id), actor.citizenid, action, detail)
    return { success = true }
end

lib.callback.register('som-court:server:accept', function(source, id)
    return claim(source, 'prosecutor', id,
        "UPDATE som_court_cases SET status = 'accepted', prosecutor_cid = ? WHERE id = ? AND status = 'filed'",
        { tonumber(id) }, 'accepted')
end)

lib.callback.register('som-court:server:drop', function(source, id)
    return claim(source, 'prosecutor', id,
        "UPDATE som_court_cases SET status = 'dismissed', prosecutor_cid = ? WHERE id = ? AND status IN ('filed','accepted')",
        { tonumber(id) }, 'dropped')
end)

lib.callback.register('som-court:server:defend', function(source, id)
    return claim(source, 'defender', id,
        "UPDATE som_court_cases SET defender_cid = ? WHERE id = ? AND defender_cid IS NULL AND status IN ('filed','accepted','scheduled')",
        { tonumber(id) }, 'defender')
end)

lib.callback.register('som-court:server:schedule', function(source, id, slot)
    local player = core:getPlayer(source)
    if player and not Court.HasGrade(player, Config.Grades.schedule) then return fail('not permitted') end

    local minutes = Config.HearingOffsets[tonumber(slot) or 0]
    if not minutes then return fail('choose a hearing time') end

    return claim(source, 'judge', id,
        "UPDATE som_court_cases SET status = 'scheduled', judge_cid = ?, hearing_at = DATE_ADD(NOW(), INTERVAL ? MINUTE) WHERE id = ? AND status = 'accepted'",
        { minutes, tonumber(id) }, 'scheduled', ('%d min'):format(minutes))
end)
