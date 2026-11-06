--- /place, /unplace, /places: staff put content on the map by standing there.
--- Each command writes a row to som_placements, which the content resource reads
--- when it starts, so run `restart <resource>` after placing. Admin only, every
--- change is audited. Made by Lennox.

local core = exports['som-core']

local POINT_FIELDS = { center = true, coords = true, terminal = true, tag = true, lootPoints = true }

local function reply(source, text)
    if source == 0 then print('[som-staff] ' .. text) else TriggerClientEvent('som:client:notify', source, text, 'inform') end
end

local function allowed(source)
    if source == 0 then return true end
    if core:hasPermission(source, 'som.admin') then return true end
    TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    return false
end

local function actor(source)
    local player = source ~= 0 and core:getPlayer(source)
    return player and player.citizenid or 'console'
end

local function audit(source, action, target, detail)
    MySQL.insert.await('INSERT INTO som_staff_audit (staff, action, target, detail) VALUES (?, ?, ?, ?)',
        { actor(source), action, target:sub(1, 48), detail and detail:sub(1, 200) or nil })
end

---@return string|nil resource, string|nil path, string|nil err
local function parse(resource, path)
    if type(resource) ~= 'string' or not Config.placeable[resource] then
        return nil, nil, 'unknown resource, use one of: ' .. table.concat(Config.placeableList, ', ')
    end
    if type(path) ~= 'string' or #path > 80 or not path:match('^[%w_]+[%w_%.]*%+?$') then
        return nil, nil, 'bad path, for example zones.grove.tag'
    end
    return resource, path
end

---@return string|nil kind, string|nil encoded, string|nil err
local function value(source, field, arg)
    if POINT_FIELDS[field] then
        local ped = source ~= 0 and GetPlayerPed(source) or 0
        if ped == 0 then return nil, nil, 'stand in game at the spot to place a point' end
        local c = GetEntityCoords(ped)
        return 'point', json.encode({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) })
    end
    if field == 'radius' then
        local n = tonumber(arg)
        if not n or n < 1 or n > 500 then return nil, nil, 'give a radius between 1 and 500' end
        return 'number', json.encode(n)
    end
    if field == 'enabled' then
        if arg ~= nil and arg ~= 'true' and arg ~= 'false' then return nil, nil, 'enabled takes true or false' end
        return 'bool', json.encode(arg ~= 'false')
    end
    return nil, nil, 'this field cannot be placed (use center, coords, terminal, tag, radius or enabled)'
end

lib.addCommand('place', {
    help = 'Place content: /place <resource> <path> [value]. Points use where you stand.',
    params = {
        { name = 'resource', type = 'string' },
        { name = 'path', type = 'string' },
        { name = 'value', type = 'longString', optional = true },
    },
}, function(source, args)
    if not allowed(source) then return end
    local res, path, err = parse(args.resource, args.path)
    if not res then return reply(source, err) end

    local field = path:gsub('%+$', ''):match('([%w_]+)$')
    local kind, encoded, verr = value(source, field, args.value)
    if not kind then return reply(source, verr) end

    if not path:find('%+$') then
        MySQL.update.await('DELETE FROM som_placements WHERE resource = ? AND path = ?', { res, path })
    end
    MySQL.insert.await('INSERT INTO som_placements (resource, path, kind, value, placed_by) VALUES (?, ?, ?, ?, ?)',
        { res, path, kind, encoded, actor(source) })
    audit(source, 'place', res .. ':' .. path, encoded)
    reply(source, ('Saved %s %s. Run: restart %s'):format(res, path, res))
end)

lib.addCommand('unplace', {
    help = 'Remove a placement: /unplace <resource> <path>',
    params = { { name = 'resource', type = 'string' }, { name = 'path', type = 'string' } },
}, function(source, args)
    if not allowed(source) then return end
    local res, path, err = parse(args.resource, args.path)
    if not res then return reply(source, err) end
    local n = MySQL.update.await('DELETE FROM som_placements WHERE resource = ? AND path = ?', { res, path }) or 0
    audit(source, 'unplace', res .. ':' .. path)
    reply(source, n > 0 and ('Removed. Run: restart %s'):format(res) or 'Nothing was placed there')
end)

lib.addCommand('places', {
    help = 'List placements: /places [resource]',
    params = { { name = 'resource', type = 'string', optional = true } },
}, function(source, args)
    if not allowed(source) then return end
    local rows = args.resource and MySQL.query.await('SELECT resource, path, kind, value FROM som_placements WHERE resource = ? ORDER BY resource, id LIMIT 60', { args.resource })
        or MySQL.query.await('SELECT resource, path, kind, value FROM som_placements ORDER BY resource, id LIMIT 60') or {}
    if #rows == 0 then return reply(source, 'Nothing placed yet') end
    for _, r in ipairs(rows) do print(('[som-staff] %s %s (%s) %s'):format(r.resource, r.path, r.kind, r.value)) end
    reply(source, ('%d placements, listed in the server console'):format(#rows))
end)
