--- The garbage round: a server-spawned truck, bins on stops, two dump points.
--- The server owns the truck, the bin list, the count, the sort and the pay.

local core = exports['som-core']
local economy = exports['som-economy']

Garbage = {}

local runs = {}
local byCitizen = {}
local cooldown = {}
local paidLog = {}
local lastCall = {}
local funding = false

local KINDS = { general = true, recycle = true }

local function limited(source)
    local now = GetGameTimer()
    if lastCall[source] and now - lastCall[source] < Config.callMs then return true end
    lastCall[source] = now
    return false
end

---True for a real position: vector arithmetic throws on anything else.
local function isVec(p)
    return p ~= nil and pcall(function() return #(vec3(0, 0, 0) - p) end)
end

local function usable(route)
    if type(route) ~= 'table' or not route.depot or not isVec(route.dump) or not isVec(route.recycle) then return false end
    if type(route.stops) ~= 'table' or #route.stops < 1 then return false end

    local seen, total = {}, 0
    for _, stop in ipairs(route.stops) do
        if type(stop.label) ~= 'string' or not isVec(stop.coords) or type(stop.bins) ~= 'table' or #stop.bins < 1 then return false end
        for _, bin in ipairs(stop.bins) do
            if type(bin.id) ~= 'string' or not bin.id:match('^[%w_%-]+$') or seen[bin.id] or not KINDS[bin.kind] or not isVec(bin.coords) then
                return false
            end
            seen[bin.id] = true
            total = total + 1
        end
    end

    route.total = total
    return true
end

local function usableRoutes()
    local out = {}
    for _, route in ipairs(Config.routes) do
        local ok, good = pcall(usable, route)
        if ok and good then out[#out + 1] = route end
    end
    return out
end

-- shortcut: the hourly cap lives in memory, so a restart resets it; upgrade to a table if abuse shows.
local function capLeft(citizenid)
    local cutoff, used, keep = os.time() - 3600, 0, {}
    for _, e in ipairs(paidLog[citizenid] or {}) do
        if e.t > cutoff then keep[#keep + 1] = e; used = used + e.amount end
    end
    paidLog[citizenid] = keep
    return math.max(0, Config.hourlyCap - used)
end

local function remove(entity)
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function bays(run)
    local out = {}
    for _, kind in ipairs({ 'general', 'recycle' }) do
        if run[kind] > 0 and not run.dumped[kind] then
            out[#out + 1] = { kind = kind, coords = kind == 'general' and run.route.dump or run.route.recycle }
        end
    end
    return out
end

local function objective(run)
    local stop = run.route.stops[run.stop]
    if stop then
        local bins = {}
        for _, bin in ipairs(stop.bins) do
            if not run.taken[bin.id] then bins[#bins + 1] = { id = bin.id, kind = bin.kind, coords = bin.coords } end
        end
        return { kind = 'stop', label = stop.label, coords = stop.coords, bins = bins }
    end

    return { kind = 'dump', label = 'Tip the load', bays = bays(run) }
end

local function tell(run, goal)
    for _, source in pairs(run.members) do TriggerClientEvent('som-garbage:client:objective', source, goal) end
end

local function clear(groupId, penalise)
    local run = runs[groupId]
    if not run then return end

    runs[groupId] = nil
    remove(run.truck)
    tell(run, nil)

    for cid in pairs(run.starters) do
        byCitizen[cid] = nil
        if penalise then cooldown[cid] = os.time() + Config.abandonCooldown end
    end
end

local function finish(groupId, penalise)
    clear(groupId, penalise)
    exports['som-jobboard']:finish(groupId)
end

local function coolingDown(members)
    for _, m in ipairs(members) do
        if (cooldown[m.citizenid] or 0) > os.time() then return true end
    end
    return false
end

---What the department could pay right now: its balance plus what the city
---budget may still add this month, never more than the treasury holds.
local function available()
    local left = Config.monthlyBudget - (MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM som_transactions WHERE citizenid IS NULL AND reason = ? AND created_at > NOW() - INTERVAL 30 DAY',
        { 'budget:' .. Config.business }) or 0)
    return economy:getBusinessBalance(Config.business) + math.max(0, math.min(left, core:getTreasury())), left
end

local function maxPool(route)
    return route.total * (Config.payPerBag + Config.recycleBonus)
end

---Tops the department up from the city budget only if it is short, only within
---the monthly cap, and only with the whole shortfall. One lock covers the cap
---read and the draw so two payouts cannot both spend the same headroom.
local function ensureFunds(amount)
    while funding do Wait(50) end
    funding = true

    local ok, result = pcall(function()
        local balance = economy:getBusinessBalance(Config.business)
        if balance >= amount then return true end

        local _, left = available()
        local need = amount - balance
        if need > left or not economy:fundFromTreasury(Config.business, need) then return false end
        return economy:getBusinessBalance(Config.business) >= amount
    end)

    funding = false
    return ok and result == true
end

local function spawn(model, at)
    local entity = CreateVehicle(joaat(model), at.x, at.y, at.z, at.w, true, true)
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end
    return DoesEntityExist(entity) and entity or nil
end

---@param info table som-groups group
---@return boolean
function Garbage.Start(info)
    local routes = usableRoutes()
    if #routes == 0 or coolingDown(info.members) or not economy:getBusiness(Config.business) then return false end

    local route = routes[math.random(#routes)]
    if available() < maxPool(route) then return false end

    local run = { group = info.id, route = route, members = {}, starters = {}, stop = 1, taken = {}, general = 0, recycle = 0, dumped = {}, picked = {} }
    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            run.starters[m.citizenid] = true
        end
    end
    if next(run.members) == nil then return false end

    run.truck = spawn(Config.truckModel, route.depot)
    if not run.truck then return false end

    run.startedAt = os.time()
    run.readyAt = run.startedAt + route.total * Config.minBagSeconds
    run.expires = run.startedAt + Config.minutes * 60 + Config.graceMinutes * 60

    runs[info.id] = run
    for cid in pairs(run.starters) do byCitizen[cid] = info.id end
    tell(run, objective(run))
    return true
end

local function memberRun(source)
    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    if run and run.members[player.citizenid] == source then return run, player end
end

local function near(source, at, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - at) <= distance
end

local function truckNear(run, at, distance)
    return run.truck and DoesEntityExist(run.truck) and #(GetEntityCoords(run.truck) - at) <= distance
end

lib.callback.register('som-garbage:server:bag', function(source, binId, choice)
    if type(binId) ~= 'string' or not KINDS[choice] then return { success = false, error = 'bad request' } end
    if limited(source) then return { success = false, error = 'slow down' } end

    local run = memberRun(source)
    if not run then return { success = false, error = 'you have no round' } end

    local stop = run.route.stops[run.stop]
    if not stop then return { success = false, error = 'the round is loaded, tip it' } end

    local bin
    for _, b in ipairs(stop.bins) do
        if b.id == binId then bin = b break end
    end
    if not bin then return { success = false, error = 'that is not a bin on this stop' } end
    if run.taken[bin.id] then return { success = false, error = 'already emptied' } end

    if not near(source, bin.coords, Config.binDistance) then return { success = false, error = 'you are too far from the bin' } end
    if not truckNear(run, bin.coords, Config.truckRange) then return { success = false, error = 'bring the truck closer' } end

    local now = GetGameTimer()
    if run.picked[source] and now - run.picked[source] < Config.minBagSeconds * 1000 then
        return { success = false, error = 'slow down' }
    end

    run.taken[bin.id] = true
    run.picked[source] = now

    local sorted = choice == bin.kind
    if sorted and bin.kind == 'recycle' then run.recycle = run.recycle + 1 else run.general = run.general + 1 end

    local done = true
    for _, b in ipairs(stop.bins) do
        if not run.taken[b.id] then done = false end
    end
    if done then run.stop = run.stop + 1 end
    tell(run, objective(run))

    return { success = true, sorted = sorted }
end)

local function settle(run, at, pool)
    local present = {}
    for cid, s in pairs(run.members) do
        local player = core:getPlayer(s)
        if player and player.citizenid == cid and near(s, at, Config.shareDistance) then
            present[#present + 1] = { cid = cid, source = s }
        end
    end
    if #present == 0 then return 0 end

    local share = math.floor(pool / #present)
    local total = 0
    for _, p in ipairs(present) do
        local amount = math.min(share, capLeft(p.cid))
        if amount < 1 then
            TriggerClientEvent('som:client:notify', p.source, 'You have worked enough for this hour', 'error')
        elseif not ensureFunds(amount) or not economy:businessSpend(Config.business, amount, 'garbage') then
            TriggerClientEvent('som:client:notify', p.source, 'The city cannot pay this round right now', 'error')
        elseif core:addMoney(p.source, 'bank', amount, 'garbage') then
            local log = paidLog[p.cid]
            log[#log + 1] = { t = os.time(), amount = amount }
            total = total + amount
            TriggerClientEvent('som:client:notify', p.source, ('Paid: $%d'):format(amount), 'success')
        else
            core:businessTransact(Config.business, amount, 'garbage:refund')
        end
    end

    return total
end

lib.callback.register('som-garbage:server:tip', function(source, kind)
    if not KINDS[kind] then return { success = false, error = 'bad request' } end
    if limited(source) then return { success = false, error = 'slow down' } end

    local run = memberRun(source)
    if not run then return { success = false, error = 'you have no round' } end
    if run.route.stops[run.stop] then return { success = false, error = 'finish the stops first' } end
    if run.dumped[kind] then return { success = false, error = 'already tipped' } end
    if run[kind] < 1 then return { success = false, error = 'nothing of that kind on the truck' } end

    local at = kind == 'general' and run.route.dump or run.route.recycle
    if not near(source, at, Config.interactDistance) then return { success = false, error = 'you are too far away' } end
    if not truckNear(run, at, Config.dumpRadius) then return { success = false, error = 'bring the truck in' } end
    if os.time() < run.readyAt then return { success = false, error = 'that load is not ready yet' } end

    run.dumped[kind] = true
    local pool = run[kind] * (Config.payPerBag + (kind == 'recycle' and Config.recycleBonus or 0))
    local ok, total = pcall(settle, run, at, pool)
    if not ok then
        print(('[som-garbage] payout failed: %s'):format(tostring(total)))
        finish(run.group)
        return { success = false, error = 'the payout failed, the round is over' }
    end

    if total < 1 then
        run.dumped[kind] = false
        return { success = false, error = 'nothing could be paid' }
    end

    if #bays(run) == 0 then finish(run.group) else tell(run, objective(run)) end
    return { success = true }
end)

lib.callback.register('som-garbage:server:abandon', function(source)
    if limited(source) then return { success = false, error = 'slow down' } end

    local run = memberRun(source)
    if not run then return { success = false, error = 'you have no round' } end

    finish(run.group, true)
    return { success = true }
end)

function Garbage.Sweep()
    for groupId, run in pairs(runs) do
        if run.expires <= os.time() or next(run.members) == nil then finish(groupId, true) end
    end
end

AddEventHandler('som-groups:server:changed', function(groupId)
    local run = runs[groupId]
    if not run then return end

    local info = exports['som-groups']:getGroupById(groupId)
    if not info then return clear(groupId, true) end

    local still = {}
    for _, m in ipairs(info.members) do still[m.citizenid] = true end

    for cid, source in pairs(run.members) do
        if not still[cid] then
            run.members[cid] = nil
            TriggerClientEvent('som-garbage:client:objective', source, nil)
        end
    end

    if next(run.members) == nil then finish(groupId, true) end
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local run = runs[byCitizen[citizenid] or -1]
    if not run then return end

    run.members[citizenid] = nil
    if next(run.members) == nil then finish(run.group, true) end
end)

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, run in pairs(runs) do remove(run.truck) end
end)

exports['som-jobboard']:registerProvider({
    id = 'garbage', label = 'Garbage round', summary = 'Collect and recycle the city rubbish',
    minSize = 1, maxSize = Config.maxSize, slots = Config.slots,
    canStart = function(info)
        local routes = usableRoutes()
        if #routes == 0 then return false, 'no rounds are open yet' end
        if not economy:getBusiness(Config.business) then return false, 'the sanitation department is not set up' end
        if coolingDown(info.members) then return false, 'a crew member abandoned a round recently' end

        local cheapest = math.huge
        for _, route in ipairs(routes) do cheapest = math.min(cheapest, maxPool(route)) end
        if available() < cheapest then return false, 'the city cannot fund a round right now' end
        return true
    end,
    start = Garbage.Start,
})

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Garbage.Sweep)
    end
end)
