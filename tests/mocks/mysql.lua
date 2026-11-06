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
    devices = {},
    characters = {},
    contacts = {},
    blocks = {},
    messages = {},
    phoneCalls = {},
    phoneAudit = {},
    notes = {},
    heist = { dongles = {}, runs = {} },
    turf = { zones = {}, events = {}, market = {} },
    whitelist = {},
    bans = {},
    buyer = {},
    placements = {},
    trade = {},
    skills = {},
    newlife = {},
    chop = { log = {}, owned = {} },
    lab = {},
    plants = {},
    gangs = { chars = {}, log = {} },
    staff = { reports = {}, audit = {} },
    vehicles = {},
    social = { handles = {}, posts = {}, likes = {}, reports = {}, adverts = {}, optin = {}, people = {} },
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


-- Chirp and Pages. Returns handled, value.
local function social(kind, query, params)
    local S = M.db.social
    local function has(text) return query:find(text, 1, true) ~= nil end
    local function post(id) return S.posts[id] end

    if kind == 'single' then
        if has('SELECT handle, colour FROM som_phone_handles WHERE citizenid = ?') then
            local h = S.handles[params[1]]
            return true, h and { handle = h.handle, colour = h.colour } or nil
        end
        if has('AS day, COALESCE(MAX(UNIX_TIMESTAMP(created_at)), 0) AS last') then
            local day, last = 0, 0
            for _, x in ipairs(S.posts) do
                if x.citizenid == params[1] and x.ts > now() - 86400 then day = day + 1; last = math.max(last, x.ts) end
            end
            return true, { day = day, last = last }
        end
        if has('SELECT citizenid, body FROM som_phone_posts WHERE id = ? AND removed = 0') then
            local x = post(params[1])
            return true, x and not x.removed and { citizenid = x.citizenid, body = x.body } or nil
        end
        if has('AS total, SUM(category = ?) AS here') then
            local total, here = 0, 0
            for _, a in ipairs(S.adverts) do
                if a.citizenid == params[2] and a.status == 'active' and not a.expired then
                    total = total + 1
                    if a.category == params[1] then here = here + 1 end
                end
            end
            return true, { total = total, here = here }
        end
        if has('SELECT a.citizenid, a.title, c.phone FROM som_phone_adverts a') then
            local a = S.adverts[params[1]]
            if not a or a.status ~= 'active' or a.expired then return true, nil end
            return true, { citizenid = a.citizenid, title = a.title, phone = S.people[a.citizenid] and S.people[a.citizenid].phone }
        end
    elseif kind == 'scalar' then
        if has('SELECT 1 FROM som_phone_likes WHERE post_id = ? AND citizenid = ?') then
            return true, S.likes[params[1] .. '|' .. params[2]] and 1 or nil
        end
        if has('SELECT id FROM som_phone_posts WHERE id = ? AND removed = 0 AND reply_to IS NULL') then
            local x = post(params[1])
            return true, x and not x.removed and not x.reply_to and x.id or nil
        end
        if has('SELECT id FROM som_phone_posts WHERE id = ? AND removed = 0') then
            local x = post(params[1])
            return true, x and not x.removed and x.id or nil
        end
        if has('SELECT 1 FROM som_phone_handles WHERE citizenid = ? AND changed_at') then
            local h = S.handles[params[1]]
            return true, h and h.changed and 1 or nil
        end
        if has('SELECT phone FROM som_characters WHERE citizenid = ?') then
            return true, S.people[params[1]] and S.people[params[1]].phone
        end
        if has('SELECT listed FROM som_phone_pages_optin WHERE citizenid = ?') then
            return true, S.optin[params[1]]
        end
    elseif kind == 'insert' then
        if has('INSERT INTO som_phone_handles (citizenid, handle)') then
            for _, h in pairs(S.handles) do if h.handle == params[2] then error('Duplicate entry') end end
            S.handles[params[1]] = { handle = params[2] }
            return true, 1
        end
        if has('INSERT INTO som_phone_posts') then
            local id = #S.posts + 1
            S.posts[id] = { id = id, citizenid = params[1], business = params[2], body = params[3], image = params[4],
                reply_to = params[5], likes = 0, removed = false, ts = now() }
            return true, id
        end
        if has('INSERT INTO som_phone_adverts') then
            local id = #S.adverts + 1
            S.adverts[id] = { id = id, citizenid = params[1], category = params[2], title = params[3], body = params[4],
                price = params[5], show_number = params[6], business = params[7], status = 'active', hours = params[8] }
            return true, id
        end
        if has('INSERT INTO som_phone_pages_optin') then
            S.optin[params[1]] = params[2]
            return true, 1
        end
    elseif kind == 'update' then
        if has('INSERT IGNORE INTO som_phone_likes') then
            local key = params[1] .. '|' .. params[2]
            if S.likes[key] then return true, 0 end
            S.likes[key] = true
            return true, 1
        end
        if has('UPDATE som_phone_posts SET likes = likes + 1') then post(params[1]).likes = post(params[1]).likes + 1; return true, 1 end
        if has('UPDATE som_phone_posts SET likes = GREATEST(likes - 1, 0)') then post(params[1]).likes = math.max(0, post(params[1]).likes - 1); return true, 1 end
        if has('DELETE FROM som_phone_likes WHERE post_id = ? AND citizenid = ?') then
            local key = params[1] .. '|' .. params[2]
            local had = S.likes[key]
            S.likes[key] = nil
            return true, had and 1 or 0
        end
        if has('UPDATE som_phone_posts SET removed = 1 WHERE id = ? AND citizenid = ? AND removed = 0') then
            local x = post(params[1])
            if x and x.citizenid == params[2] and not x.removed then x.removed = true; return true, 1 end
            return true, 0
        end
        if has('UPDATE som_phone_posts SET removed = 1 WHERE id = ? AND removed = 0') then
            local x = post(params[1])
            if x and not x.removed then x.removed = true; return true, 1 end
            return true, 0
        end
        if has('INSERT IGNORE INTO som_phone_reports') then
            local key = params[1] .. '|' .. params[2]
            if S.reports[key] then return true, 0 end
            S.reports[key] = params[3]
            return true, 1
        end
        if has('UPDATE som_phone_handles SET handle = ?, changed_at = NOW()') then
            for cid, h in pairs(S.handles) do if h.handle == params[1] and cid ~= params[2] then error('Duplicate entry') end end
            S.handles[params[2]].handle, S.handles[params[2]].changed = params[1], true
            return true, 1
        end
        if has('UPDATE som_phone_handles SET colour = ? WHERE citizenid = ?') then
            S.handles[params[2]].colour = params[1]
            return true, 1
        end
        if has("UPDATE som_phone_adverts SET status = 'removed' WHERE id = ? AND citizenid = ?") then
            local a = S.adverts[params[1]]
            if a and a.citizenid == params[2] and a.status == 'active' then a.status = 'removed'; return true, 1 end
            return true, 0
        end
        if has("UPDATE som_phone_adverts SET status = 'removed' WHERE id = ? AND status = 'active'") then
            local a = S.adverts[params[1]]
            if a and a.status == 'active' then a.status = 'removed'; return true, 1 end
            return true, 0
        end
    elseif kind == 'query' then
        if has('FROM som_phone_posts p JOIN som_phone_handles h') then
            local out, threadOf = {}, has('p.id = ? OR p.reply_to = ?') and params[1]
            for i = #S.posts, 1, -1 do
                local x = S.posts[i]
                local pick = not x.removed and ((threadOf and (x.id == threadOf or x.reply_to == threadOf)) or (not threadOf and not x.reply_to))
                if pick then
                    local h = S.handles[x.citizenid]
                    local replies = 0
                    for _, r in ipairs(S.posts) do if r.reply_to == x.id and not r.removed then replies = replies + 1 end end
                    out[#out + 1] = { id = x.id, citizenid = x.citizenid, handle = h.handle, colour = h.colour, business = x.business,
                        body = x.body, image = x.image, likes = x.likes, reply_to = x.reply_to, created_at = 'now', replies = replies }
                end
            end
            if threadOf then table.sort(out, function(a, b) return a.id < b.id end) end
            return true, out
        end
        if has('FROM som_phone_adverts a JOIN som_phone_handles h') then
            local out = {}
            for i = #S.adverts, 1, -1 do
                local a = S.adverts[i]
                if a.status == 'active' and not a.expired and (params[1] == nil or a.category == params[1]) then
                    out[#out + 1] = { id = a.id, citizenid = a.citizenid, category = a.category, title = a.title, body = a.body, price = a.price,
                        show_number = a.show_number, business = a.business, created_at = 'now', handle = S.handles[a.citizenid].handle }
                end
            end
            return true, out
        end
        if has('FROM som_phone_pages_optin o') then
            local needle = params[1]:gsub('\\', ''):gsub('^%%', ''):gsub('%%$', ''):lower()
            local out = {}
            for cid, listed in pairs(S.optin) do
                local c = S.people[cid]
                if listed == 1 and c and (c.firstname .. ' ' .. c.lastname):lower():find(needle, 1, true) then
                    out[#out + 1] = { firstname = c.firstname, lastname = c.lastname, phone = c.phone }
                end
            end
            return true, out
        end
    end
    return false
end

local function city(kind, query, params)
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'query' then
        if has('SELECT plate, model, garage, state FROM som_vehicles WHERE citizenid = ?') then
            local out = {}
            for _, v in ipairs(M.db.vehicles) do
                if v.citizenid == params[1] and #out < params[2] then out[#out + 1] = { plate = v.plate, model = v.model, garage = v.garage, state = v.state } end
            end
            return true, out
        end
        if has('SELECT id, title, body FROM som_phone_notes WHERE citizenid = ?') then
            local out = {}
            for i = #M.db.notes, 1, -1 do
                local n = M.db.notes[i]
                if n.citizenid == params[1] and #out < params[2] then out[#out + 1] = { id = n.id, title = n.title, body = n.body } end
            end
            return true, out
        end
    elseif kind == 'scalar' then
        if has('SELECT COUNT(*) FROM som_phone_notes WHERE citizenid = ?') then
            local n = 0
            for _, x in ipairs(M.db.notes) do if x.citizenid == params[1] then n = n + 1 end end
            return true, n
        end
    elseif kind == 'insert' then
        if has('INSERT INTO som_phone_notes') then
            local id = #M.db.notes + 1
            M.db.notes[id] = { id = id, citizenid = params[1], title = params[2], body = params[3] }
            return true, id
        end
    elseif kind == 'update' then
        if has('UPDATE som_phone_notes SET title = ?, body = ? WHERE id = ? AND citizenid = ?') then
            local n = M.db.notes[params[3]]
            if n and n.citizenid == params[4] then n.title, n.body = params[1], params[2]; return true, 1 end
            return true, 0
        end
        if has('DELETE FROM som_phone_notes WHERE id = ? AND citizenid = ?') then
            local n = M.db.notes[params[1]]
            if n and n.citizenid == params[2] then M.db.notes[params[1]] = { id = params[1], citizenid = '' }; return true, 1 end
            return true, 0
        end
    end
    return false
end

local function heist(kind, query, params)
    local H = M.db.heist
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'insert' then
        if has('INSERT INTO som_heist_dongles') then
            H.dongles[params[1]] = { status = 'issued', tag = params[2] }
            return true, 1
        end
        if has('INSERT INTO som_heist_runs') then
            local site, tier, group, cooldown = params[1], params[2], params[3], params[5]
            for _, r in ipairs(H.runs) do
                if r.site == site and not r.deleted and (r.status == 'active' or r.ts > now() - cooldown * 60) then return true, 0 end
            end
            local id = #H.runs + 1
            H.runs[id] = { id = id, site = site, tier = tier, group = group, status = 'active', clean_paid = 0, ts = now() }
            return true, id
        end
    elseif kind == 'scalar' then
        if has('SELECT status FROM som_heist_dongles WHERE uid = ?') then
            return true, H.dongles[params[1]] and H.dongles[params[1]].status or nil
        end
        if has('SELECT COALESCE(SUM(clean_paid), 0) FROM som_heist_runs WHERE tier = ?') then
            local sum = 0
            for _, r in ipairs(H.runs) do
                if r.tier == params[1] and not r.deleted and r.ts > now() - 3600 then sum = sum + r.clean_paid end
            end
            return true, sum
        end
    elseif kind == 'update' then
        if has("UPDATE som_heist_dongles SET status = 'used' WHERE uid = ? AND status = 'issued'") then
            local d = H.dongles[params[1]]
            if d and d.status == 'issued' then d.status = 'used'; return true, 1 end
            return true, 0
        end
        if has("UPDATE som_heist_dongles SET status = 'void' WHERE uid = ? AND status = 'issued'") then
            local d = H.dongles[params[1]]
            if d and d.status == 'issued' then d.status = 'void'; return true, 1 end
            return true, 0
        end
        if has("UPDATE som_heist_runs SET status = ? WHERE id = ? AND status = 'active'") then
            local r = H.runs[params[2]]
            if r and r.status == 'active' then r.status = params[1]; return true, 1 end
            return true, 0
        end
        if has('UPDATE som_heist_runs SET clean_paid = clean_paid + ? WHERE id = ?') then
            H.runs[params[2]].clean_paid = H.runs[params[2]].clean_paid + params[1]
            return true, 1
        end
        if has("UPDATE som_heist_runs SET status = 'failed' WHERE status = 'active'") then
            for _, r in ipairs(H.runs) do if r.status == 'active' then r.status = 'failed' end end
            return true, 1
        end
        if has('DELETE FROM som_heist_runs WHERE id = ?') then
            if H.runs[params[1]] then H.runs[params[1]].deleted = true end
            return true, 1
        end
    end
    return false
end

local function bans(kind, query, params)
    local B = M.db.bans
    if kind == 'insert' and query:find('INSERT INTO som_bans', 1, true) then
        B[#B + 1] = { identifier = params[1], reason = params[2], by = params[3], revoked = 0, expires = params[4] ~= 0 and (now() + params[5] * 3600) or nil }
        return true, #B
    elseif kind == 'single' and query:find('FROM som_bans WHERE identifier = ?', 1, true) then
        for i = #B, 1, -1 do
            local r = B[i]
            if r.identifier == params[1] and r.revoked == 0 and (r.expires == nil or r.expires > now()) then
                return true, { reason = r.reason, permanent = r.expires == nil and 1 or 0 }
            end
        end
        return true, nil
    elseif kind == 'update' and query:find('UPDATE som_bans SET revoked = 1', 1, true) then
        local n = 0
        for _, r in ipairs(B) do if r.identifier == params[1] and r.revoked == 0 then r.revoked = 1; n = n + 1 end end
        return true, n
    end
    return false
end

local function whitelist(kind, query, params)
    local W = M.db.whitelist
    if kind == 'update' and query:find('INSERT IGNORE INTO som_whitelist', 1, true) then
        if W[params[1]] then return true, 0 end
        W[params[1]] = { note = params[2], added_by = params[3] }
        return true, 1
    elseif kind == 'update' and query:find('DELETE FROM som_whitelist WHERE identifier = ?', 1, true) then
        local had = W[params[1]] ~= nil
        W[params[1]] = nil
        return true, had and 1 or 0
    elseif kind == 'scalar' and query:find('SELECT 1 FROM som_whitelist WHERE identifier = ?', 1, true) then
        return true, W[params[1]] and 1 or nil
    end
    return false
end

local function newlife(kind, query, params)
    local N = M.db.newlife
    if kind == 'insert' and query:find('INSERT INTO som_new_life', 1, true) then
        N[#N + 1] = { citizenid = params[1], class = params[2], x = params[3], y = params[4], z = params[5], untilAt = now() + params[6] * 60 }
        return true, #N
    elseif kind == 'single' and query:find('FROM som_new_life WHERE citizenid = ?', 1, true) then
        for i = #N, 1, -1 do
            local r = N[i]
            if r.citizenid == params[1] and r.untilAt > now() then
                return true, { class = r.class, x = r.x, y = r.y, z = r.z, minutes_left = math.ceil((r.untilAt - now()) / 60) }
            end
        end
        return true, nil
    end
    return false
end

local function placements(kind, query, params)
    local P = M.db.placements
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'query' and has('SELECT path, kind, value FROM som_placements WHERE resource = ?') then
        local out = {}
        for _, r in ipairs(P) do if r.resource == params[1] then out[#out + 1] = { path = r.path, kind = r.kind, value = r.value } end end
        return true, out
    elseif kind == 'query' and has('FROM som_placements ORDER BY resource, id') then
        local out = {}
        for _, r in ipairs(P) do out[#out + 1] = { resource = r.resource, path = r.path, kind = r.kind, value = r.value } end
        return true, out
    elseif kind == 'update' and has('DELETE FROM som_placements WHERE resource = ? AND path = ?') then
        local n, keep = 0, {}
        for _, r in ipairs(P) do if r.resource == params[1] and r.path == params[2] then n = n + 1 else keep[#keep + 1] = r end end
        M.db.placements = keep
        return true, n
    elseif kind == 'insert' and has('INSERT INTO som_placements') then
        P[#P + 1] = { resource = params[1], path = params[2], kind = params[3], value = params[4], by = params[5] }
        return true, #P
    end
    return false
end

local function moneyRows(kind, query, params)
    if kind == 'scalar' and query:find('SELECT 1 FROM som_character_money WHERE citizenid = ?', 1, true) then
        return true, params[1] == 'OFFLINE1' and 1 or nil
    end
    return false
end

local function trade(kind, query, params)
    local T = M.db.trade
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'insert' and has("SELECT 'FALLBACK', ?, ?, ?, 'done' FROM DUAL") then
        local n = 0
        for _, o in ipairs(T) do
            if o.seller == 'FALLBACK' and o.buyer == params[4] and o.status ~= 'cancelled' and o.ts > now() - 3600 then n = n + 1 end
        end
        if n >= params[5] then return true, 0 end
        T[#T + 1] = { id = #T + 1, seller = 'FALLBACK', buyer = params[1], item = params[2], price = params[3], status = 'done', ts = now() }
        return true, #T
    elseif kind == 'insert' and has('INSERT INTO som_trade_offers') then
        T[#T + 1] = { id = #T + 1, seller = params[1], buyer = params[2], item = params[3], price = params[4], status = 'pending', ts = now() }
        return true, #T
    elseif kind == 'scalar' and has("seller = ? AND status = 'pending'") then
        local n = 0
        for _, o in ipairs(T) do if o.seller == params[1] and o.status == 'pending' and o.ts > now() - params[2] then n = n + 1 end end
        return true, n
    elseif kind == 'scalar' and has("seller = 'FALLBACK'") then
        local n = 0
        for _, o in ipairs(T) do if o.seller == 'FALLBACK' and o.buyer == params[1] and o.status ~= 'cancelled' and o.ts > now() - 3600 then n = n + 1 end end
        return true, n
    elseif kind == 'update' and has("SET status = 'done' WHERE id = ?") then
        local o = T[params[1]]
        if o and o.buyer == params[2] and o.status == 'pending' and o.ts > now() - params[3] then o.status = 'done'; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("SET status = 'cancelled' WHERE id = ? AND buyer = ?") then
        local o = T[params[1]]
        if o and o.buyer == params[2] and o.status == 'pending' then o.status = 'cancelled'; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("SET status = 'cancelled' WHERE id = ?") then
        local o = T[params[1]]
        if o then o.status = 'cancelled' end
        return true, 1
    elseif kind == 'single' and has('SELECT seller, item, price FROM som_trade_offers WHERE id = ?') then
        local o = T[params[1]]
        return true, o and { seller = o.seller, item = o.item, price = o.price } or nil
    elseif kind == 'query' and has('FROM som_trade_offers o JOIN som_characters c') then
        local out = {}
        for i = #T, 1, -1 do
            local o = T[i]
            if o.buyer == params[1] and o.status == 'pending' and o.ts > now() - params[2] then out[#out + 1] = { id = o.id, item = o.item, price = o.price, firstname = 'Mo', lastname = 'Chanic' } end
        end
        return true, out
    end
    return false
end

local function skills(kind, query, params)
    local K = M.db.skills
    if kind == 'scalar' and query:find('SELECT xp FROM som_skills WHERE citizenid = ? AND track = ?', 1, true) then
        local r = K[params[1] .. ':' .. params[2]]
        return true, r and r.xp or nil
    elseif kind == 'query' and query:find('SELECT track, xp FROM som_skills WHERE citizenid = ?', 1, true) then
        local out = {}
        for key, r in pairs(K) do if key:find(params[1] .. ':', 1, true) == 1 then out[#out + 1] = { track = r.track, xp = r.xp } end end
        return true, out
    elseif kind == 'update' and query:find('INSERT INTO som_skills', 1, true) then
        local cid, track, amount, cap = params[1], params[2], params[3], params[4]
        local key = cid .. ':' .. track
        local r = K[key]
        if not r then
            local g = math.min(amount, cap)
            K[key] = { track = track, xp = g, day_xp = g }
        else
            local g = math.min(amount, math.max(0, cap - r.day_xp))
            r.xp, r.day_xp = r.xp + g, r.day_xp + g
        end
        return true, 1
    end
    return false
end

local function chop(kind, query, params)
    local C = M.db.chop
    if kind == 'scalar' and query:find('SELECT 1 FROM som_vehicles WHERE plate = ?', 1, true) then
        return true, C.owned[params[1]] and 1 or nil
    elseif kind == 'insert' and query:find('INSERT INTO som_chop_log', 1, true) then
        local cid, drop, plate, dcool, _, pcool = params[1], params[2], params[3], params[5], params[6], params[7]
        for _, r in ipairs(C.log) do
            if (r.dropoff == drop and r.ts > now() - dcool * 60) or (r.plate == plate and r.ts > now() - pcool * 60) then return true, 0 end
        end
        C.log[#C.log + 1] = { citizenid = cid, dropoff = drop, plate = plate, ts = now() }
        return true, #C.log
    end
    return false
end

local function buyer(kind, query, params)
    local B = M.db.buyer
    if kind == 'scalar' and query:find('FROM som_buyer_payouts WHERE buyer = ?', 1, true) then
        local sum = 0
        for _, r in ipairs(B) do if r.buyer == params[1] and r.ts > now() - 3600 then sum = sum + r.amount end end
        return true, sum
    elseif kind == 'insert' and query:find('INSERT INTO som_buyer_payouts', 1, true) then
        B[#B + 1] = { buyer = params[1], amount = params[2], ts = now() }
        return true, #B
    end
    return false
end

local function lab(kind, query, params)
    local L = M.db.lab
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'scalar' and has("SELECT COUNT(*) FROM som_lab_jobs WHERE citizenid = ?") then
        local n = 0
        for _, j in ipairs(L) do if j.citizenid == params[1] and j.status == 'cooking' then n = n + 1 end end
        return true, n
    elseif kind == 'insert' and has('INSERT INTO som_lab_jobs') then
        for _, j in ipairs(L) do if j.lab == params[5] and j.status == 'cooking' then return true, 0 end end
        local id = #L + 1
        L[id] = { id = id, citizenid = params[1], lab = params[2], recipe = params[3], status = 'cooking', ready = M.fakeNow + params[4] * 60 }
        return true, id
    elseif kind == 'single' and has('FROM som_lab_jobs WHERE lab = ? AND citizenid = ?') then
        for _, j in ipairs(L) do
            if j.lab == params[1] and j.citizenid == params[2] and j.status == 'cooking' then
                return true, { id = j.id, recipe = j.recipe, ready = j.ready <= M.fakeNow and 1 or 0 }
            end
        end
        return true, nil
    elseif kind == 'update' and has("SET status = 'collected' WHERE id = ? AND status = 'cooking'") then
        local j = L[params[1]]
        if j and j.status == 'cooking' then j.status = 'collected'; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("SET status = 'cooking' WHERE id = ? AND status = 'collected'") then
        local j = L[params[1]]
        if j and j.status == 'collected' then j.status = 'cooking'; return true, 1 end
        return true, 0
    end
    return false
end

local function plants(kind, query, params)
    local P = M.db.plants
    local function has(text) return query:find(text, 1, true) ~= nil end
    local function age(p) return now() - p.planted end
    if kind == 'update' and has("SET status = 'withered' WHERE status = 'growing' AND last_water <") then
        for _, p in ipairs(P) do
            if p.status == 'growing' and p.watered < now() - params[1] * 60 then p.status = 'withered' end
        end
        return true, 1
    elseif kind == 'scalar' and has("SELECT COUNT(*) FROM som_plants WHERE citizenid = ?") then
        local n = 0
        for _, p in ipairs(P) do if p.citizenid == params[1] and p.status == 'growing' then n = n + 1 end end
        return true, n
    elseif kind == 'insert' and has('INSERT INTO som_plants') then
        local id = #P + 1
        P[id] = { id = id, citizenid = params[1], strain = params[2], x = params[3], y = params[4], z = params[5], fed = 0, status = 'growing', planted = now(), watered = now() }
        return true, id
    elseif kind == 'query' and has('FROM som_plants WHERE status') then
        local out = {}
        for _, p in ipairs(P) do
            if p.status == 'growing' then out[#out + 1] = { id = p.id, strain = p.strain, x = p.x, y = p.y, z = p.z, fed = p.fed, age = age(p) } end
        end
        return true, out
    elseif kind == 'single' and has('FROM som_plants WHERE id = ?') then
        local p = P[params[1]]
        if p and p.status == 'growing' then return true, { id = p.id, strain = p.strain, x = p.x, y = p.y, z = p.z, fed = p.fed, age = age(p) } end
        return true, nil
    elseif kind == 'update' and has('SET last_water = NOW()') then
        local p = P[params[1]]
        if p and p.status == 'growing' then p.watered = now(); return true, 1 end
        return true, 0
    elseif kind == 'update' and has('SET fed = 1') then
        local p = P[params[1]]
        if p and p.status == 'growing' and p.fed == 0 then p.fed = 1; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("SET status = 'harvested' WHERE id = ? AND status = 'growing'") then
        local p = P[params[1]]
        if p and p.status == 'growing' then p.status = 'harvested'; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("SET status = 'growing' WHERE id = ? AND status = 'harvested'") then
        local p = P[params[1]]
        if p and p.status == 'harvested' then p.status = 'growing'; return true, 1 end
        return true, 0
    end
    return false
end

local function gangs(kind, query, params)
    local G = M.db.gangs
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'query' and has('FROM som_characters') and has('WHERE gang = ?') then
        local out = {}
        for cid, c in pairs(G.chars) do
            if c.gang == params[1] then out[#out + 1] = { citizenid = cid, firstname = c.first, lastname = c.last, gang_grade = c.grade } end
        end
        table.sort(out, function(a, b)
            if a.gang_grade ~= b.gang_grade then return a.gang_grade > b.gang_grade end
            return a.citizenid < b.citizenid
        end)
        return true, out
    elseif kind == 'scalar' and has('SELECT gang_grade FROM som_characters WHERE citizenid = ? AND gang = ?') then
        local c = G.chars[params[1]]
        if c and c.gang == params[2] then return true, c.grade end
        return true, nil
    elseif kind == 'update' and has('UPDATE som_characters SET gang = ?, gang_grade = ? WHERE citizenid = ? AND gang = ?') then
        local c = G.chars[params[3]]
        if c and c.gang == params[4] then c.gang, c.grade = params[1], params[2]; return true, 1 end
        return true, 0
    elseif kind == 'insert' and has('INSERT INTO som_gang_log') then
        G.log[#G.log + 1] = { gang = params[1], actor = params[2], target = params[3], action = params[4], detail = params[5] }
        return true, #G.log
    end
    return false
end

local function staff(kind, query, params)
    local S = M.db.staff
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'insert' and has('INSERT INTO som_reports') then
        for _, r in ipairs(S.reports) do
            if r.citizenid == params[1] and r.status ~= 'closed' then return true, 0 end
        end
        local id = #S.reports + 1
        S.reports[id] = { id = id, citizenid = params[1], name = params[2], message = params[3], status = 'open' }
        return true, id
    elseif kind == 'insert' and has('INSERT INTO som_staff_audit') then
        S.audit[#S.audit + 1] = { staff = params[1], action = params[2], target = params[3] }
        return true, #S.audit
    elseif kind == 'query' and has('FROM som_staff_audit ORDER BY id DESC') then
        local out = {}
        for i = #S.audit, 1, -1 do out[#out + 1] = S.audit[i] end
        return true, out
    elseif kind == 'query' and has('FROM som_reports') then
        local out = {}
        for _, r in ipairs(S.reports) do if r.status ~= 'closed' then out[#out + 1] = r end end
        return true, out
    elseif kind == 'update' and has("UPDATE som_reports SET status = 'claimed'") then
        local r = S.reports[params[2]]
        if r and r.status == 'open' then r.status, r.claimed_by = 'claimed', params[1]; return true, 1 end
        return true, 0
    elseif kind == 'update' and has("UPDATE som_reports SET status = 'closed'") then
        local r = S.reports[params[1]]
        if r and r.status ~= 'closed' then r.status = 'closed'; return true, 1 end
        return true, 0
    end
    return false
end

local function turf(kind, query, params)
    local T = M.db.turf
    local function has(text) return query:find(text, 1, true) ~= nil end
    if kind == 'single' and has('FROM som_turf WHERE name = ?') then
        local z = T.zones[params[1]]
        if not z then return true, nil end
        return true, { name = params[1], owner_gang = z.owner, contested_by = z.contested_by,
                       contest_age = z.contest_started and (now() - z.contest_started) or nil }
    elseif kind == 'query' and has('GROUP BY owner_gang') then
        local counts, out = {}, {}
        for _, z in pairs(T.zones) do if z.owner then counts[z.owner] = (counts[z.owner] or 0) + 1 end end
        for gang, n in pairs(counts) do out[#out + 1] = { owner_gang = gang, zones = n } end
        return true, out
    elseif kind == 'query' and has('FROM som_turf_events e JOIN som_turf t') then
        local out = {}
        for i = #T.events, 1, -1 do
            local e = T.events[i]
            if e.gang == params[1] and e.action ~= 'sale' then out[#out + 1] = { label = e.zone, action = e.action } end
        end
        return true, out
    elseif kind == 'single' and has('SELECT name, owner_gang, contested_by FROM som_turf WHERE name = ?') then
        local z = T.zones[params[1]]
        if not z then return true, nil end
        return true, { name = params[1], owner_gang = z.owner, contested_by = z.contested_by }
    elseif kind == 'insert' and has('INSERT INTO som_turf_events') then
        T.events[#T.events + 1] = { gang = params[1], citizenid = params[2], points = params[3], action = params[4], zone = params[5] }
        return true, #T.events
    elseif kind == 'scalar' and has('FROM som_drug_market WHERE item = ?') then
        local m = T.market[params[2]]
        if not m then return true, nil end
        return true, math.max(0, m.units - math.floor((now() - m.ts) / 3600 * params[1]))
    elseif kind == 'update' then
        if has('INSERT INTO som_drug_market') then
            local m = T.market[params[1]] or { units = 0, ts = now() }
            m.units = math.max(0, m.units - math.floor((now() - m.ts) / 3600 * params[2])) + 1
            m.ts = now()
            T.market[params[1]] = m
            return true, 1
        end
        local z
        if has('SET owner_gang = ?, claimed_at = NOW(), contested_by = NULL, contest_started = NULL WHERE name = ? AND owner_gang IS NULL') then
            z = T.zones[params[2]]
            if z and z.owner == nil then z.owner = params[1]; z.contested_by, z.contest_started = nil, nil; return true, 1 end
            return true, 0
        end
        if has('SET contested_by = ?, contest_started = NOW() WHERE name = ? AND owner_gang = ? AND contested_by IS NULL') then
            z = T.zones[params[2]]
            if z and z.owner == params[3] and z.contested_by == nil then z.contested_by, z.contest_started = params[1], now(); return true, 1 end
            return true, 0
        end
        if has('SET contested_by = NULL, contest_started = NULL WHERE name = ? AND owner_gang = ? AND contested_by IS NOT NULL') then
            z = T.zones[params[1]]
            if z and z.owner == params[2] and z.contested_by ~= nil then z.contested_by, z.contest_started = nil, nil; return true, 1 end
            return true, 0
        end
        if has('SET owner_gang = ?, claimed_at = NOW(), contested_by = NULL, contest_started = NULL') and has('INTERVAL ? MINUTE') then
            z = T.zones[params[2]]
            if z and z.owner == params[3] and z.contested_by == params[4] and z.contest_started and z.contest_started <= now() - params[5] * 60 then
                z.owner = params[1]; z.contested_by, z.contest_started = nil, nil
                return true, 1
            end
            return true, 0
        end
    end
    return false
end

local function fail(query)
    error('tests/mocks/mysql.lua: unhandled query: ' .. query, 3)
end

function M.single(query, params)
    params = params or {}
    do local handled, value = social('single', query, params); if handled then return value end end
    do local handled, value = city('single', query, params); if handled then return value end end
    do local handled, value = heist('single', query, params); if handled then return value end end
    do local handled, value = turf('single', query, params); if handled then return value end end
    do local handled, value = trade('single', query, params); if handled then return value end end
    do local handled, value = bans('single', query, params); if handled then return value end end
    do local handled, value = newlife('single', query, params); if handled then return value end end
    do local handled, value = plants('single', query, params); if handled then return value end end
    do local handled, value = lab('single', query, params); if handled then return value end end
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
    if query:find('SELECT imei, pass_hash FROM som_phone_devices WHERE imei = ?', 1, true) then
        local d = M.db.devices[params[1]]
        return d and { imei = params[1], pass_hash = d.pass_hash } or nil
    end
    if query:find('FROM som_phone_settings WHERE citizenid = ?', 1, true) then return nil end
    if query:find('SELECT citizenid FROM som_characters WHERE phone = ?', 1, true) then
        local cid = M.db.characters[params[1]]
        return cid and { citizenid = cid } or nil
    end
    if query:find('SELECT body, from_number FROM som_phone_messages WHERE id = ?', 1, true) then
        for _, x in ipairs(M.db.messages) do
            if x.id == params[1] then return { body = x.body, from_number = x.from_number } end
        end
        return nil
    end
    fail(query)
end

function M.scalar(query, params)
    params = params or {}
    do local handled, value = social('scalar', query, params); if handled then return value end end
    do local handled, value = city('scalar', query, params); if handled then return value end end
    do local handled, value = heist('scalar', query, params); if handled then return value end end
    do local handled, value = turf('scalar', query, params); if handled then return value end end
    do local handled, value = gangs('scalar', query, params); if handled then return value end end
    do local handled, value = plants('scalar', query, params); if handled then return value end end
    do local handled, value = lab('scalar', query, params); if handled then return value end end
    do local handled, value = buyer('scalar', query, params); if handled then return value end end
    do local handled, value = chop('scalar', query, params); if handled then return value end end
    do local handled, value = skills('scalar', query, params); if handled then return value end end
    do local handled, value = trade('scalar', query, params); if handled then return value end end
    do local handled, value = moneyRows('scalar', query, params); if handled then return value end end
    do local handled, value = whitelist('scalar', query, params); if handled then return value end end
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
    if query:find('SELECT pass_salt FROM som_phone_devices WHERE imei = ?', 1, true) then
        local d = M.db.devices[params[1]]
        return d and d.pass_salt or nil
    end
    if query:find('SELECT SHA2(CONCAT(?, ?, ?), 256)', 1, true) then
        return 'H:' .. params[1] .. ':' .. params[2] .. ':' .. params[3]
    end
    if query:find('SELECT COUNT(*) FROM som_phone_bills', 1, true) then return 0 end
    if query:find('SELECT 1 FROM som_phone_blocks WHERE citizenid = ? AND number = ?', 1, true) then
        return M.db.blocks[params[1] .. '|' .. params[2]] and 1 or nil
    end
    if query:find('SELECT name FROM som_phone_contacts WHERE citizenid = ? AND number = ?', 1, true) then
        return M.db.contacts[params[1] .. '|' .. params[2]]
    end
    if query:find('SELECT COUNT(*) FROM som_phone_contacts WHERE citizenid = ?', 1, true) then
        local n = 0
        for k in pairs(M.db.contacts) do if k:find('^' .. params[1] .. '|') then n = n + 1 end end
        return n
    end
    fail(query)
end

function M.update(query, params)
    params = params or {}
    do local handled, value = social('update', query, params); if handled then return value end end
    do local handled, value = city('update', query, params); if handled then return value end end
    do local handled, value = heist('update', query, params); if handled then return value end end
    do local handled, value = turf('update', query, params); if handled then return value end end
    do local handled, value = whitelist('update', query, params); if handled then return value end end
    do local handled, value = bans('update', query, params); if handled then return value end end
    do local handled, value = staff('update', query, params); if handled then return value end end
    do local handled, value = skills('update', query, params); if handled then return value end end
    do local handled, value = trade('update', query, params); if handled then return value end end
    do local handled, value = placements('update', query, params); if handled then return value end end
    do local handled, value = gangs('update', query, params); if handled then return value end end
    do local handled, value = plants('update', query, params); if handled then return value end end
    do local handled, value = lab('update', query, params); if handled then return value end end
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
    if query:find('UPDATE som_phone_devices SET pass_hash = NULL', 1, true) then
        local d = M.db.devices[params[1]]
        if not d then return 0 end
        d.pass_hash, d.pass_salt = nil, nil
        return 1
    end
    if query:find('UPDATE som_phone_devices SET pass_hash = ?, pass_salt = ?', 1, true) then
        local d = M.db.devices[params[3]]
        if not d then return 0 end
        d.pass_hash, d.pass_salt = params[1], params[2]
        return 1
    end
    if query:find('DELETE FROM som_phone_contacts WHERE citizenid = ? AND number = ?', 1, true) then
        local key = params[1] .. '|' .. params[2]
        local had = M.db.contacts[key] ~= nil
        M.db.contacts[key] = nil
        return had and 1 or 0
    end
    if query:find('DELETE FROM som_phone_blocks WHERE citizenid = ? AND number = ?', 1, true) then
        M.db.blocks[params[1] .. '|' .. params[2]] = nil
        return 1
    end
    if query:find('UPDATE som_phone_messages SET read_at = NOW() WHERE to_number = ?', 1, true) then
        local n = 0
        for _, x in ipairs(M.db.messages) do
            if x.to_number == params[1] and x.from_number == params[2] and not x.read then x.read = true; n = n + 1 end
        end
        return n
    end
    fail(query)
end

function M.insert(query, params)
    params = params or {}
    do local handled, value = social('insert', query, params); if handled then return value end end
    do local handled, value = city('insert', query, params); if handled then return value end end
    do local handled, value = heist('insert', query, params); if handled then return value end end
    do local handled, value = turf('insert', query, params); if handled then return value end end
    do local handled, value = bans('insert', query, params); if handled then return value end end
    do local handled, value = staff('insert', query, params); if handled then return value end end
    do local handled, value = gangs('insert', query, params); if handled then return value end end
    do local handled, value = plants('insert', query, params); if handled then return value end end
    do local handled, value = lab('insert', query, params); if handled then return value end end
    do local handled, value = buyer('insert', query, params); if handled then return value end end
    do local handled, value = chop('insert', query, params); if handled then return value end end
    do local handled, value = trade('insert', query, params); if handled then return value end end
    do local handled, value = placements('insert', query, params); if handled then return value end end
    do local handled, value = newlife('insert', query, params); if handled then return value end end
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
    if query:find('INSERT INTO som_phone_devices', 1, true) then
        M.db.devices[params[1]] = {}
        return 1
    end
    if query:find('INSERT INTO som_phone_audit', 1, true) then
        M.db.phoneAudit[#M.db.phoneAudit + 1] = { citizenid = params[1], app = params[2], action = params[3], ok = params[4] }
        return #M.db.phoneAudit
    end
    if query:find('INSERT INTO som_phone_settings', 1, true) then
        M.db.phoneSettings = M.db.phoneSettings or {}
        M.db.phoneSettings[params[1]] = params[2]
        return 1
    end
    if query:find('INSERT INTO som_phone_contacts', 1, true) then
        M.db.contacts[params[1] .. '|' .. params[2]] = params[3]
        return 1
    end
    if query:find('INSERT IGNORE INTO som_phone_blocks', 1, true) then
        M.db.blocks[params[1] .. '|' .. params[2]] = true
        return 1
    end
    if query:find('INSERT INTO som_phone_messages', 1, true) then
        local id = #M.db.messages + 1
        M.db.messages[id] = { id = id, from_number = params[1], to_number = params[2], body = params[3], read = false }
        return id
    end
    if query:find('INSERT INTO som_phone_calls', 1, true) then
        M.db.phoneCalls[#M.db.phoneCalls + 1] = { from_number = params[1], to_number = params[2], status = params[3], answered = params[4] }
        return #M.db.phoneCalls
    end
    fail(query)
end

function M.query(query, params)
    params = params or {}
    do local handled, value = social('query', query, params); if handled then return value end end
    do local handled, value = city('query', query, params); if handled then return value end end
    do local handled, value = heist('query', query, params); if handled then return value end end
    do local handled, value = turf('query', query, params); if handled then return value end end
    do local handled, value = staff('query', query, params); if handled then return value end end
    do local handled, value = skills('query', query, params); if handled then return value end end
    do local handled, value = trade('query', query, params); if handled then return value end end
    do local handled, value = placements('query', query, params); if handled then return value end end
    do local handled, value = gangs('query', query, params); if handled then return value end end
    do local handled, value = plants('query', query, params); if handled then return value end end
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
    if query:find('SELECT number, name FROM som_phone_contacts WHERE citizenid = ?', 1, true) then
        local out = {}
        for k, name in pairs(M.db.contacts) do
            local cid, number = k:match('^(.-)|(.*)$')
            if cid == params[1] then out[#out + 1] = { number = number, name = name } end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end
    if query:find('SELECT other, MAX(id) AS last_id', 1, true) then
        local me, byOther = params[1], {}
        for _, x in ipairs(M.db.messages) do
            if x.from_number == me or x.to_number == me then
                local other = x.from_number == me and x.to_number or x.from_number
                local t = byOther[other] or { other = other, last_id = 0, unread = 0 }
                byOther[other] = t
                if x.id > t.last_id then t.last_id = x.id end
                if x.to_number == me and not x.read then t.unread = t.unread + 1 end
            end
        end
        local out = {}
        for _, t in pairs(byOther) do out[#out + 1] = t end
        table.sort(out, function(a, b) return a.last_id > b.last_id end)
        return out
    end
    if query:find('SELECT id, from_number, body, created_at FROM som_phone_messages', 1, true) then
        local me, other, out = params[1], params[2], {}
        for i = #M.db.messages, 1, -1 do
            local x = M.db.messages[i]
            if (x.from_number == me and x.to_number == other) or (x.from_number == other and x.to_number == me) then
                out[#out + 1] = { id = x.id, from_number = x.from_number, body = x.body, created_at = 'now' }
            end
        end
        return out
    end
    if query:find('SELECT from_number, to_number, status, created_at FROM som_phone_calls', 1, true) then
        local out = {}
        for i = #M.db.phoneCalls, 1, -1 do
            local c = M.db.phoneCalls[i]
            if c.from_number == params[1] or c.to_number == params[1] then
                out[#out + 1] = { from_number = c.from_number, to_number = c.to_number, status = c.status, created_at = 'now' }
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
    -- Records each transaction so a test can check what would reach the database.
    transaction = { await = function(queries)
        if M.failTransaction then error('simulated database failure') end
        M.transactions[#M.transactions + 1] = queries
        return true
    end },
}
M.transactions = {}

return M
