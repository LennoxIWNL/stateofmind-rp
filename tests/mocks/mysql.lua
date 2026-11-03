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
    nextId = { properties = 1, owners = 1, finance = 1 },
}

local function findProperty(id)
    for _, p in ipairs(M.db.properties) do
        if p.id == id then return p end
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
    fail(query)
end

function M.query(query, params)
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
