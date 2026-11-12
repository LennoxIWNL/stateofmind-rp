--- Read only phone view of who holds what and what the street pays. It has
--- no actions: seeing prices is information, not a score.

local core = exports['som-core']
local Gangs = core:getGangs()

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function zoneState(z, r)
    local owner = r and r.owner_gang
    if not owner then return 'Nobody holds it' end
    local label = Gangs[owner] and Gangs[owner].label or owner
    if r.contested_by then
        return ('%s, contested by %s'):format(label, Gangs[r.contested_by] and Gangs[r.contested_by].label or r.contested_by)
    end
    return label
end

local function view(player)
    local sections = {}

    local rows = {}
    for _, z in ipairs(Config.zones) do
        if Turf.Usable(z) then
            local r = MySQL.single.await(
                'SELECT name, owner_gang, contested_by FROM som_turf WHERE name = ?', { z.name })
            rows[#rows + 1] = { title = z.label, sub = zoneState(z, r) }
        end
    end
    sections[#sections + 1] = { title = 'Turf', rows = rows }

    if player.gang.name ~= 'none' then
        local prices = {}
        for item, d in pairs(Config.drugs) do
            prices[#prices + 1] = { title = d.label, sub = ('$%d'):format(math.floor(Turf.Price(item))), item = item }
        end
        table.sort(prices, function(a, b) return a.item < b.item end)
        for _, p in ipairs(prices) do p.item = nil end
        sections[#sections + 1] = { title = 'Street prices', rows = prices }

        local recent = {}
        for _, e in ipairs(MySQL.query.await([[
            SELECT t.label, e.action FROM som_turf_events e JOIN som_turf t ON t.id = e.turf_id
            WHERE e.gang = ? AND e.action <> 'sale' ORDER BY e.id DESC LIMIT 8
        ]], { player.gang.name }) or {}) do
            recent[#recent + 1] = { title = e.label, sub = e.action }
        end
        sections[#sections + 1] = { title = 'Your gang lately', rows = recent }
    end

    return { sections = sections, empty = 'No turf is open yet' }
end

exports['som-phone']:registerApp({
    id = 'turf', label = 'Turf', icon = 'briefcase', colour = '#bf5af2', order = 66,
    reads = { view = true },
    handler = function(source, action)
        local player = core:getPlayer(source)
        if action ~= 'view' or not player then return done(false, 'not available') end
        return done(true, nil, { view = view(player) })
    end,
})
