--- Paramedic revive. The server decides everything that matters: the job and
--- duty, that the patient is really down, the distance, the minimum treatment
--- time, the kit and the bill. The client only runs the progress bar.

local core = exports['som-core']
local ox = exports.ox_inventory

local started = {}  -- [medic source] = { target, at }
local lastRevive = {} -- [patient citizenid] = GetGameTimer()

local function done(ok, err)
    return { success = ok == true, error = (not ok) and err or nil }
end

local function medic(source)
    local player = core:getPlayer(source)
    if not player or not player.job or player.job.name ~= Config.job or not player.job.onduty then return nil end
    return player
end

local function patient(source, target)
    target = tonumber(target)
    if not target or target % 1 ~= 0 or target == source then return nil end

    local player = core:getPlayer(target)
    if not player or not exports['som-medical']:isDowned(target) then return nil end

    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.distance then return nil end
    return player, target
end

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
    if not run or run.target ~= tonumber(target) or GetGameTimer() - run.at < r.seconds * 900 then
        return done(false, 'treatment was not finished')
    end

    local patientPlayer, id = patient(source, target)
    if not patientPlayer then return done(false, 'nobody here needs help') end

    if not ox:RemoveItem(source, r.item, r.count) then return done(false, ('you need %d %s'):format(r.count, r.item)) end

    if not exports['som-medical']:revive(id, source) then
        ox:AddItem(source, r.item, r.count)
        return done(false, 'nobody here needs help')
    end

    lastRevive[patientPlayer.citizenid] = GetGameTimer()
    exports['som-phone']:billCitizen(patientPlayer.citizenid, Config.business, r.price, 'Emergency treatment', {
        issuerCitizenid = player.citizenid,
        fromName = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
    })
    return done(true)
end)

AddEventHandler('playerDropped', function() started[source] = nil end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then started, lastRevive = {}, {} end
end)
