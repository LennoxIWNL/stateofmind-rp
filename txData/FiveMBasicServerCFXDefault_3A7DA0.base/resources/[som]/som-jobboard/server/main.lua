--- The job board. A provider (a legal run, later each heist) registers itself;
--- a ready group waits on it; a lottery picks one waiting group at a time and
--- offers it the job. Nothing here knows what a job is: the provider starts it
--- and tells the board when it is over.

local core = exports['som-core']
local groups = exports['som-groups']

JobBoard = {}

local providers = {}
local queued = {}
local offers = {}
local running = {}
local active = {}
local refusals = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function tell(source, text)
    if source then exports['som-phone']:notifyApp(source, 'jobs', text) end
end

local function tellGroup(info, text)
    for _, m in ipairs(info.members) do tell(m.source, text) end
end

local function refresh(info)
    for _, m in ipairs(info.members) do
        if m.source then TriggerClientEvent('som-phone:client:refresh', m.source) end
    end
end

local function refusal(groupId)
    refusals[groupId] = refusals[groupId] or { count = 0, lockedUntil = 0 }
    return refusals[groupId]
end

---Whether a group may wait on, or be offered, a provider right now.
---@return boolean ok, string|nil reason
local function eligible(provider, info)
    if not info then return false, 'your group is gone' end
    if info.busy then return false, 'your group is on a job' end
    if not info.allReady then return false, 'everyone must be ready' end

    local size = #info.members
    if size < provider.minSize or size > provider.maxSize then
        return false, ('this job takes %d to %d people'):format(provider.minSize, provider.maxSize)
    end

    if provider.canStart then
        local ok, allowed, why = pcall(provider.canStart, info)
        if not ok or not allowed then return false, (ok and why) or 'not available right now' end
    end

    return true
end

local function dequeue(groupId)
    local entry = queued[groupId]
    if not entry then return end

    queued[groupId] = nil
end

