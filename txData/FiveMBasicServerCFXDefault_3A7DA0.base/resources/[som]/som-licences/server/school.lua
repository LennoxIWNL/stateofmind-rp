local core = exports['som-core']

local theory = {}     -- citizenid -> { source, order, i, right, startedAt }
local passed = {}     -- citizenid -> game ms the theory pass stops counting
local practical = {}  -- citizenid -> session

local function now() return GetGameTimer() end

local function usable()
    local s = Config.school
    return s.enabled and s.coords and s.spawn and #Config.practical.route > 0
end

local function nearSchool(source)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - Config.school.coords) <= Config.school.radius + 5.0
end

local function treasury(amount, reason) return core:taxToTreasury(amount, reason) end

local function record(citizenid, kind, ok, score)
    MySQL.insert.await('INSERT INTO som_licence_attempts (citizenid, kind, passed, score) VALUES (?, ?, ?, ?)',
        { citizenid, kind, ok and 1 or 0, score or 0 })
end

local function question(t)
    local q = Questions[t.order[t.i]]
    return { n = t.i, total = #t.order, text = q.q, options = q.o }
end

lib.callback.register('som-licences:server:beginTheory', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end
    if not usable() then return { success = false, error = 'the driving school is closed' } end
    if not nearSchool(source) then return { success = false, error = 'too far away' } end

    local cid = player.citizenid
    local old = theory[cid]
    if old and now() - old.startedAt > Config.theory.maxMinutes * 60000 then
        theory[cid] = nil
        record(cid, 'theory', false, old.right)
        old = nil
    end
    if old or practical[cid] then return { success = false, error = 'you are already taking a test' } end
    if Licences.Status(cid).driver then return { success = false, error = 'you already hold or have lost a licence' } end
    if not core:hasMoney(source, 'bank', Config.school.fee) then
        return { success = false, error = ('the licence costs $%d, in your bank'):format(Config.school.fee) }
    end

    local recent = MySQL.scalar.await([[
        SELECT COUNT(*) FROM som_licence_attempts
        WHERE citizenid = ? AND kind = 'theory' AND passed = 0
          AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { cid, Config.theory.retryMinutes })
    if (recent or 0) > 0 then
        return { success = false, error = ('wait %d minutes after a failed test'):format(Config.theory.retryMinutes) }
    end

    local pool = {}
    for i = 1, #Questions do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local order = {}
    for i = 1, math.min(Config.theory.questions, #pool) do order[i] = pool[i] end

    local t = { source = source, order = order, i = 1, right = 0, startedAt = now() }
    theory[cid] = t
    return { success = true, question = question(t) }
end)

lib.callback.register('som-licences:server:answer', function(source, choice)
    local player = core:getPlayer(source)
    local t = player and theory[player.citizenid]
    if not t then return { success = false, error = 'no test in progress' } end

    local q = Questions[t.order[t.i]]
    if math.type(choice) ~= 'integer' or choice < 1 or choice > #q.o then return { success = false, error = 'bad answer' } end

    if now() - t.startedAt > Config.theory.maxMinutes * 60000 then
        theory[player.citizenid] = nil
        record(player.citizenid, 'theory', false, t.right)
        return { success = true, done = true, passed = false, score = t.right, total = #t.order }
    end

    if choice == q.answer then t.right = t.right + 1 end
    t.i = t.i + 1

    if t.i <= #t.order then return { success = true, question = question(t) } end

    theory[player.citizenid] = nil
    local ok = t.right >= Config.theory.pass
    record(player.citizenid, 'theory', ok, t.right)
    if ok then passed[player.citizenid] = now() + Config.theory.practicalWindowMinutes * 60000 end

    return { success = true, done = true, passed = ok, score = t.right, total = #t.order }
end)

local function endPractical(cid, ok, reason)
    local s = practical[cid]
    if not s then return end
    practical[cid] = nil

    if s.entity and DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
    TriggerClientEvent('som-licences:client:practical', s.source, nil)
    record(cid, 'practical', ok, s.faults)

    if not ok then
        TriggerClientEvent('som:client:notify', s.source, reason or 'You failed the driving test', 'error')
        return
    end

    local done, err = Licences.Issue(s.source, 'driver', Config.school.fee, treasury)
    TriggerClientEvent('som:client:notify', s.source, done and 'You passed. Your driver licence has been issued' or err, done and 'success' or 'error')
end

lib.callback.register('som-licences:server:startPractical', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end
    local cid = player.citizenid

    if not usable() then return { success = false, error = 'the driving school is closed' } end
    if practical[cid] then return { success = false, error = 'you are already driving' } end
    if not passed[cid] or passed[cid] < now() then return { success = false, error = 'pass the theory test first' } end
    if not nearSchool(source) then return { success = false, error = 'too far away' } end

    passed[cid] = nil

    local sp = Config.school.spawn
    local entity = CreateVehicle(joaat(Config.school.model), sp.x, sp.y, sp.z, sp.w, true, true)
    local deadline = now() + 5000
    while not DoesEntityExist(entity) and now() < deadline do Wait(0) end
    if not DoesEntityExist(entity) then return { success = false, error = 'the school car could not be brought round' } end

    SetVehicleNumberPlateText(entity, Config.school.plate)
    -- Locked to everyone; the client seats the test taker directly, which ignores locks.
    SetVehicleDoorsLocked(entity, 2)

    local s = {
        source = source, entity = entity, index = 1, faults = 0,
        startedAt = now(), prevAt = now(), prevPos = vec3(sp.x, sp.y, sp.z),
        lastBody = 1000.0, lastFault = 0,
    }
    practical[cid] = s

    TriggerClientEvent('som-licences:client:practical', source, {
        netId = NetworkGetNetworkIdFromEntity(entity), checkpoint = Config.practical.route[1],
    })
    return { success = true }
end)

local function fault(s, text)
    s.faults = s.faults + 1
    s.lastFault = now()
    TriggerClientEvent('som:client:notify', s.source, ('%s (fault %d of %d)'):format(text, s.faults, Config.practical.maxFaults), 'error')
end

local function tick(cid, s)
    local P = Config.practical
    local ped = GetPlayerPed(s.source)
    if ped == 0 or not core:getPlayer(s.source) then return endPractical(cid, false) end
    if now() - s.startedAt > P.maxMinutes * 60000 then return endPractical(cid, false, 'You ran out of time') end

    if GetVehiclePedIsIn(ped, false) ~= s.entity then
        s.outSince = s.outSince or now()
        if now() - s.outSince > P.leaveGraceSeconds * 1000 then return endPractical(cid, false, 'You left the school car') end
        return
    end
    s.outSince = nil

    if GetEntitySpeed(s.entity) * 3.6 > P.speedLimit and now() - s.lastFault > 3000 then fault(s, 'Too fast') end

    local body = GetVehicleBodyHealth(s.entity)
    if body < s.lastBody - P.damageStep then fault(s, 'You hit something') end
    s.lastBody = body

    if s.faults > P.maxFaults then return endPractical(cid, false, 'Too many faults') end

    local target = P.route[s.index]
    local minMs = #(target - s.prevPos) / P.maxSpeed * 1000
    if #(GetEntityCoords(ped) - target) > P.radius or now() - s.prevAt < minMs then return end

    s.prevAt, s.prevPos, s.index = now(), target, s.index + 1
    if s.index > #P.route then return endPractical(cid, true) end
    TriggerClientEvent('som-licences:client:practical', s.source, { checkpoint = P.route[s.index] })
end

CreateThread(function()
    while true do
        Wait(1000)
        local ids = {}
        for cid in pairs(practical) do ids[#ids + 1] = cid end
        for _, cid in ipairs(ids) do
            local s = practical[cid]
            if s then
                local ok, err = pcall(tick, cid, s)
                if not ok then print(('[som-licences] drive check failed for %s: %s'):format(cid, err)) end
            end
        end
    end
end)

local function drop(citizenid)
    local t = theory[citizenid]
    if t then record(citizenid, 'theory', false, t.right) end
    theory[citizenid] = nil
    passed[citizenid] = nil
    endPractical(citizenid, false)
end

AddEventHandler('som:server:playerUnloaded', function(_, citizenid) drop(citizenid) end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for cid in pairs(practical) do endPractical(cid, false) end
end)
