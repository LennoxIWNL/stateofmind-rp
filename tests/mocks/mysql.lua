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
    nextId = { properties = 1, owners = 1, finance = 1, jailSentences = 1, jailBail = 1 },
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
            id = id, citizenid = params[1], officer_cid = params[2], conviction_id = params[3],
            charges = params[4], total_seconds = params[5], status = 'serving',
            booked_at = now(), released_at = nil, released_by = nil,
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
