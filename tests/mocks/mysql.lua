-- A tiny in-memory fake of oxmysql's await-style API, matched against the
-- exact query strings the resources under test actually issue. Not a
-- general SQL engine: the production code and this mock are both ours, so
-- pattern-matching a known, small set of literal queries is enough, and an
-- unrecognized query fails loudly instead of returning the wrong shape.

local M = {}

M.db = {
    properties = {},
    owners = {},
    finance = {},
    jailSentences = {},
    jailBail = {},
    courtCases = {},
    courtEvents = {},
    courtWarrants = {},
    service = {},
    evidence = {},
    custody = {},
    profiles = {},
    bills = {},
    orders = {},
    nextId = { properties = 1, owners = 1, finance = 1, jailSentences = 1, jailBail = 1,
               courtCases = 1, courtEvents = 1, courtWarrants = 1, service = 1, evidence = 1, custody = 1, orders = 1 },
}

-- Overridable "now" for jail/bail elapsed-time math, so a test can jump a
-- sentence forward without a real wait. nil means use the real clock.
M.fakeNow = nil

local function now()
    return M.fakeNow or os.time()
end

local function findProperty(id)
    for _, p in ipairs(M.db.properties) do
        if p.id == id then return p end
    end
    return nil
end

local function findSentence(id)
    for _, s in ipairs(M.db.jailSentences) do
        if s.id == id then return s end
    end
    return nil
end


local function findCase(id)
    for _, c in ipairs(M.db.courtCases) do
        if c.id == tonumber(id) then return c end
    end
    return nil
end

local function findEvidence(id)
    for _, r in ipairs(M.db.evidence) do
        if r.id == tonumber(id) then return r end
    end
    return nil
end

local function findOrder(id)
    for _, o in ipairs(M.db.orders) do
        if o.id == tonumber(id) then return o end
    end
    return nil
end

local function findService(id)
    for _, r in ipairs(M.db.service) do
        if r.id == id then return r end
    end
    return nil
end

local function activeService(cid)
    for _, r in ipairs(M.db.service) do
        if r.citizenid == cid and r.status == 'active' then return r end
    end
    return nil
end

local function liveWarrant(w)
    return w.status == 'active' and w.expires_at > now()
end

local function inList(value, ...)
    for _, v in ipairs({ ... }) do
        if value == v then return true end
    end
    return false
end

local function findOwner(propertyId, citizenid)
    for _, o in ipairs(M.db.owners) do
        if o.property_id == propertyId and o.citizenid == citizenid then return o end
    end
    return nil
end

local function copy(t)
    if not t then return nil end
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function fail(query)
    error('tests/mocks/mysql.lua: unhandled query: ' .. query, 3)
end

function M.single(query, params)
    params = params or {}
    if query:find('FROM som_properties WHERE slug = ?', 1, true) then
        for _, p in ipairs(M.db.properties) do
            if p.slug == params[1] then return copy(p) end
        end
        return nil
    end
    if query:find('FROM som_properties WHERE id = ?', 1, true) then
        return copy(findProperty(tonumber(params[1])))
    end
    if query:find("FROM som_property_finance WHERE property_id = ? AND status = 'active'", 1, true) then
        for _, f in ipairs(M.db.finance) do
            if f.property_id == params[1] and f.status == 'active' then return copy(f) end
        end
        return nil
    end
    if query:find('FROM som_property_finance WHERE id = ?', 1, true) then
        for _, f in ipairs(M.db.finance) do
            if f.id == params[1] then return copy(f) end
        end
        return nil
    end
    -- bail.lua's activeWithRemaining: one sentence, with elapsed.
    if query:find('FROM som_jail_sentences WHERE citizenid = ? AND status = ', 1, true) then
        for _, s in ipairs(M.db.jailSentences) do
            if s.citizenid == params[1] and s.status == 'serving' then
                local row = copy(s)
                row.elapsed = now() - s.booked_at
                return row
            end
        end
        return nil
    end
    if query:find('FROM som_court_cases WHERE id = ?', 1, true) then
        return copy(findCase(params[1]))
    end
    if query:find("FROM som_community_service WHERE citizenid = ? AND status = 'active'", 1, true) then
        return copy(activeService(params[1]))
    end
    if query:find('SELECT * FROM som_evidence WHERE id = ?', 1, true) then
        return copy(findEvidence(params[1]))
    end
    if query:find('SELECT worth, status FROM som_marked_bills WHERE uid = ?', 1, true) then
        return copy(M.db.bills[params[1]])
    end
    if query:find('SELECT * FROM som_launder_orders WHERE id = ?', 1, true) then
        return copy(findOrder(params[1]))
    end
    fail(query)