---@param provider table
---@return table[] groups still waiting, oldest first
local function waiting(providerId)
    local list = {}
    for groupId, entry in pairs(queued) do
        if entry.provider == providerId then list[#list + 1] = { id = groupId, since = entry.since } end
    end
    table.sort(list, function(a, b) return a.since < b.since end)
    return list
end

local function weight(since, now)
    local points = math.floor((now - since) / 60 / Config.minutesPerPoint)
    return math.min(1 + points, Config.maxWeight)
end

---One lottery round for one provider. Returns the group id offered, or nil.
---@param providerId string
---@return number|nil
function JobBoard.Draw(providerId)
    local provider = providers[providerId]
    if not provider or (active[providerId] or 0) >= provider.slots then return nil end

    local now = os.time()
    local pool, total = {}, 0

    for _, entry in ipairs(waiting(providerId)) do
        local info = groups:getGroupById(entry.id)
        local ok = eligible(provider, info)
        if ok and not offers[entry.id] then
            local w = weight(entry.since, now)
            pool[#pool + 1] = { id = entry.id, w = w, info = info }
            total = total + w
        elseif not info or info.busy then
            dequeue(entry.id)
        end
    end

    if total == 0 then return nil end

    local roll, picked = math.random() * total, nil
    for _, candidate in ipairs(pool) do
        roll = roll - candidate.w
        if roll <= 0 then picked = candidate break end
    end
    picked = picked or pool[#pool]

    dequeue(picked.id)
    offers[picked.id] = { provider = providerId, expires = now + Config.offerSeconds }
    tellGroup(picked.info, ('%s: you were picked. Open Jobs to accept'):format(provider.label))
    refresh(picked.info)
    return picked.id
end

local function expire(groupId, why)
    local offer = offers[groupId]
    if not offer then return end

    offers[groupId] = nil
    local r = refusal(groupId)
    r.count = r.count + 1
    if r.count >= Config.declinesBeforeLock then
        r.count = 0
        r.lockedUntil = os.time() + Config.lockSeconds
    end

    local info = groups:getGroupById(groupId)
    if info then
        tellGroup(info, why)
        refresh(info)
    end
end

function JobBoard.Tick()
    local now = os.time()

    for groupId, offer in pairs(offers) do
        if offer.expires <= now or not groups:getGroupById(groupId) then expire(groupId, 'The offer ran out') end
    end

    for id in pairs(providers) do JobBoard.Draw(id) end
end

local function view(source)
    local info = groups:getGroup(source)
    if not info then
        return { empty = 'Create or join a group in Groups first' }
    end

    local sections, buttons = {}, {}
    local gid = info.id

    local offer = offers[gid]
    if offer then
        sections[#sections + 1] = { title = 'Offer', rows = { {
            title = providers[offer.provider].label, sub = 'Your group was picked', action = 'accept',
        } } }
        buttons[#buttons + 1] = { label = 'Decline', action = 'decline', danger = true }
        return { sections = sections, buttons = buttons }
    end

    if running[gid] then
        sections[#sections + 1] = { title = 'In progress', rows = { { title = providers[running[gid]].label } } }
        return { sections = sections }
    end

    local lock = refusal(gid).lockedUntil - os.time()
    if lock > 0 then
        return { empty = ('Your group turned down too many offers. Try again in %d minutes'):format(math.ceil(lock / 60)) }
    end

    local entry = queued[gid]
    if entry then
        sections[#sections + 1] = { title = 'Waiting', rows = { {
            title = providers[entry.provider].label,
            sub = ('Waiting %d min'):format(math.floor((os.time() - entry.since) / 60)),
        } } }
        buttons[#buttons + 1] = { label = 'Stop waiting', action = 'unqueue', danger = true }
        return { sections = sections, buttons = buttons }
    end

    local rows = {}
    for id, p in pairs(providers) do
        local _, why = eligible(p, info)
        rows[#rows + 1] = { title = p.label, sub = why or p.summary or 'Ready to wait', action = (not why) and 'queue' or nil, payload = { provider = id }, order = p.label }
    end
    table.sort(rows, function(a, b) return a.order < b.order end)
    for _, r in ipairs(rows) do r.order = nil end

    sections[#sections + 1] = { title = 'Jobs for your group', rows = rows }
    return { sections = sections, empty = 'No jobs are listed yet' }
end

local function leaderOf(source, info)
    return info and info.leader == source
end

local actions = {}

function actions.view(source)
    return done(true, nil, { view = view(source) })
end

function actions.queue(source, payload)
    local info = groups:getGroup(source)
    if not info then return done(false, 'you are not in a group') end
    if not leaderOf(source, info) then return done(false, 'only the leader can do that') end

    local provider = type(payload.provider) == 'string' and providers[payload.provider]
    if not provider then return done(false, 'no such job') end
    if queued[info.id] or offers[info.id] or running[info.id] then return done(false, 'your group is already busy') end
    if refusal(info.id).lockedUntil > os.time() then return done(false, 'your group is locked out for a while') end

    local ok, why = eligible(provider, info)
    if not ok then return done(false, why) end

    queued[info.id] = { provider = payload.provider, since = os.time() }
    refresh(info)
    return done(true)
end

function actions.unqueue(source)
    local info = groups:getGroup(source)
    if not leaderOf(source, info) then return done(false, 'only the leader can do that') end

    dequeue(info.id)
    refresh(info)
    return done(true)
end

function actions.decline(source)
    local info = groups:getGroup(source)
    if not leaderOf(source, info) then return done(false, 'only the leader can do that') end
    if not offers[info.id] then return done(false, 'there is no offer') end

    expire(info.id, 'The offer was declined')
    return done(true)
end

function actions.accept(source)
    local info = groups:getGroup(source)
    if not leaderOf(source, info) then return done(false, 'only the leader can do that') end

    local offer = offers[info.id]
    if not offer or offer.expires <= os.time() then return done(false, 'the offer ran out') end

    local provider = providers[offer.provider]
    local ok, why = eligible(provider, info)
    if not ok then
        offers[info.id] = nil
        return done(false, why)
    end

    offers[info.id] = nil

    local started, err = pcall(provider.start, info)
    if not started or err == false then
        tellGroup(info, 'That job could not start')
        return done(false, 'that job could not start')
    end

    running[info.id] = offer.provider
    active[offer.provider] = (active[offer.provider] or 0) + 1
    groups:setBusy(info.id, provider.label)
    return done(true)
end

local app = {
    id = 'jobs', label = 'Jobs', icon = 'briefcase', colour = '#ff9f0a', order = 55,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        if not fn or not core:getPlayer(source) then return done(false, 'not available') end

        return fn(source, type(payload) == 'table' and payload or {})
    end,
}

exports['som-phone']:registerApp(app)

-- ---------------------------------------------------------------------------
-- For provider resources
-- ---------------------------------------------------------------------------

---@param def table { id, label, summary?, minSize, maxSize, slots, canStart?(info), start(info) }
---@return boolean
exports('registerProvider', function(def)
    if type(def) ~= 'table' or type(def.id) ~= 'string' or not def.id:match('^[%w_%-]+$')
        or type(def.label) ~= 'string' or type(def.start) ~= 'function' then
        return false
    end

    providers[def.id] = {
        id = def.id,
        label = def.label:sub(1, 32),
        summary = type(def.summary) == 'string' and def.summary:sub(1, 80) or nil,
        minSize = math.max(1, math.floor(tonumber(def.minSize) or 1)),
        maxSize = math.max(1, math.floor(tonumber(def.maxSize) or 6)),
        slots = math.max(1, math.floor(tonumber(def.slots) or 1)),
        canStart = type(def.canStart) == 'function' and def.canStart or nil,
        start = def.start,
        resource = GetInvokingResource(),
    }

    return true
end)

---Called by the provider when its job is over, for any reason. Only the
---resource that registered the provider may end its group's job.
---@param groupId number
---@return boolean
exports('finish', function(groupId)
    local id = running[groupId]
    local provider = id and providers[id]
    if not provider or provider.resource ~= GetInvokingResource() then return false end

    running[groupId] = nil
    active[id] = math.max(0, (active[id] or 1) - 1)
    groups:setBusy(groupId, nil)
    return true
end)

AddEventHandler('som-groups:server:changed', function(groupId)
    local info = groups:getGroupById(groupId)

    if not info then
        dequeue(groupId)
        offers[groupId] = nil
        refusals[groupId] = nil

        local id = running[groupId]
        if id then
            running[groupId] = nil
            active[id] = math.max(0, (active[id] or 1) - 1)
        end
        return
    end

    if queued[groupId] and not info.allReady then dequeue(groupId) end
end)

CreateThread(function()
    while true do
        Wait(Config.drawSeconds * 1000)
        pcall(JobBoard.Tick)
    end
end)
