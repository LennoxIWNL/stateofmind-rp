--- Fire incidents. The server owns every flame: where it burns, how much is
--- left, when it spreads and when it burns out. Clients only draw flames and
--- say "I am spraying that one"; the server checks the tool, the distance, the
--- rate and the job before it takes any hp off.

local core = exports['som-core']
local ox = exports.ox_inventory
local economy = exports['som-economy']
local C = Config

local incidents = {}
local nextIncident, nextPoint = 1, 1
local lastSpray = {}
local rescues = {}
local paidLog, drawLog = {}, {}
local truckModels = {}
for _, name in ipairs(C.trucks) do truckModels[joaat(name)] = true end

Fire = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success, out.error = ok == true, (not ok) and err or nil
    return out
end

local function now() return GetGameTimer() end

local function firefighter(source)
    local player = core:getPlayer(source)
    if not player or not player.job or player.job.name ~= C.job or not player.job.onduty then return nil end
    return player
end

local function snapshot()
    local list = {}
    for id, inc in pairs(incidents) do
        local points = {}
        for _, p in ipairs(inc.points) do points[#points + 1] = { id = p.id, x = p.coords.x, y = p.coords.y, z = p.coords.z } end
        list[#list + 1] = { id = id, points = points }
    end
    return list
end

local function sync() TriggerClientEvent('som-fire:client:sync', -1, snapshot()) end

local function newPoint(coords)
    local p = { id = nextPoint, coords = coords, hp = C.pointHp, by = {} }
    nextPoint = nextPoint + 1
    return p
end

---Starts an incident at the position. Nil and a reason when the cap is reached.
function Fire.Start(coords)
    local open = 0
    for _ in pairs(incidents) do open = open + 1 end
    if open >= C.maxIncidents then return nil, 'too many fires burning' end

    local id = nextIncident
    nextIncident = nextIncident + 1
    local t = now()
    incidents[id] = { id = id, points = { newPoint(coords) }, startedAt = t, spreadAt = t + C.spreadSeconds * 1000 }
    exports['som-dispatch']:alert(nil, 'structureFire', { coords = coords, message = 'Fire reported' })
    sync()
    return id
end

---Burns out old fires and lets young ones grow. Runs from the loop below.
function Fire.Tick()
    local changed = false
    local t = now()
    for id, inc in pairs(incidents) do
        if t - inc.startedAt > C.lifetime * 1000 then
            incidents[id] = nil
            changed = true
        elseif t >= inc.spreadAt and #inc.points < C.maxPoints then
            local from = inc.points[math.random(#inc.points)].coords
            local angle = math.random() * 2 * math.pi
            local r = C.spreadRadius.min + math.random() * (C.spreadRadius.max - C.spreadRadius.min)
            inc.points[#inc.points + 1] = newPoint(vec3(from.x + math.cos(angle) * r, from.y + math.sin(angle) * r, from.z))
            inc.spreadAt = t + C.spreadSeconds * 1000
            changed = true
        end
    end
    if changed then sync() end
end

local function nearestPoint(coords)
    local best, bestIncident, bestDist
    for _, inc in pairs(incidents) do
        for _, p in ipairs(inc.points) do
            local d = #(coords - p.coords)
            if not bestDist or d < bestDist then best, bestIncident, bestDist = p, inc, d end
        end
    end
    return best, bestIncident, bestDist
end

local function sumLast(log, key, window)
    local cutoff, keep, total = os.time() - window, {}, 0
    for _, e in ipairs(log[key] or {}) do
        if e.t > cutoff then keep[#keep + 1] = e; total = total + e.amount end
    end
    log[key] = keep
    return total
end

-- shortcut: pay and draw counts live in memory, so a restart resets them; move to a table if abuse shows.
---Tops the account up from the city budget for the shortfall, within the hourly draw cap.
local function ensureFunds(amount)
    local balance = economy:getBusinessBalance(C.business)
    if balance >= amount then return true end

    local need = amount - balance
    if sumLast(drawLog, 'all', 3600) + need > C.pay.drawCapHourly then return false end

    local entry = { t = os.time(), amount = need }
    drawLog.all[#drawLog.all + 1] = entry
    local ok, funded = pcall(function() return economy:fundFromTreasury(C.business, need) end)
    if ok and funded then return true end

    for i, e in ipairs(drawLog.all) do
        if e == entry then table.remove(drawLog.all, i) break end
    end
    return false
end

---Pays from the account: debit first, credit second, undo on failure. Nothing is minted.
local function pay(source, citizenid, amount)
    amount = math.min(amount, C.pay.hourlyCap - sumLast(paidLog, citizenid, 3600))
    if amount < 1 or not ensureFunds(amount) then return 0 end

    local ok, debited = pcall(function() return core:businessTransact(C.business, -amount, 'fire-pay') end)
    if not (ok and debited) then return 0 end

    local paid, credited = pcall(function() return core:addMoney(source, 'bank', amount, 'fire-pay') end)
    if paid and credited then
        paidLog[citizenid][#paidLog[citizenid] + 1] = { t = os.time(), amount = amount }
        return amount
    end
    local undone, restored = pcall(function() return core:businessTransact(C.business, amount, 'fire-pay:undo') end)
    if not (undone and restored) then
        print(('[som-fire] MONEY LOST: %d was taken from the %s account for %s and could not be given back'):format(amount, C.business, citizenid))
    end
    return 0
end

local function payOut(point)
    local crew = {}
    for citizenid, w in pairs(point.by) do
        if w.ticks >= C.pay.minTicks then crew[#crew + 1] = { citizenid = citizenid, source = w.source } end
    end
    if #crew == 0 then return end

    local share = math.floor(C.pay.perPoint / #crew)
    for _, w in ipairs(crew) do
        local player = core:getPlayer(w.source)
        if player and player.citizenid == w.citizenid then pay(w.source, w.citizenid, share) end
    end
end

local function canSpray(source)
    if (ox:Search(source, 'count', C.tool) or 0) >= 1 then return true end
    local ped = GetPlayerPed(source)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    return vehicle ~= 0 and truckModels[GetEntityModel(vehicle)] == true
end

lib.callback.register('som-fire:server:douse', function(source, incidentId, pointId)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local inc = math.type(incidentId) == 'integer' and incidents[incidentId]
    local point, index
    if inc and math.type(pointId) == 'integer' then
        for i, p in ipairs(inc.points) do
            if p.id == pointId then point, index = p, i end
        end
    end
    if not point then return done(false, 'that fire is out') end

    local t = now()
    if lastSpray[source] and t - lastSpray[source] < C.sprayMinMs then return done(false, 'too fast') end
    lastSpray[source] = t

    if exports['som-medical']:isDowned(source) then return done(false, 'you cannot do that now') end
    if not canSpray(source) then return done(false, 'you need an extinguisher') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - point.coords) > C.sprayDistance then return done(false, 'you are too far from the fire') end

    if firefighter(source) then
        local w = point.by[player.citizenid] or { ticks = 0 }
        w.ticks, w.source = w.ticks + 1, source
        point.by[player.citizenid] = w
    end

    point.hp = point.hp - C.sprayDamage
    if point.hp > 0 then return done(true, nil, { out = false }) end

    -- Claim the flame before anyone is paid for it.
    table.remove(inc.points, index)
    inc.spreadAt = math.max(inc.spreadAt, t + C.spreadSeconds * 1000)
    if #inc.points == 0 then incidents[inc.id] = nil end
    sync()
    payOut(point)
    return done(true, nil, { out = true })
end)

lib.callback.register('som-fire:server:state', snapshot)

local function victim(source, target)
    target = tonumber(target)
    if not target or target % 1 ~= 0 or target == source then return nil end
    if not core:getPlayer(target) or not exports['som-medical']:isDowned(target) then return nil end

    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a == 0 or b == 0 then return nil end
    local at, to = GetEntityCoords(a), GetEntityCoords(b)
    if #(at - to) > C.rescue.distance then return nil end

    local point, _, dist = nearestPoint(to)
    if not point or dist > C.rescue.fireRadius then return nil end
    return target, to, point
end

lib.callback.register('som-fire:server:rescueBegin', function(source, target)
    if not firefighter(source) then return done(false, 'you are not on duty as a firefighter') end
    if not victim(source, target) then return done(false, 'nobody here needs to be pulled out') end
    rescues[source] = { target = tonumber(target), at = now() }
    return done(true, nil, { seconds = C.rescue.seconds })
end)

lib.callback.register('som-fire:server:rescueFinish', function(source, target)
    if not firefighter(source) then return done(false, 'you are not on duty as a firefighter') end

    local run = rescues[source]
    rescues[source] = nil
    local age = run and now() - run.at
    if not run or run.target ~= tonumber(target) or age < C.rescue.seconds * 900 or age > C.rescue.staleSeconds * 1000 then
        return done(false, 'the rescue was not finished')
    end

    local id, to, point = victim(source, target)
    if not id then return done(false, 'nobody here needs to be pulled out') end

    local dx, dy = to.x - point.coords.x, to.y - point.coords.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.1 then dx, dy, len = 1.0, 0.0, 1.0 end
    TriggerClientEvent('som-fire:client:moveTo', id, to.x + dx / len * C.rescue.clear, to.y + dy / len * C.rescue.clear, to.z)
    return done(true)
end)

local function staff(source)
    return source ~= 0 and core:hasPermission(source, 'som.admin')
end

RegisterCommand('startfire', function(source)
    if not staff(source) then return end
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local _, err = Fire.Start(GetEntityCoords(ped))
    if err then TriggerClientEvent('som:client:notify', source, err, 'error') end
end, false)

RegisterCommand('stopfires', function(source)
    if not staff(source) then return end
    incidents = {}
    sync()
end, false)

CreateThread(function()
    local lastAmbient = now()
    while true do
        Wait(5000)
        if next(incidents) then Fire.Tick() end

        local a = C.ambient
        if a.enabled and #a.locations > 0 and now() - lastAmbient > a.minutes * 60000 then
            lastAmbient = now()
            if math.random() < a.chance then Fire.Start(a.locations[math.random(#a.locations)]) end
        end
    end
end)

AddEventHandler('playerDropped', function() lastSpray[source], rescues[source] = nil, nil end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    incidents, lastSpray, rescues, paidLog, drawLog = {}, {}, {}, {}, {}
end)