end

function M.scalar(query, params)
    params = params or {}
    if query:find('SELECT role FROM som_property_owners WHERE property_id = ? AND citizenid = ?', 1, true) then
        local o = findOwner(params[1], params[2])
        return o and o.role or nil
    end
    if query:find("SELECT citizenid FROM som_property_owners WHERE property_id = ? AND role = 'owner'", 1, true) then
        for _, o in ipairs(M.db.owners) do
            if o.property_id == params[1] and o.role == 'owner' then return o.citizenid end
        end
        return nil
    end
    if query:find("SELECT COUNT(*) FROM som_property_owners WHERE citizenid = ? AND role = 'owner'", 1, true) then
        local n = 0
        for _, o in ipairs(M.db.owners) do
            if o.citizenid == params[1] and o.role == 'owner' then n = n + 1 end
        end
        return n
    end
    if query:find('SELECT id FROM som_jail_bail WHERE sentence_id = ? AND status = ', 1, true) then
        for _, b in ipairs(M.db.jailBail) do
            if b.sentence_id == params[1] and b.status == 'posted' then return b.id end
        end
        return nil
    end
    if query:find("SELECT COUNT(*) FROM som_court_cases WHERE defendant_cid = ?", 1, true) then
        local n = 0
        for _, c in ipairs(M.db.courtCases) do
            if c.defendant_cid == params[1] and inList(c.status, 'filed', 'accepted', 'scheduled') then n = n + 1 end
        end
        return n
    end
    if query:find("SELECT id FROM som_court_warrants WHERE case_id = ?", 1, true) then
        for _, w in ipairs(M.db.courtWarrants) do
            if w.case_id == params[1] and liveWarrant(w) then return w.id end
        end
        return nil
    end
    if query:find('SELECT code FROM som_evidence_profiles WHERE citizenid = ?', 1, true) then
        return M.db.profiles[params[1]]
    end
    if query:find("kind = 'casing' AND status = 'scene' AND source_cid = ?", 1, true) then
        local n = 0
        for _, r in ipairs(M.db.evidence) do
            if r.kind == 'casing' and r.status == 'scene' and r.source_cid == params[1]
                and r.x >= params[2] and r.x <= params[3] and r.y >= params[4] and r.y <= params[5] then n = n + 1 end
        end
        return n
    end
    if query:find('SELECT 1 FROM som_evidence WHERE id = ? AND analysed_at <= NOW()', 1, true) then
        local r = findEvidence(params[1])
        return r and r.analysed_at and r.analysed_at <= now() and 1 or nil
    end
    if query:find('SELECT source_cid FROM som_evidence WHERE kind = ? AND profile = ?', 1, true) then
        for _, r in ipairs(M.db.evidence) do
            if r.kind == params[1] and r.profile == params[2] and r.status ~= 'destroyed' then return r.source_cid end
        end
        return nil
    end
    if query:find('FROM som_launder_orders WHERE citizenid = ?', 1, true) then
        local sum = 0
        for _, o in ipairs(M.db.orders) do
            if o.citizenid == params[1] and o.status ~= 'cancelled' and o.created_at > now() - 86400 then sum = sum + o.face end
        end
        return sum
    end
    if query:find('FROM som_launder_orders WHERE status <> ', 1, true) then
        local sum = 0
        for _, o in ipairs(M.db.orders) do
            if o.status ~= 'cancelled' and o.created_at > now() - 3600 then sum = sum + o.face end
        end
        return sum
    end
    fail(query)
