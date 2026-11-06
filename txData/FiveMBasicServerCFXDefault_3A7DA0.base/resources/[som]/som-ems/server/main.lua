--- Paramedic revive. The server decides everything that matters: the job and
--- duty, that the patient is really down, the distance, the minimum treatment
--- time, the kit and the bill. The client only runs the progress bar.

local core = exports['som-core']
local ox = exports.ox_inventory

local started = {}  -- [medic source] = { target, at }
local lastRevive = {} -- [patient citizenid] = GetGameTimer()
local taking = {}

local function done(ok, err)
    return { success = ok == true, error = (not ok) and err or nil }
end

local function medic(source)
    local player = core:getPlayer(source)
    if not player or not player.job or player.job.name ~= Config.job or not player.job.onduty then return nil end
    return player
end

Ems = { Medic = medic, Done = done, Cooldown = lastRevive }

local function patient(source, target)
    target = tonumber(target)
    if not target or target % 1 ~= 0 or target == source then return nil end

    local player = core:getPlayer(target)
    if not player or not exports['som-medical']:isDowned(target) then return nil end

    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.distance then return nil end
    return player, target
end

Ems.Patient = patient

lib.callback.register('som-ems:server:begin', function(source, target)
    if not medic(source) then return done(false, 'you are not on duty as a paramedic') end
    local player, id = patient(source, target)
    if not player then return done(false, 'nobody here needs help') end

    local last = lastRevive[player.citizenid]
    if last and GetGameTimer() - last < Config.cooldownSeconds * 1000 then return done(false, 'give them a moment') end

    started[source] = { target = id, at = GetGameTimer() }
    return done(true)
end)

lib.callback.register('som-ems:server:revive', function(source, target)
    local player = medic(source)
    if not player then return done(false, 'you are not on duty as a paramedic') end

    local run = started[source]
    started[source] = nil
    local r = Config.revive
    local age = run and GetGameTimer() - run.at
    if not run or run.target ~= tonumber(target) or age < r.seconds * 900 or age > Config.staleSeconds * 1000 then
        return done(false, 'treatment was not finished')
    end

    local patientPlayer, id = patient(source, target)
    if not patientPlayer then return done(false, 'nobody here needs help') end

    if not ox:RemoveItem(source, r.item, r.count) then return done(false, ('you need %d %s'):format(r.count, r.item)) end

    if not exports['som-medical']:revive(id, source) then
        ox:AddItem(source, r.item, r.count)
        return done(false, 'nobody here needs help')
    end

    local now = GetGameTimer()
    for cid, at in pairs(lastRevive) do
        if now - at > Config.cooldownSeconds * 1000 then lastRevive[cid] = nil end
    end
    lastRevive[patientPlayer.citizenid] = now
    exports['som-phone']:billCitizen(patientPlayer.citizenid, Config.business, r.price, 'Emergency treatment', {
        issuerCitizenid = player.citizenid,
        fromName = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
    })
    return done(true)
end)

local function lockerOpen()
    return Config.locker.enabled and Config.locker.coords ~= nil
end

lib.callback.register('som-ems:server:lockerInfo', function(source)
    if not lockerOpen() or not medic(source) then return nil end
    local l = Config.locker
    return { label = l.label, coords = l.coords }
end)

lib.callback.register('som-ems:server:lockerTake', function(source)
    if not medic(source) then return done(false, 'you are not on duty as a paramedic') end
    if not lockerOpen() then return done(false, 'the locker is closed') end
    if taking[source] then return done(false, 'one moment') end

    local l = Config.locker
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - l.coords) > l.distance then return done(false, 'you are too far away') end

    taking[source] = true
    local ok, err = pcall(function()
        if (ox:Search(source, 'count', l.item) or 0) >= l.max then error('you already carry enough', 0) end
        local issued, why = exports['som-economy']:issueEquipment(source, Config.business, l.item)
        if not issued then error(why or 'not available', 0) end
        if not ox:AddItem(source, l.item, 1) then error('you cannot carry it', 0) end
    end)
    taking[source] = nil
    if not ok then return done(false, tostring(err)) end
    return done(true)
end)

AddEventHandler('playerDropped', function() started[source] = nil; taking[source] = nil end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then started, lastRevive, taking = {}, {}, {} end
end)

