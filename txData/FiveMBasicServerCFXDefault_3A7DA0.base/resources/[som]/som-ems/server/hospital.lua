--- Ambulance transport and admission. The server tracks who is loaded where and
--- re-checks everything at the desk: the medic's duty, that the patient is still
--- down and still in that ambulance, the distances, the minimum time down, the
--- cooldown. The patient pays first (into the ems account); the medic is paid
--- from that account only after the charge went through.

local core = exports['som-core']
local medical = exports['som-medical']

local done, medic = Ems.Done, Ems.Medic

local loaded = {} -- [medic source] = { target, vehicle, cid }

local models = {}
for _, name in ipairs(Config.hospital.vehicles) do models[joaat(name)] = true end

local function open()
    local h = Config.hospital
    return h.enabled and h.desk ~= nil and h.bed ~= nil
end

-- Releases a medic's patient. Where they are put: the ambulance if it still
-- exists, else the medic, else the patient's own position (never the map origin).
-- Sent as a plain table, not a vector.
local function clear(medicSource, medicPed)
    local run = loaded[medicSource]
    loaded[medicSource] = nil
    if not run or not GetPlayerName(run.target) then return end

    local ent = DoesEntityExist(run.vehicle) and run.vehicle
        or (medicPed and medicPed ~= 0 and medicPed)
        or GetPlayerPed(run.target)
    local at = GetEntityCoords(ent)
    TriggerClientEvent('som-medical:client:carried', run.target, false, { x = at.x, y = at.y, z = at.z })
end

local function clearPatient(target)
    for source, run in pairs(loaded) do
        if run.target == target then loaded[source] = nil end
    end
end

lib.callback.register('som-ems:server:deskInfo', function(source)
    if not open() or not medic(source) then return nil end
    return { label = Config.hospital.label, coords = Config.hospital.desk }
end)

lib.callback.register('som-ems:server:inspect', function(source, target)
    if not medic(source) then return done(false, 'you are not on duty as a paramedic') end
    local player, id = Ems.Patient(source, target)
    if not player then return done(false, 'nobody here needs help') end

    local info = medical:getDownInfo(id)
    if not info then return done(false, 'nobody here needs help') end
    local result = done(true)
    result.seconds = os.time() - info.since
    result.cause = medical:getDeathClass(player.citizenid)
    return result
end)

lib.callback.register('som-ems:server:load', function(source, target, netId)
    if not medic(source) then return done(false, 'you are not on duty as a paramedic') end
    if not open() then return done(false, 'the hospital is closed') end
    local h = Config.hospital

    local player, id = Ems.Patient(source, target)
    if not player then return done(false, 'nobody here needs help') end
    if loaded[source] then return done(false, 'you already have a patient loaded') end
    for _, run in pairs(loaded) do
        if run.target == id then return done(false, 'they are already loaded') end
    end

    netId = tonumber(netId)
    if not netId or netId % 1 ~= 0 then return done(false, 'no ambulance here') end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2
        or not models[GetEntityModel(vehicle)]
        or #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(vehicle)) > h.loadDistance then
        return done(false, 'no ambulance here')
    end

    local seat
    for _, s in ipairs(h.seats) do
        if GetPedInVehicleSeat(vehicle, s) == 0 then seat = s; break end
    end
    if not seat then return done(false, 'the ambulance is full') end

    loaded[source] = { target = id, vehicle = vehicle, cid = player.citizenid }
    SetPedIntoVehicle(GetPlayerPed(id), vehicle, seat)
    TriggerClientEvent('som-medical:client:carried', id, true)
    return done(true)
end)

-- No duty check: only the medic who loaded can unload, and losing the job or
-- going off duty must not strand the patient in the seat.
lib.callback.register('som-ems:server:unload', function(source)
    if not loaded[source] then return done(false, 'nobody is loaded') end

    clear(source, GetPlayerPed(source))
    return done(true)
end)

---Takes the fee from the patient into the ems account. False when they cannot pay.
local function charge(target, fee)
    if not core:hasMoney(target, 'bank', fee) or not core:removeMoney(target, 'bank', fee, 'hospital-admission') then return false end
    local ok, credited = pcall(function() return core:businessTransact('ems', fee, 'hospital-admission') end)
    if ok and credited then return true end
    core:addMoney(target, 'bank', fee, 'hospital-admission:refund')
    return false
end

---Pays the medic from the ems account: debit first, credit second, undo on failure.
local function payMedic(source, pay)
    local ok, debited = pcall(function() return core:businessTransact('ems', -pay, 'ems-transport') end)
    if pay < 1 or not (ok and debited) then return 0 end
    local paid, credited = pcall(function() return core:addMoney(source, 'bank', pay, 'ems-transport') end)
    if paid and credited then return pay end
    core:businessTransact('ems', pay, 'ems-transport:undo')
    return 0
end

lib.callback.register('som-ems:server:admit', function(source)
    local player = medic(source)
    if not player then return done(false, 'you are not on duty as a paramedic') end
    if not open() then return done(false, 'the hospital is closed') end
    local h = Config.hospital

    local run = loaded[source]
    if not run then return done(false, 'nobody is loaded') end

    local ped, patientPed = GetPlayerPed(source), GetPlayerPed(run.target)
    local info = medical:getDownInfo(run.target)
    local patient = core:getPlayer(run.target)
    if not info or not patient or patient.citizenid ~= run.cid or patientPed == 0
        or GetVehiclePedIsIn(patientPed, false) ~= run.vehicle then
        loaded[source] = nil
        return done(false, 'the patient is no longer in the ambulance')
    end
    if #(GetEntityCoords(ped) - h.desk) > h.distance or #(GetEntityCoords(run.vehicle) - h.desk) > h.vehicleDistance then
        return done(false, 'bring the ambulance to the front desk')
    end
    if os.time() - info.since < h.minDownSeconds then return done(false, 'they only just went down, treat them first') end

    local last = Ems.Cooldown[run.cid]
    if last and GetGameTimer() - last < Config.cooldownSeconds * 1000 then return done(false, 'give them a moment') end

    -- Claim: nothing below yields before these three lines have run.
    loaded[source] = nil
    local id = run.target
    Ems.Cooldown[run.cid] = GetGameTimer()

    if not medical:revive(id, source) then return done(false, 'nobody here needs help') end

    local paid = 0
    if charge(id, h.fee) then
        -- The share is capped at 60 percent whatever the config says, so a medic never out-earns the fee.
        paid = payMedic(source, math.floor(h.fee * math.min(h.payShare, 0.6)))
    end

    TriggerClientEvent('som-ems:client:admitted', id, { x = h.bed.x, y = h.bed.y, z = h.bed.z, w = h.bed.w }, h.bedSeconds)
    local result = done(true)
    result.paid = paid
    return result
end)

AddEventHandler('som:server:playerRevived', function(source) clearPatient(source) end)

AddEventHandler('som:server:jobChanged', function(source, _, job)
    if type(job) == 'table' and job.name ~= Config.job then clear(source, GetPlayerPed(source)) end
end)

AddEventHandler('playerDropped', function()
    clear(source)
    clearPatient(source)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for source in pairs(loaded) do clear(source, GetPlayerPed(source)) end
end)

CreateThread(function() SomPlacements.Apply(Config) end)