end

function M.update(query, params)
    params = params or {}
    if query:find('SET for_sale = 0 WHERE id = ? AND for_sale = 1', 1, true) then
        local p = findProperty(tonumber(params[1]))
        if p and tonumber(p.for_sale) == 1 then
            p.for_sale = 0
            return 1
        end
        return 0
    end
    if query:find('SET for_sale = 1 WHERE id = ?', 1, true) then
        local p = findProperty(tonumber(params[1]))
        if p then p.for_sale = 1; return 1 end
        return 0
    end
    if query:find('DELETE FROM som_property_owners WHERE property_id = ? AND citizenid = ?', 1, true) then
        local before = #M.db.owners
        local kept = {}
        for _, o in ipairs(M.db.owners) do
            if not (o.property_id == params[1] and o.citizenid == params[2]) then
                kept[#kept + 1] = o
            end
        end
        M.db.owners = kept
        return before - #kept
    end
    if query:find("UPDATE som_jail_bail SET status = 'forfeited' WHERE citizenid = ? AND status = 'posted'", 1, true) then
        local n = 0
        for _, b in ipairs(M.db.jailBail) do
            if b.citizenid == params[1] and b.status == 'posted' then
                b.status = 'forfeited'
                n = n + 1
            end
        end
        return n
    end
    if query:find('SET status = ?, released_at = CURRENT_TIMESTAMP, released_by = ?', 1, true) then
        local s = findSentence(params[3])
        if not s or s.status ~= 'serving' then return 0 end
        s.status = params[1]
        s.released_by = params[2]
        return 1
    end
    if query:find('SET release_pending = 1 WHERE id = ?', 1, true) then
        local s = findSentence(params[1])
        if not s then return 0 end
        s.release_pending = 1
        return 1
    end
    if query:find('SET release_pending = 0 WHERE citizenid = ? AND release_pending = 1', 1, true) then
        local n = 0
        for _, s in ipairs(M.db.jailSentences) do
            if s.citizenid == params[1] and s.release_pending == 1 then s.release_pending = 0; n = n + 1 end
        end
        return n
    end
    if query:find("SET status = 'serving', released_at = NULL", 1, true) then
        local s = findSentence(params[1])
        if not s or s.status ~= 'bailed' then return 0 end
        s.status = 'serving'
        return 1
    end
    if query:find("UPDATE som_jail_sentences SET status = 'absconded' WHERE id = ?", 1, true) then
        local s = findSentence(params[1])
        if not s or s.status ~= 'serving' then return 0 end
        s.status = 'absconded'
        return 1
    end
    if query:find("UPDATE som_jail_bail SET status = 'cleared' WHERE status = 'posted'", 1, true) then
        local n = 0
        for _, b in ipairs(M.db.jailBail) do
            if b.status == 'posted' and b.appeal_due_at <= now() then
                b.status = 'cleared'
                n = n + 1
            end
        end
        return n
    end
    if query:find("SET status = 'accepted', prosecutor_cid = ?", 1, true) then
        local c = findCase(params[2])
        if not c or c.status ~= 'filed' then return 0 end
        c.status, c.prosecutor_cid = 'accepted', params[1]
        return 1
    end
    if query:find("SET status = 'dismissed', prosecutor_cid = ?", 1, true) then
        local c = findCase(params[2])
        if not c or not inList(c.status, 'filed', 'accepted') then return 0 end
        c.status, c.prosecutor_cid = 'dismissed', params[1]
        return 1
    end
    if query:find("SET defender_cid = ? WHERE id = ?", 1, true) then
        local c = findCase(params[2])
        if not c or c.defender_cid or not inList(c.status, 'filed', 'accepted', 'scheduled') then return 0 end
        c.defender_cid = params[1]
        return 1
    end
    if query:find("SET status = 'scheduled', judge_cid = ?, hearing_at", 1, true) then
        local c = findCase(params[3])
        if not c or c.status ~= 'accepted' then return 0 end
        c.status, c.judge_cid, c.hearing_at = 'scheduled', params[1], now() + params[2] * 60
        return 1
    end
    if query:find("SET status = 'acquitted'", 1, true) then
        local c = findCase(params[3])
        if not c or c.status ~= 'scheduled' or not c.hearing_at or c.hearing_at > now() then return 0 end
        c.status, c.judge_cid, c.notes = 'acquitted', params[1], params[2]
        return 1
    end
    if query:find("SET status = ?, ruled_at = NOW(), judge_cid = ?", 1, true) then
        local c = findCase(params[8])
        if not c or c.status ~= 'scheduled' or not c.hearing_at or c.hearing_at > now() then return 0 end
        c.status, c.judge_cid, c.sentence_months, c.service_tasks, c.fine, c.bail_amount, c.notes =
            params[1], params[2], params[3], params[4], params[5], params[6], params[7]
        return 1
    end
    if query:find("SET status = 'scheduled', ruled_at = NULL", 1, true) then
        local c = findCase(params[1])
        if not c or not inList(c.status, 'convicted', 'sentenced') then return 0 end
        c.status = 'scheduled'
        return 1
    end
    if query:find("SET status = 'dismissed', judge_cid = ?", 1, true) then
        local c = findCase(params[2])
        if not c or not inList(c.status, 'filed', 'accepted', 'scheduled', 'convicted') then return 0 end
        c.status, c.judge_cid = 'dismissed', params[1]
        return 1
    end
    if query:find("SET sentence_months = ?", 1, true) then
        local c = findCase(params[2])
        if not c or c.status ~= 'convicted' or c.sentence_months < params[3] then return 0 end
        c.sentence_months = params[1]
        return 1
    end
    if query:find("SET bail_amount = ?", 1, true) then
        local c = findCase(params[2])
        if not c or c.class ~= 'felony' or not inList(c.status, 'accepted', 'scheduled') then return 0 end
        c.bail_amount = params[1]
        return 1
    end
    if query:find("SET notes = 'failure to appear'", 1, true) then
        local c = findCase(params[1])
        if not c or c.status ~= 'scheduled' or not c.hearing_at or c.hearing_at > now() - params[2] * 60 then return 0 end
        c.notes = 'failure to appear'
        return 1
    end
    if query:find("SET status = 'sentenced' WHERE id = ? AND defendant_cid = ?", 1, true) then
        local c = findCase(params[1])
        if not c or c.defendant_cid ~= params[2] or c.status ~= 'convicted' or (c.sentence_months < 1 and (c.service_tasks or 0) < 1) then return 0 end
        c.status = 'sentenced'
        return 1
    end
    if query:find("SET status = 'convicted' WHERE id = ? AND status = 'sentenced'", 1, true) then
        local c = findCase(params[1])
        if not c or c.status ~= 'sentenced' then return 0 end
        c.status = 'convicted'
        return 1
    end
    if query:find("SET status = 'served' WHERE citizenid = ?", 1, true) then
        local n = 0
        for _, w in ipairs(M.db.courtWarrants) do
            if w.citizenid == params[1] and liveWarrant(w) then w.status = 'served'; n = n + 1 end
        end
        return n
    end
    if query:find("SET status = 'expired' WHERE status = 'active'", 1, true) then
        local n = 0
        for _, w in ipairs(M.db.courtWarrants) do
            if w.status == 'active' and w.expires_at <= now() then w.status = 'expired'; n = n + 1 end
        end
        return n
    end
    if query:find("UPDATE som_community_service SET status = 'cancelled'", 1, true) then
        local r = activeService(params[1])
        if not r then return 0 end
        r.status = 'cancelled'
        return 1
    end
    if query:find("UPDATE som_community_service SET status = 'completed'", 1, true) then
        local r = findService(params[1])
        if not r or r.status ~= 'active' or r.tasks_done < r.tasks_total then return 0 end
        r.status = 'completed'
        return 1
    end
    if query:find("SET tasks_done = tasks_done + 1", 1, true) then
        local r = activeService(params[1])
        if not r or r.tasks_done >= r.tasks_total then return 0 end
        if r.last_task_at and r.last_task_at > now() - params[2] then return 0 end
        r.tasks_done, r.last_task_at = r.tasks_done + 1, now()
        return 1
    end
    if query:find("SET tasks_total = LEAST(tasks_total + ?, ?)", 1, true) then
        local r = findService(params[3])
        if not r or r.status ~= 'active' then return 0 end
        if r.last_penalty_at and r.last_penalty_at > now() - params[4] then return 0 end
        r.tasks_total = math.min(r.tasks_total + params[1], params[2])
        r.strikes, r.last_penalty_at = r.strikes + 1, now()
        return 1
    end
    if query:find("UPDATE som_community_service SET status = 'absconded'", 1, true) then
        local r = findService(params[1])
        if not r or r.status ~= 'active' then return 0 end
        r.status = 'absconded'
        return 1
    end
    if query:find("SET status = 'collected', holder_cid = ?, station = NULL", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.status ~= 'stored' or r.station ~= params[3] then return 0 end
        r.status, r.holder_cid, r.station = 'collected', params[1], nil
        return 1
    end
    if query:find("SET status = 'collected', holder_cid = ?", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.status ~= 'scene' or r.expires_at <= now() then return 0 end
        r.status, r.holder_cid = 'collected', params[1]
        return 1
    end
    if query:find("SET status = 'scene', holder_cid = NULL", 1, true) then
        local r = findEvidence(params[1])
        if not r or r.status ~= 'collected' then return 0 end
        r.status, r.holder_cid = 'scene', nil
        return 1
    end
    if query:find("SET status = 'stored', station = ?, holder_cid = NULL", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.status ~= 'collected' or r.holder_cid ~= params[3] then return 0 end
        r.status, r.station, r.holder_cid = 'stored', params[1], nil
        return 1
    end
    if query:find("SET status = 'stored', holder_cid = NULL, station = ?", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.status ~= 'collected' then return 0 end
        r.status, r.holder_cid, r.station = 'stored', nil, params[1]
        return 1
    end
    if query:find("SET analysed_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.analysed_at or not (r.status == 'collected' or r.status == 'stored') then return 0 end
        if not (r.holder_cid == params[3] or r.station == params[4]) then return 0 end
        r.analysed_at = now() + params[1] * 60
        return 1
    end
    if query:find("UPDATE som_evidence SET case_id = ?", 1, true) then
        local r = findEvidence(params[2])
        if not r or r.case_id or not (r.status == 'collected' or r.status == 'stored') then return 0 end
        if not (r.holder_cid == params[3] or r.station == params[4]) then return 0 end
        r.case_id = params[1]
        return 1
    end
    if query:find("SET status = 'destroyed' WHERE id = ?", 1, true) then
        local r = findEvidence(params[1])
        if not r then return 0 end
        r.status = 'destroyed'
        return 1
    end
    if query:find("SET status = 'destroyed' WHERE status = 'scene' AND expires_at <= NOW()", 1, true) then
        local n = 0
        for _, r in ipairs(M.db.evidence) do
            if r.status == 'scene' and r.expires_at <= now() then r.status = 'destroyed'; n = n + 1 end
        end
        return n
    end
    if query:find("UPDATE som_marked_bills SET status = 'void'", 1, true) then
        local b = M.db.bills[params[1]]
        if not b or b.status ~= 'issued' then return 0 end
        b.status = 'void'
        return 1
    end
    if query:find("SET status = 'washing', order_id = ? WHERE uid = ?", 1, true) then
        local b = M.db.bills[params[2]]
        if not b or b.status ~= 'issued' then return 0 end
        b.status, b.order_id = 'washing', params[1]
        return 1
    end
    if query:find("SET status = 'issued', order_id = NULL WHERE uid = ?", 1, true) then
        local b = M.db.bills[params[1]]
        if not b or b.status ~= 'washing' then return 0 end
        b.status, b.order_id = 'issued', nil
        return 1
    end
    if query:find("UPDATE som_launder_orders SET status = 'cancelled'", 1, true) then
        local o = findOrder(params[1])
        if not o or o.status ~= 'washing' then return 0 end
        o.status = 'cancelled'
        return 1
    end
    if query:find("UPDATE som_launder_orders SET status = 'collected'", 1, true) then
        local o = findOrder(params[1])
        if not o or o.citizenid ~= params[2] or o.status ~= 'washing' or o.ready_at > now() then return 0 end
        o.status = 'collected'
        return 1
    end
    if query:find("UPDATE som_launder_orders SET status = 'washing'", 1, true) then
        local o = findOrder(params[1])
        if not o or o.status ~= 'collected' then return 0 end
        o.status = 'washing'
        return 1
    end
    if query:find("UPDATE som_marked_bills SET status = 'washed' WHERE order_id = ?", 1, true) then
        local n = 0
        for _, b in pairs(M.db.bills) do
            if b.order_id == params[1] and b.status == 'washing' then b.status = 'washed'; n = n + 1 end
        end
        return n
    end
    fail(query)
end

function M.insert(query, params)
    params = params or {}
    if query:find('INSERT INTO som_property_owners', 1, true) then
        local propertyId, citizenid, role, grantedBy = params[1], params[2], params[3], params[4]
        local existing = findOwner(propertyId, citizenid)
        if existing then
            existing.role = role
            existing.granted_by = grantedBy
        else
            M.db.owners[#M.db.owners + 1] = {
                property_id = propertyId, citizenid = citizenid, role = role, granted_by = grantedBy,
            }
        end
        return 1
    end
    if query:find('INSERT INTO som_property_finance', 1, true) then
        local id = M.db.nextId.finance
        M.db.nextId.finance = id + 1
        M.db.finance[#M.db.finance + 1] = {
            id = id, property_id = params[1], citizenid = params[2], principal = params[3],
            remaining = params[4], instalment = params[5], interval_days = params[6],
            realtor_citizenid = params[8], status = 'active', missed_cycles = 0,
        }
        return id
    end
    if query:find('INSERT INTO som_jail_sentences', 1, true) then
        local id = M.db.nextId.jailSentences
        M.db.nextId.jailSentences = id + 1
        M.db.jailSentences[#M.db.jailSentences + 1] = {
            id = id, citizenid = params[1], officer_cid = params[2], case_id = params[3],
            charges = params[4], total_seconds = params[5], kind = params[6], status = 'serving',
            booked_at = now(), released_at = nil, released_by = nil, release_pending = 0,
        }
        return id
    end
    if query:find('INSERT INTO som_jail_bail', 1, true) then
        local id = M.db.nextId.jailBail
        M.db.nextId.jailBail = id + 1
        M.db.jailBail[#M.db.jailBail + 1] = {
            id = id, sentence_id = params[1], citizenid = params[2], amount = params[3],
            status = 'posted', posted_at = now(), appeal_due_at = now() + (tonumber(params[4]) or 0) * 3600,
        }
        return id
    end
    if query:find('INSERT INTO som_court_cases', 1, true) then
        local id = M.db.nextId.courtCases
        M.db.nextId.courtCases = id + 1
        M.db.courtCases[#M.db.courtCases + 1] = {
            id = id, defendant_cid = params[1], filed_by = params[2], incident_id = params[3],
            charges = params[4], class = params[5], status = 'filed', sentence_months = 0, service_tasks = 0, fine = 0,
        }
        return id
    end
    if query:find('INSERT INTO som_court_events', 1, true) then
        local id = M.db.nextId.courtEvents
        M.db.nextId.courtEvents = id + 1
        M.db.courtEvents[#M.db.courtEvents + 1] = {
            id = id, case_id = params[1], actor_cid = params[2], action = params[3], detail = params[4],
        }
        return id
    end
    if query:find('INSERT INTO som_court_warrants', 1, true) then
        local id = M.db.nextId.courtWarrants
        M.db.nextId.courtWarrants = id + 1
        M.db.courtWarrants[#M.db.courtWarrants + 1] = {
            id = id, citizenid = params[1], case_id = params[2], reason = params[3], issued_by = params[4],
            status = 'active', expires_at = now() + params[5] * 3600,
        }
        return id
    end
    if query:find('INSERT INTO som_community_service', 1, true) then
        local id = M.db.nextId.service
        M.db.nextId.service = id + 1
        M.db.service[#M.db.service + 1] = {
            id = id, citizenid = params[1], case_id = params[2], issued_by = params[3], tasks_total = params[4],
            tasks_done = 0, strikes = 0, status = 'active',
        }
        return id
    end
    if query:find('INSERT IGNORE INTO som_evidence_profiles', 1, true) then
        for cid, code in pairs(M.db.profiles) do
            if cid == params[1] or code == params[2] then return 0 end
        end
        M.db.profiles[params[1]] = params[2]
        return 1
    end
    if query:find("VALUES (?, ?, ?, ?, 'collected'", 1, true) and query:find('INSERT INTO som_evidence', 1, true) then
        local id = M.db.nextId.evidence
        M.db.nextId.evidence = id + 1
        M.db.evidence[#M.db.evidence + 1] = {
            id = id, kind = params[1], x = params[2], y = params[3], z = params[4], status = 'collected',
            holder_cid = params[5], source_cid = params[6], profile = params[7], expires_at = now() + 10 * 365 * 86400,
        }
        return id
    end
    if query:find('INSERT INTO som_evidence_custody', 1, true) then
        M.db.custody[#M.db.custody + 1] = { evidence_id = params[1], actor_cid = params[2], action = params[3], detail = params[4] }
        return #M.db.custody
    end
    if query:find('INSERT INTO som_evidence (kind, x, y, z, source_cid', 1, true) then
        local id = M.db.nextId.evidence
        M.db.nextId.evidence = id + 1
        M.db.evidence[#M.db.evidence + 1] = {
            id = id, kind = params[1], x = params[2], y = params[3], z = params[4], status = 'scene',
            source_cid = params[5], profile = params[6], weapon_serial = params[7], expires_at = now() + params[8] * 60,
        }
        return id
    end
    if query:find('INSERT INTO som_marked_bills', 1, true) then
        M.db.bills[params[1]] = { worth = params[2], status = 'issued', source_tag = params[3] }
        return 1
    end
    if query:find('INSERT INTO som_launder_orders', 1, true) then
        local id = M.db.nextId.orders
        M.db.nextId.orders = id + 1
        M.db.orders[#M.db.orders + 1] = {
            id = id, citizenid = params[1], front = params[2], face = params[3], payout = params[4],
            status = 'washing', created_at = now(), ready_at = now() + params[5] * 60,
        }
        return id
    end
    fail(query)
end

function M.query(query, params)
    params = params or {}
    -- jail.lua's sweep: every serving sentence, with elapsed.
    if query:find("FROM som_jail_sentences WHERE status = 'serving'", 1, true) then
        local out = {}
        for _, s in ipairs(M.db.jailSentences) do
            if s.status == 'serving' then
                local row = copy(s)
                row.elapsed = now() - s.booked_at
                out[#out + 1] = row
            end
        end
        return out
    end
    local function cases(filter)
        local out = {}
        for i = #M.db.courtCases, 1, -1 do
            local c = M.db.courtCases[i]
            if filter(c) then out[#out + 1] = copy(c) end
        end
        return out
    end
    if query:find("WHERE status IN ('accepted','scheduled','convicted') ORDER BY", 1, true) then
        return cases(function(c) return inList(c.status, 'accepted', 'scheduled', 'convicted') end)
    end
    if query:find("WHERE status IN ('filed','accepted') ORDER BY", 1, true) then
        return cases(function(c) return inList(c.status, 'filed', 'accepted') end)
    end
    if query:find("(defender_cid = ? OR defender_cid IS NULL)", 1, true) then
        return cases(function(c)
            return (c.defender_cid == params[1] or c.defender_cid == nil)
                and inList(c.status, 'filed', 'accepted', 'scheduled')
        end)
    end
    if query:find('FROM som_court_cases WHERE filed_by = ?', 1, true) then
        return cases(function(c) return c.filed_by == params[1] end)
    end
    if query:find('FROM som_court_cases WHERE defendant_cid = ? ORDER BY', 1, true) then
        return cases(function(c) return c.defendant_cid == params[1] end)
    end
    if query:find("(sentence_months > 0 OR service_tasks > 0)", 1, true) then
        return cases(function(c)
            return c.defendant_cid == params[1]
                and (inList(c.status, 'filed', 'accepted', 'scheduled')
                    or (c.status == 'convicted' and (c.sentence_months > 0 or (c.service_tasks or 0) > 0)))
        end)
    end
    if query:find("FROM som_court_warrants WHERE citizenid = ? AND status = 'active'", 1, true) then
        local out = {}
        for _, w in ipairs(M.db.courtWarrants) do
            if w.citizenid == params[1] and liveWarrant(w) then out[#out + 1] = copy(w) end
        end
        return out
    end
    if query:find("FROM som_community_service WHERE status = 'active'", 1, true) then
        local out = {}
        for _, r in ipairs(M.db.service) do
            if r.status == 'active' then out[#out + 1] = copy(r) end
        end
        return out
    end
    if query:find('SELECT id, kind, x, y, z FROM som_evidence', 1, true) then
        local out = {}
        for _, r in ipairs(M.db.evidence) do
            if r.status == 'scene' and r.expires_at > now()
                and r.x >= params[1] and r.x <= params[2] and r.y >= params[3] and r.y <= params[4] then
                out[#out + 1] = copy(r)
            end
        end
        return out
    end
    if query:find("WHERE holder_cid = ? AND status = 'collected' LIMIT 25", 1, true) then
        local out = {}
        for _, r in ipairs(M.db.evidence) do
            if r.holder_cid == params[1] and r.status == 'collected' then out[#out + 1] = copy(r) end
        end
        return out
    end
    if query:find("WHERE station = ? AND status = 'stored' ORDER BY", 1, true) then
        local out = {}
        for _, r in ipairs(M.db.evidence) do
            if r.station == params[1] and r.status == 'stored' then out[#out + 1] = copy(r) end
        end
        return out
    end
    if query:find("FROM som_evidence WHERE case_id = ? AND status <> 'destroyed'", 1, true) then
        local out = {}
        for _, r in ipairs(M.db.evidence) do
            if r.case_id == params[1] and r.status ~= 'destroyed' then out[#out + 1] = copy(r) end
        end
        return out
    end
    if query:find('ready_at <= NOW() AS ready FROM som_launder_orders', 1, true) then
        local out = {}
        for _, o in ipairs(M.db.orders) do
            if o.citizenid == params[1] and o.front == params[2] and o.status == 'washing' then
                local row = copy(o)
                row.ready = o.ready_at <= now() and 1 or 0
                out[#out + 1] = row
            end
        end
        return out
    end
    fail(query)
end

_G.MySQL = {
    single = { await = function(q, p) return M.single(q, p) end },
    scalar = { await = function(q, p) return M.scalar(q, p) end },
    update = { await = function(q, p) return M.update(q, p) end },
    insert = { await = function(q, p) return M.insert(q, p) end },
    query  = { await = function(q, p) return M.query(q, p) end },
}

return M
