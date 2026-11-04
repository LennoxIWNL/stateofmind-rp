--- The phone's single entry point. Every request from a player, from the home
--- screen to a message, arrives here as (app, action, payload) and is checked
--- the same way before an app handler sees it. Handlers are local functions, so
--- there is no per-app net event a client could call directly.

local core = exports['som-core']

Phone = { Apps = {}, unlocked = {}, buckets = {} }

local function fail(err) return { success = false, error = err } end

---@param value any
---@param depth number
---@return number|nil size, string|nil reason
local function measure(value, depth)
    if depth > Config.Pipeline.maxDepth then return nil, 'too deep' end

    local kind = type(value)
    if kind == 'string' then return #value end
    if kind == 'number' or kind == 'boolean' then return 8 end
    if kind ~= 'table' then return nil, 'bad value' end

    local total = 0
    for k, v in pairs(value) do
        local keySize = measure(k, depth + 1)
        if not keySize or type(k) == 'table' then return nil, 'bad key' end

        local size, reason = measure(v, depth + 1)
        if not size then return nil, reason end

        total = total + keySize + size
        if total > Config.Pipeline.maxPayload then return nil, 'too big' end
    end

    return total
end

---Registers an app. `actions` is { name = { fn, writes } } for apps in this
---resource; `handler(source, action, payload)` is the form other resources use.
---@param app table
---@return boolean
function Phone.Register(app)
    if type(app) ~= 'table' or type(app.id) ~= 'string' or not app.id:match('^[%w_%-]+$') or #app.id > 32 then
        return false
    end

    local resource = GetInvokingResource()

    Phone.Apps[app.id] = {
        id = app.id,
        label = type(app.label) == 'string' and app.label:sub(1, 32) or app.id,
        icon = app.icon or '?',
        colour = app.colour or '#ff1493',
        order = tonumber(app.order) or 50,
        perk = app.perk,
        jobs = type(app.jobs) == 'table' and app.jobs or nil,
        actions = app.actions,
        handler = type(app.handler) == 'function' and app.handler or nil,
        reads = type(app.reads) == 'table' and app.reads or {},
        resource = resource,
    }

    return true
end

exports('registerApp', Phone.Register)

---@param source number
---@param app table
---@return boolean
local function allowedFor(source, app)
    if app.perk and not core:hasPerk(source, app.perk) then return false end

    if app.jobs then
        local player = core:getPlayer(source)
        if not player then return false end

        for _, job in ipairs(app.jobs) do
            if player.job.name == job then return true end
        end
        return false
    end

    return true
end

---The apps a player may see, in order.
---@param source number
---@return table[]
function Phone.AppsFor(source)
    local list = {}

    for _, app in pairs(Phone.Apps) do
        if app.id ~= 'system' and allowedFor(source, app) then
            list[#list + 1] = { id = app.id, label = app.label, icon = app.icon, colour = app.colour, order = app.order }
        end
    end

    table.sort(list, function(a, b) return a.order == b.order and a.id < b.id or a.order < b.order end)
    return list
end

---@param source number
---@param key string
---@param limit number
---@return boolean ok
local function withinLimit(source, key, limit)
    local now = os.time()
    local mine = Phone.buckets[source]
    if not mine then
        mine = {}
        Phone.buckets[source] = mine
    end

    local bucket = mine[key]
    if not bucket or now - bucket.since >= 60 then
        bucket = { since = now, used = 0 }
        mine[key] = bucket
    end

    bucket.used = bucket.used + 1
    return bucket.used <= limit
end

---Mutating actions leave a row. A read is not worth one.
local function audit(player, appId, action, ok)
    MySQL.insert.await(
        'INSERT INTO som_phone_audit (citizenid, app, action, ok) VALUES (?, ?, ?, ?)',
        { player.citizenid, appId, action, ok and 1 or 0 })
end

---@param app table
---@param action string
---@return function|nil fn, boolean writes
local function resolve(app, action)
    if app.actions then
        local entry = app.actions[action]
        if not entry then return nil, false end
        return entry.fn, entry.writes == true
    end

    if app.handler then
        return function(source, payload) return app.handler(source, action, payload) end, not app.reads[action]
    end

    return nil, false
end

---@param source number
---@param appId any
---@param action any
---@param payload any
---@return table
function Phone.Action(source, appId, action, payload)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    if type(appId) ~= 'string' or type(action) ~= 'string' or #appId > 32 or #action > 32 then
        return fail('bad request')
    end
    if payload ~= nil and type(payload) ~= 'table' then return fail('bad request') end

    local _, reason = measure(payload or {}, 0)
    if reason then return fail('bad request') end

    if GetResourceState('som-medical') == 'started' and exports['som-medical']:isDowned(source) == true then
        return fail('You are in no state to use a phone')
    end

    local device, deviceErr = Phone.DeviceFor(source, player)
    if not device then return fail(deviceErr) end

    -- Opening, unlocking and locking are the only things a locked phone does.
    if appId == 'system' and (action == 'open' or action == 'unlock' or action == 'lock') then
        if not withinLimit(source, 'system:' .. action, Config.Pipeline.readsPerMinute) then return fail('slow down') end
        return Phone.System(source, player, device, action, payload or {})
    end

    if Phone.IsLocked(source, device) then return { success = false, error = 'locked', locked = true } end

    local app = Phone.Apps[appId]
    if not app or not allowedFor(source, app) then return fail('no such app') end

    local fn, writes = resolve(app, action)
    if not fn then return fail('no such action') end

    local limit = writes and Config.Pipeline.writesPerMinute or Config.Pipeline.readsPerMinute
    if not withinLimit(source, appId .. ':' .. action, limit) then return fail('slow down') end

    local ok, result = pcall(fn, source, payload or {}, player)
    if not ok then
        print(('[som-phone] %s:%s failed: %s'):format(appId, action, tostring(result)))
        return fail('something went wrong')
    end

    if type(result) ~= 'table' then result = {} end
    if result.success == nil then result.success = result.error == nil end

    if writes then pcall(audit, player, appId, action, result.success) end

    return result
end

lib.callback.register('som-phone:server:action', function(source, appId, action, payload)
    return Phone.Action(source, appId, action, payload)
end)

AddEventHandler('playerDropped', function()
    local source = source
    Phone.unlocked[source] = nil
    Phone.buckets[source] = nil
end)
