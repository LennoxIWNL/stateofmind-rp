--- Vehicle contracts as job board providers. A class is a provider, a pickup is
--- a place. The server spawns the car, owns its plate and model, and decides
--- every step: the unlock (time and distance), the one dispatch call, and the
--- delivery (that exact entity, plate, model, driven by the sender, at a drop-off).
--- The pay is marked bills from som-launder's ledger, claimed before it is minted.

local core = exports['som-core']

Boosting = {}

local runs = {}       -- by group id
local byCitizen = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function log(text)
    local url = GetConvar('som_boosting_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
end

local function usable(place)
    return place.enabled == true and place.coords ~= nil
end

local function policeOnDuty()
    return #core:getPlayersByJob('police', true)
end

local function near(source, entity, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= distance
end

local function nearCoords(source, coords, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= distance
end

local function trim(text)
    return type(text) == 'string' and text:gsub('^%s+', ''):gsub('%s+$', ''):upper() or nil
end

local function spawn(model, at, heading)
    local entity = CreateVehicle(joaat(model), at.x, at.y, at.z, heading or 0.0, true, true)
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end
    return DoesEntityExist(entity) and entity or nil
end

---A plate no player vehicle holds.
local function freePlate()
    for _ = 1, 5 do
        local plate = ('BST%05d'):format(math.random(0, 99999))
        if not MySQL.scalar.await('SELECT 1 FROM som_vehicles WHERE plate = ? LIMIT 1', { plate }) then return plate end
    end
end

-- ---------------------------------------------------------------------------
-- Run state
-- ---------------------------------------------------------------------------

local function tell(run, name, payload)
    for _, s in pairs(run.members) do TriggerClientEvent(name, s, payload) end
end

local function close(groupId, status)
    local run = runs[groupId]
    if not run then return end

    MySQL.update.await("UPDATE som_boost_runs SET status = ? WHERE id = ? AND status = 'active'", { status, run.id })
    log(('boost %s %s ended %s'):format(run.class, run.plate, status))

    if DoesEntityExist(run.entity) then DeleteEntity(run.entity) end
    tell(run, 'som-boosting:client:contract', nil)

    runs[groupId] = nil
    for cid in pairs(run.members) do byCitizen[cid] = nil end
    exports['som-jobboard']:finish(groupId)
end

local function runOf(source)
    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    return run, player
end

-- ---------------------------------------------------------------------------
-- Starting a contract
-- ---------------------------------------------------------------------------

---A free pickup: usable, not busy and not cooling down, with the class's hourly
---face value under its cap. One conditional insert claims both, so two groups
---cannot take the same place and a crowd cannot overshoot the cap.
local function claimPickup(class, info, plate, model)
    local cfg = Config.classes[class]
    local face = cfg.bills.count * cfg.bills.worth

    local candidates = {}
    for _, pickup in ipairs(Config.pickups) do
        if usable(pickup) then candidates[#candidates + 1] = pickup end
    end
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    for _, pickup in ipairs(candidates) do
        local id = MySQL.insert.await([[
            INSERT INTO som_boost_runs (class, pickup, group_id, plate, model, face)
            SELECT ?, ?, ?, ?, ?, ? FROM DUAL
            WHERE NOT EXISTS (
                SELECT 1 FROM som_boost_runs
                WHERE pickup = ? AND (status = 'active' OR created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE))
            )
            AND (
                SELECT COALESCE(SUM(face), 0) FROM som_boost_runs
                WHERE class = ? AND status <> 'failed' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
            ) + ? <= ?
        ]], { class, pickup.id, info.id, plate, model, face, pickup.id, pickup.cooldownMinutes, class, face, cfg.hourlyCap })

        if id and id > 0 then return pickup, id end
    end
end

local function start(class, info)
    local cfg = Config.classes[class]
    if not cfg.enabled or policeOnDuty() < cfg.policeMin then return false end

    local drops = {}
    for _, drop in ipairs(Config.dropoffs) do
        if usable(drop) then drops[#drops + 1] = drop end
    end
    if #drops == 0 then return false end

    local plate = freePlate()
    if not plate then return false end

    local model = cfg.models[math.random(#cfg.models)]
    local pickup, runId = claimPickup(class, info, plate, model)
    if not pickup then return false end

    local entity = spawn(model, pickup.coords, pickup.heading)
    if not entity then
        MySQL.update.await('DELETE FROM som_boost_runs WHERE id = ?', { runId })
        return false
    end

    SetVehicleNumberPlateText(entity, plate)
    SetVehicleDoorsLocked(entity, 2)

    local run = {
        id = runId, group = info.id, class = class, model = model, plate = plate, entity = entity,
        drop = drops[math.random(#drops)], stage = 'locked', members = {}, began = {},
        expires = os.time() + Config.minutes * 60,
    }

    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            byCitizen[m.citizenid] = info.id
        end
    end
    if next(run.members) == nil then
        runs[info.id] = run
        close(info.id, 'failed')
        return false
    end

    runs[info.id] = run

    -- The crew is shown a circle the car is somewhere inside, not the car.
    local angle, reach = math.random() * 2 * math.pi, math.random() * Config.searchRadius * 0.6
    tell(run, 'som-boosting:client:contract', {
        label = cfg.label, model = model:upper(), plate = plate, netId = NetworkGetNetworkIdFromEntity(entity),
        area = { x = pickup.coords.x + math.cos(angle) * reach, y = pickup.coords.y + math.sin(angle) * reach, z = pickup.coords.z },
        radius = Config.searchRadius, unlockSeconds = Config.unlockSeconds, interactDistance = Config.interactDistance,
    })

    log(('boost %s started at %s (%s %s)'):format(class, pickup.id, model, plate))
    return true
end

for class, cfg in pairs(Config.classes) do
    exports['som-jobboard']:registerProvider({
        id = 'boost_' .. class, label = cfg.label, summary = ('Needs %d on the police'):format(cfg.policeMin),
        minSize = cfg.minSize, maxSize = cfg.maxSize, slots = cfg.slots,
        canStart = function()
            if not cfg.enabled then return false, 'not taking contracts yet' end
            if policeOnDuty() < cfg.policeMin then return false, 'the city is too quiet for this' end

            local pickups, drops = false, false
            for _, p in ipairs(Config.pickups) do if usable(p) then pickups = true end end
            for _, d in ipairs(Config.dropoffs) do if usable(d) then drops = true end end
            if not (pickups and drops) then return false, 'no places are open yet' end
            return true
        end,
        start = function(info) return start(class, info) end,
    })
end

-- ---------------------------------------------------------------------------
-- The unlock
-- ---------------------------------------------------------------------------

lib.callback.register('som-boosting:server:unlock', function(source, step)
    if step ~= 'begin' and step ~= 'finish' then return done(false, 'bad request') end

    local run, player = runOf(source)
    if not run or run.stage ~= 'locked' then return done(false, 'there is nothing to open') end
    if not DoesEntityExist(run.entity) or not near(source, run.entity, Config.interactDistance) then
        return done(false, 'you are not at the car')
    end

    if step == 'begin' then
        run.began[player.citizenid] = GetGameTimer()
        return done(true)
    end

    local began = run.began[player.citizenid]
    run.began[player.citizenid] = nil
    if not began or GetGameTimer() - began < Config.unlockSeconds * 1000 then return done(false, 'you were too quick') end

    -- One claim opens the car, and the same claim is the only dispatch call.
    if MySQL.update.await("UPDATE som_boost_runs SET unlocked_at = NOW() WHERE id = ? AND status = 'active' AND unlocked_at IS NULL", { run.id }) ~= 1 then
        return done(false, 'it is already open')
    end

    run.stage = 'deliver'
    SetVehicleDoorsLocked(run.entity, 1)

    exports['som-dispatch']:alert(source, 'vehicleTheft', {
        coords = GetEntityCoords(run.entity), plate = run.plate, model = run.model,
        message = ('Vehicle theft: %s, plate %s'):format(run.model:upper(), run.plate),
    })

    tell(run, 'som-boosting:client:deliver', { coords = { x = run.drop.coords.x, y = run.drop.coords.y, z = run.drop.coords.z }, label = run.drop.label })
    return done(true)
end)

-- ---------------------------------------------------------------------------
-- The delivery and the pay
-- ---------------------------------------------------------------------------

---Deals the class's bills round robin to the crew at the drop-off. Returns the
---face value minted and whether every share arrived.
local function pay(run, deliverer)
    local cfg = Config.classes[run.class]

    local shares = {}
    for cid, src in pairs(run.members) do
        local member = core:getPlayer(src)
        if member and member.citizenid == cid and (src == deliverer or nearCoords(src, run.drop.coords, Config.shareDistance)) then
            shares[#shares + 1] = { cid = cid, source = src, worths = {} }
        end
    end
    table.sort(shares, function(a, b) return a.cid < b.cid end)
    if #shares == 0 then return 0, false end

    for i = 1, cfg.bills.count do
        local share = shares[((i - 1) % #shares) + 1]
        share.worths[#share.worths + 1] = cfg.bills.worth
    end

    local minted, complete = 0, true
    for _, share in ipairs(shares) do
        if #share.worths > 0 then
            local ok, uids = pcall(function()
                return exports['som-launder']:mintBills(share.source, share.worths, ('boost:%s'):format(run.class))
            end)
            if ok and uids then
                minted = minted + #share.worths * cfg.bills.worth
                TriggerClientEvent('som:client:notify', share.source, 'You were handed marked bills', 'success')
            else
                complete = false
                TriggerClientEvent('som:client:notify', share.source, 'You could not carry your share', 'error')
            end
        end
    end
    return minted, complete
end

lib.callback.register('som-boosting:server:deliver', function(source, netId)
    if math.type(netId) ~= 'integer' then return done(false, 'bad request') end

    local run = runOf(source)
    if not run or run.stage ~= 'deliver' then return done(false, 'there is nothing to hand over') end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or entity ~= run.entity or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return done(false, 'that is not the car')
    end
    if GetEntityModel(entity) ~= joaat(run.model) or trim(GetVehicleNumberPlateText(entity)) ~= run.plate then
        return done(false, 'that is not the car')
    end

    local ped = GetPlayerPed(source)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= entity then return done(false, 'you need to be driving it') end
    if #(GetEntityCoords(entity) - run.drop.coords) > Config.deliverDistance then return done(false, 'bring it to the drop-off') end

    -- The claim comes first, so two members handing it over cannot both be paid.
    local claimed = MySQL.update.await([[
        UPDATE som_boost_runs SET status = 'done'
        WHERE id = ? AND status = 'active' AND unlocked_at IS NOT NULL AND unlocked_at <= DATE_SUB(NOW(), INTERVAL ? SECOND)
    ]], { run.id, Config.deliverAfterSeconds })
    if claimed ~= 1 then return done(false, 'give it a few minutes before you hand it over') end

    local minted, complete = pay(run, source)
    MySQL.update.await("UPDATE som_boost_runs SET paid = ?, status = ? WHERE id = ? AND status = 'done'",
        { minted, complete and 'done' or 'unpaid', run.id })
    if not complete then log(('boost run %d paid %d of %d, some shares were not minted'):format(run.id, minted, Config.classes[run.class].bills.count * Config.classes[run.class].bills.worth)) end

    close(run.group, 'done')
    return done(true)
end)

-- ---------------------------------------------------------------------------
-- Upkeep
-- ---------------------------------------------------------------------------

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local groupId = byCitizen[citizenid]
    if not groupId then return end
    runs[groupId].members[citizenid] = nil
    byCitizen[citizenid] = nil
end)

function Boosting.Sweep()
    for groupId, run in pairs(runs) do
        if run.expires <= os.time() or not DoesEntityExist(run.entity) then close(groupId, 'failed') end
    end
end

-- A restart ends every run, so none may keep a pickup claimed as active.
CreateThread(function()
    MySQL.update.await("UPDATE som_boost_runs SET status = 'failed' WHERE status = 'active'")
end)

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Boosting.Sweep)
    end
end)

CreateThread(function() SomPlacements.Apply(Config) end)
