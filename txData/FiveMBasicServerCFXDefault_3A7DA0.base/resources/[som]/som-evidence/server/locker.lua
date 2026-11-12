--- The station: locking evidence up, checking it out, the lab, and the link to
--- a court case. Stored evidence is a database state, not a stash the client
--- could name, and every change leaves a custody row.

local ox = exports.ox_inventory

local function fail(err) return { success = false, error = err } end

---An on duty officer standing at one of the two points of a configured station.
---@param source number
---@param stationKey any
---@param point string 'locker' or 'lab'
---@return table|nil officer, string|nil error
local function atStation(source, stationKey, point)
    local officer, err = Evidence.Officer(source)
    if not officer then return nil, err end

    local station = type(stationKey) == 'string' and Config.Stations[stationKey]
    if not station then return nil, 'no such station' end

    local at = Evidence.Position(source)
    if not at or #(at - station[point]) > station.range then return nil, 'too far away' end

    return officer
end

local function idOf(value)
    local id = math.floor(tonumber(value) or 0)
    return id > 0 and id or nil
end

lib.callback.register('som-evidence:server:locker', function(source, stationKey, point)
    local officer, err = atStation(source, stationKey, point == 'lab' and 'lab' or 'locker')
    if not officer then return fail(err) end

    return {
        success = true,
        held = MySQL.query.await(
            "SELECT id, kind, case_id FROM som_evidence WHERE holder_cid = ? AND status = 'collected' LIMIT 25",
            { officer.citizenid }) or {},
        stored = MySQL.query.await(
            "SELECT id, kind, case_id, analysed_at FROM som_evidence WHERE station = ? AND status = 'stored' ORDER BY id DESC LIMIT 25",
            { stationKey }) or {},
    }
end)

lib.callback.register('som-evidence:server:store', function(source, stationKey, id)
    local officer, err = atStation(source, stationKey, 'locker')
    if not officer then return fail(err) end

    id = idOf(id)
    if not id then return fail('no such evidence') end

    local slot = Evidence.BagSlot(source, id)
    if not slot then return fail('you are not carrying that bag') end

    local won = MySQL.update.await([[
        UPDATE som_evidence SET status = 'stored', station = ?, holder_cid = NULL
        WHERE id = ? AND status = 'collected' AND holder_cid = ?
    ]], { stationKey, id, officer.citizenid })
    if won ~= 1 then return fail('that evidence is not yours to lock up') end

    if not ox:RemoveItem(source, Config.Items.filledBag, 1, nil, slot) then
        MySQL.update.await(
            "UPDATE som_evidence SET status = 'collected', holder_cid = ?, station = NULL WHERE id = ? AND status = 'stored' AND station = ?",
            { officer.citizenid, id, stationKey })
        return fail('the bag is no longer in your pack')
    end
    Evidence.Custody(id, officer.citizenid, 'stored', stationKey)
    return { success = true }
end)

lib.callback.register('som-evidence:server:checkout', function(source, stationKey, id)
    local officer, err = atStation(source, stationKey, 'locker')
    if not officer then return fail(err) end

    id = idOf(id)
    if not id then return fail('no such evidence') end

    local won = MySQL.update.await([[
        UPDATE som_evidence SET status = 'collected', holder_cid = ?, station = NULL
        WHERE id = ? AND status = 'stored' AND station = ?
    ]], { officer.citizenid, id, stationKey })
    if won ~= 1 then return fail('that evidence is not in this locker') end

    if not ox:AddItem(source, Config.Items.filledBag, 1, { evidence_id = id }) then
        MySQL.update.await(
            "UPDATE som_evidence SET status = 'stored', holder_cid = NULL, station = ? WHERE id = ? AND status = 'collected'",
            { stationKey, id })
        return fail('you cannot carry that')
    end

    Evidence.Custody(id, officer.citizenid, 'checked out', stationKey)
    return { success = true }
end)

