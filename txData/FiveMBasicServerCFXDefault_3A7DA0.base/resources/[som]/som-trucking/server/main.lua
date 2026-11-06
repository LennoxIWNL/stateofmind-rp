--- The freight haul: a server-spawned truck and trailer, driven to a yard.
--- The server owns the vehicles, the damage read, the clock and the pay.

local core = exports['som-core']

Trucking = {}

local runs = {}
local byCitizen = {}
local cooldown = {}
local paidLog = {}
local lastCall = {}

local function limited(source)
    local now = GetGameTimer()
    if lastCall[source] and now - lastCall[source] < Config.callMs then return true end
    lastCall[source] = now
    return false
end

local function usable(route)
    return type(route) == 'table' and type(route.id) == 'string' and route.id:match('^[%w_%-]+$') ~= nil
        and type(route.label) == 'string' and route.depot and route.trailer and route.dropoff
        and type(route.base) == 'number' and route.base >= 1 and type(route.minutes) == 'number' and route.minutes > 0
        and #(vec3(route.depot.x, route.depot.y, route.depot.z) - route.dropoff) >= Config.minDistance
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

local function tell(run, goal)
    for _, source in pairs(run.members) do TriggerClientEvent('som-trucking:client:objective', source, goal) end
end

---Ends a run: vehicles go, every client is cleared. Does not free the group.
local function clear(groupId, penalise)
    local run = runs[groupId]
    if not run then return end

    runs[groupId] = nil
    remove(run.truck)
    remove(run.trailer)
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

local function spawn(model, at)
    local entity = CreateVehicle(joaat(model), at.x, at.y, at.z, at.w, true, true)
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end
    return DoesEntityExist(entity) and entity or nil
end

local function coolingDown(members)
    for _, m in ipairs(members) do
        if (cooldown[m.citizenid] or 0) > os.time() then return true end
    end
    return false
end

---@param info table som-groups group
---@param route table
---@return boolean
function Trucking.Start(info, route)
    if not usable(route) or coolingDown(info.members) then return false end

    local run = { group = info.id, route = route, members = {}, starters = {}, startedAt = os.time() }
    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            run.starters[m.citizenid] = true
            run.count = (run.count or 0) + 1
        end
    end
    if not run.count then return false end

    run.truck = spawn(Config.truckModel, route.depot)
    run.trailer = run.truck and spawn(Config.trailerModel, route.trailer)
    if not run.trailer then
        remove(run.truck)
        return false
    end

    local dist = #(vec3(route.depot.x, route.depot.y, route.depot.z) - route.dropoff)
    run.readyAt = run.startedAt + math.ceil(dist / Config.maxSpeed)
    run.dueAt = run.startedAt + route.minutes * 60
    run.expires = run.dueAt + Config.graceMinutes * 60

    runs[info.id] = run
    for cid in pairs(run.starters) do byCitizen[cid] = info.id end
    tell(run, {
        label = route.label,
        coords = route.dropoff,
        depot = vec3(route.trailer.x, route.trailer.y, route.trailer.z),
    })
    return true
end

local function settle(run, at)
    local damage = math.min(Config.maxDamage, math.max(0, (1000.0 - GetVehicleBodyHealth(run.trailer)) / 1000.0))
    local factor = (1.0 - damage) * (os.time() > run.dueAt and (1.0 - Config.latePenalty) or 1.0)
    factor = math.max(Config.floor, factor)

    local present = {}
    for cid, s in pairs(run.members) do
        local ped = GetPlayerPed(s)
        local player = core:getPlayer(s)
        if ped ~= 0 and player and player.citizenid == cid and #(GetEntityCoords(ped) - at) <= Config.shareDistance then
            present[#present + 1] = { cid = cid, source = s }
        end
    end

    local bonus = (run.count >= 2 and #present >= 2) and Config.groupBonus or 0
    local share = math.floor(run.route.base * factor * (1.0 + bonus) / math.max(1, #present))

    local total = 0
    for _, p in ipairs(present) do
        local amount = math.min(share, capLeft(p.cid))
        if amount < 1 then
            TriggerClientEvent('som:client:notify', p.source, 'You have hauled enough for this hour', 'error')
        elseif not exports['som-economy']:businessSpend(Config.business, amount, 'trucking') then
            TriggerClientEvent('som:client:notify', p.source, 'The company could not pay this haul', 'error')
        elseif core:addMoney(p.source, 'bank', amount, 'trucking') then
            local log = paidLog[p.cid]
            log[#log + 1] = { t = os.time(), amount = amount }
            total = total + amount
            TriggerClientEvent('som:client:notify', p.source, ('Delivered: $%d'):format(amount), 'success')
        else
            core:businessTransact(Config.business, amount, 'trucking:refund')
        end
    end

    return total
end

lib.callback.register('som-trucking:server:deliver', function(source)
    if limited(source) then return { success = false, error = 'slow down' } end

    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    if not run or run.members[player.citizenid] ~= source then return { success = false, error = 'you have no haul' } end
    if run.delivered then return { success = false, error = 'already handed in' } end

    local at = run.route.dropoff
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - at) > Config.interactDistance then
        return { success = false, error = 'you are too far away' }
    end

    if not run.trailer or not DoesEntityExist(run.trailer) or #(GetEntityCoords(run.trailer) - at) > Config.dropRadius then
        return { success = false, error = 'bring the trailer into the yard' }
    end

    if os.time() < run.readyAt then return { success = false, error = 'you have not driven that far yet' } end

    run.delivered = true
    local ok, total = pcall(settle, run, at)
    if not ok then
        print(('[som-trucking] payout failed: %s'):format(tostring(total)))
        finish(run.group)
        return { success = false, error = 'the payout failed, the haul is over' }
    end

    if total < 1 then
        run.delivered = false
        return { success = false, error = 'nothing could be paid' }
    end

    finish(run.group)
    return { success = true }
end)

lib.callback.register('som-trucking:server:abandon', function(source)
    if limited(source) then return { success = false, error = 'slow down' } end

    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    if not run or run.members[player.citizenid] ~= source then return { success = false, error = 'you have no haul' } end

    finish(run.group, true)
    return { success = true }
end)

function Trucking.Sweep()
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
            TriggerClientEvent('som-trucking:client:objective', source, nil)
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
    for _, run in pairs(runs) do
        remove(run.truck)
        remove(run.trailer)
    end
end)

---Offers one job board entry per usable route.
function Trucking.Register()
    for _, route in ipairs(Config.routes) do
        local ok, good = pcall(usable, route)
        if ok and good then
            exports['som-jobboard']:registerProvider({
                id = 'trucking_' .. route.id, label = route.label:sub(1, 32), summary = 'Long haul freight contract',
                minSize = 1, maxSize = Config.maxSize, slots = Config.slots,
                canStart = function(info)
                    if coolingDown(info.members) then return false, 'a crew member abandoned a haul recently' end
                    return true
                end,
                start = function(info) return Trucking.Start(info, route) end,
            })
        end
    end
end

Trucking.Register()

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Trucking.Sweep)
    end
end)
