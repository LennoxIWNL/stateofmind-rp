--- The courier run: collect parcels at a pickup, deliver to a few drops.
--- The server owns the stage, the position check and the pay; the client only
--- shows where to go and asks to interact.

local core = exports['som-core']

Courier = {}

local runs = {}
local byCitizen = {}
local paidLog = {}

-- shortcut: the hourly cap lives in memory, so a restart resets it; upgrade to a table if abuse shows.
local function capLeft(citizenid)
    local cutoff, used, keep = os.time() - 3600, 0, {}
    for _, e in ipairs(paidLog[citizenid] or {}) do
        if e.t > cutoff then keep[#keep + 1] = e; used = used + e.amount end
    end
    paidLog[citizenid] = keep
    return math.max(0, Config.hourlyCap - used)
end

local function objective(run)
    if run.stage == 'pickup' then
        return { kind = 'pickup', coords = run.route.pickup, label = run.route.label .. ' pickup' }
    end

    return { kind = 'drop', coords = run.route.drops[run.drops[run.done + 1]], label = ('Drop %d of %d'):format(run.done + 1, #run.drops) }
end

local function sendObjective(run, source)
    local targets = source and { source } or {}
    if not source then
        for _, m in ipairs(exports['som-groups']:getGroupById(run.group).members) do targets[#targets + 1] = m.source end
    end

    for _, s in ipairs(targets) do
        if s then TriggerClientEvent('som-courier:client:objective', s, objective(run)) end
    end
end

local function clear(groupId)
    local run = runs[groupId]
    if not run then return end

    runs[groupId] = nil
    for cid, source in pairs(run.members) do
        byCitizen[cid] = nil
        TriggerClientEvent('som-courier:client:objective', source, nil)
    end
end

local function finish(groupId)
    clear(groupId)
    exports['som-jobboard']:finish(groupId)
end

---Pays each present member from the business: debit first, credit second, and
---a failed credit returns the money.
local function pay(run, at)
    local present = {}
    for cid, source in pairs(run.members) do
        local ped = GetPlayerPed(source)
        if ped ~= 0 and #(GetEntityCoords(ped) - at) <= Config.shareDistance and core:getPlayer(source) then
            present[#present + 1] = { cid = cid, source = source }
        end
    end

    for _, p in ipairs(present) do
        local amount = math.min(Config.payPerDrop, capLeft(p.cid))
        if amount < 1 then
            TriggerClientEvent('som:client:notify', p.source, 'You have delivered enough for this hour', 'error')
        elseif not exports['som-economy']:businessSpend(Config.business, amount, 'courier') then
            TriggerClientEvent('som:client:notify', p.source, 'The company could not pay this drop', 'error')
        elseif core:addMoney(p.source, 'bank', amount, 'courier') then
            local log = paidLog[p.cid]
            log[#log + 1] = { t = os.time(), amount = amount }
            TriggerClientEvent('som:client:notify', p.source, ('Delivered: $%d'):format(amount), 'success')
        else
            core:businessTransact(Config.business, amount, 'courier:refund')
        end
    end
end

---@param info table som-groups group
---@return boolean
function Courier.Start(info)
    local usable = {}
    for _, route in ipairs(Config.routes) do
        if route.pickup and type(route.drops) == 'table' and #route.drops > 0 then usable[#usable + 1] = route end
    end
    if #usable == 0 then return false end

    local route = usable[math.random(#usable)]

    local order = {}
    for i = 1, #route.drops do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    local drops = {}
    for i = 1, math.min(Config.dropsPerRun, #order) do drops[i] = order[i] end

    local run = { group = info.id, route = route, stage = 'pickup', drops = drops, done = 0, members = {}, expires = os.time() + Config.minutes * 60 }
    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            byCitizen[m.citizenid] = info.id
        end
    end

    runs[info.id] = run
    sendObjective(run)
    return true
end

lib.callback.register('som-courier:server:interact', function(source, kind)
    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    if not run then return { success = false, error = 'you have no delivery' } end
    if kind ~= 'pickup' and kind ~= 'drop' then return { success = false, error = 'bad request' } end

    local goal = objective(run)
    if goal.kind ~= kind then return { success = false, error = 'not yet' } end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - goal.coords) > Config.interactDistance then
        return { success = false, error = 'you are too far away' }
    end

    if kind == 'pickup' then
        run.stage = 'drops'
        sendObjective(run)
        return { success = true }
    end

    run.done = run.done + 1
    pay(run, goal.coords)

    if run.done >= #run.drops then
        finish(run.group)
    else
        sendObjective(run)
    end

    return { success = true }
end)

---Ends runs that ran out of time. Pay was already made drop by drop.
function Courier.Sweep()
    for groupId, run in pairs(runs) do
        if run.expires <= os.time() then finish(groupId) end
    end
end

AddEventHandler('som-groups:server:changed', function(groupId)
    local run = runs[groupId]
    if not run then return end

    local info = exports['som-groups']:getGroupById(groupId)
    if not info then return clear(groupId) end

    local still = {}
    for _, m in ipairs(info.members) do still[m.citizenid] = true end

    for cid, source in pairs(run.members) do
        if not still[cid] then
            run.members[cid] = nil
            byCitizen[cid] = nil
            TriggerClientEvent('som-courier:client:objective', source, nil)
        end
    end
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local groupId = byCitizen[citizenid]
    if not groupId then return end
    runs[groupId].members[citizenid] = nil
    byCitizen[citizenid] = nil
end)

exports['som-jobboard']:registerProvider({
    id = 'courier', label = 'Courier run', summary = 'Deliver parcels around the city',
    minSize = 1, maxSize = Config.maxSize, slots = Config.slots,
    canStart = function()
        for _, route in ipairs(Config.routes) do
            if route.pickup and type(route.drops) == 'table' and #route.drops > 0 then return true end
        end
        return false, 'no routes are open yet'
    end,
    start = Courier.Start,
})

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Courier.Sweep)
    end
end)