--- Starts the clock. The result time is the database's, and the result is only
--- readable once it is due.
lib.callback.register('som-evidence:server:analyse', function(source, stationKey, id)
    local officer, err = atStation(source, stationKey, 'lab')
    if not officer then return fail(err) end

    id = idOf(id)
    local row = id and MySQL.single.await('SELECT * FROM som_evidence WHERE id = ?', { id })
    if not row then return fail('no such evidence') end

    local def = Config.Kinds[row.kind]
    if def.reference then return fail('a reference sample is not analysed') end

    local won = MySQL.update.await([[
        UPDATE som_evidence SET analysed_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE id = ? AND analysed_at IS NULL AND status IN ('collected', 'stored')
          AND (holder_cid = ? OR station = ?)
    ]], { def.lab, id, officer.citizenid, stationKey })
    if won ~= 1 then return fail('it is not here to be analysed, or already is') end

    Evidence.Custody(id, officer.citizenid, 'analysis started', stationKey)
    return { success = true, minutes = def.lab }
end)

lib.callback.register('som-evidence:server:result', function(source, stationKey, id)
    local officer, err = atStation(source, stationKey, 'lab')
    if not officer then return fail(err) end

    id = idOf(id)
    local row = id and MySQL.single.await('SELECT * FROM som_evidence WHERE id = ?', { id })
    if not row or not row.analysed_at then return fail('nothing has been analysed') end

    local due = MySQL.scalar.await('SELECT 1 FROM som_evidence WHERE id = ? AND analysed_at <= NOW()', { id })
    if not due then return fail('the analysis is not finished') end

    local result = { kind = Config.Kinds[row.kind].label, serial = row.weapon_serial }

    -- A match needs an on-file reference sample of the matching type with the same code.
    for kind, def in pairs(Config.Kinds) do
        if def.reference and def.matches == row.kind and row.profile then
            local match = MySQL.scalar.await(
                "SELECT source_cid FROM som_evidence WHERE kind = ? AND profile = ? AND status <> 'destroyed' LIMIT 1",
                { kind, row.profile })
            if match then result.match = match end
        end
    end

    if row.profile and not result.match and not Config.Kinds[row.kind].reference then
        result.profile = row.profile
    end

    return { success = true, result = result }
end)

--- Attaches evidence to a court case the officer filed. Both ends are read
--- from the database, so there is nothing for the client to forge.
lib.callback.register('som-evidence:server:link', function(source, stationKey, id, caseId)
    local officer, err = atStation(source, stationKey, 'locker')
    if not officer then return fail(err) end

    id, caseId = idOf(id), idOf(caseId)
    if not id or not caseId then return fail('no such evidence or case') end

    local case = exports['som-court']:caseSummary(caseId)
    if not case or case.filed_by ~= officer.citizenid then return fail('that is not your case') end
    if case.status ~= 'filed' and case.status ~= 'accepted' and case.status ~= 'scheduled' then
        return fail('that case is closed')
    end

    local won = MySQL.update.await([[
        UPDATE som_evidence SET case_id = ?
        WHERE id = ? AND case_id IS NULL AND status IN ('collected', 'stored') AND (holder_cid = ? OR station = ?)
    ]], { caseId, id, officer.citizenid, stationKey })
    if won ~= 1 then return fail('that evidence cannot be linked') end

    Evidence.Custody(id, officer.citizenid, 'linked', ('case #%d'):format(caseId))
    return { success = true }
end)

---Read by som-court so a judge sees what backs a case.
---@param caseId any
---@return table[]
exports('forCase', function(caseId)
    caseId = idOf(caseId)
    if not caseId then return {} end

    local rows = MySQL.query.await(
        "SELECT id, kind, analysed_at FROM som_evidence WHERE case_id = ? AND status <> 'destroyed' ORDER BY id LIMIT 50",
        { caseId }) or {}

    for _, row in ipairs(rows) do row.label = Config.Kinds[row.kind].label end
    return rows
end)
