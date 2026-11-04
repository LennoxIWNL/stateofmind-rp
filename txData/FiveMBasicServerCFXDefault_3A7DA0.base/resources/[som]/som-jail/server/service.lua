--- Community service. The server owns every step: where the worker is, how
--- long a task took, how many are done. A task is counted by one conditional
--- UPDATE, so quick repeated requests cannot both count.

local core = exports['som-core']
local medical = exports['som-medical']
local dispatch = exports['som-dispatch']

Service = {}

-- citizenid -> { spot, at, lastSpot }. Only in-flight state, so losing it at a
-- restart just means the worker starts the task again.
local tokens = {}
local lastIssue = {}

local function fail(err) return { success = false, error = err } end

local function spotById(id)
    for _, spot in ipairs(Config.Service.spots) do
        if spot.id == id then return spot end
    end
end

---@return number
local function distanceTo(source, coords)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

---@param source number
---@return boolean
function Service.Outside(source)
    return distanceTo(source, Config.Service.zone.center) > Config.Service.zone.radius
end

---@param citizenid string
---@return table|nil
function Service.Active(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    return MySQL.single.await(
        "SELECT * FROM som_community_service WHERE citizenid = ? AND status = 'active'", { citizenid })
end

exports('serviceFor', Service.Active)

---@param targetSource number
---@param tasks any
---@param caseId number|nil
---@param issuedBy string citizenid, or 'console'
---@return boolean ok, string|nil error
function Service.Start(targetSource, tasks, caseId, issuedBy)
    local target = core:getPlayer(tonumber(targetSource))
    if not target then return false, 'they are not here' end

    tasks = math.floor(tonumber(tasks) or 0)
    if tasks < 1 or tasks > Config.Service.maxTasks then
        return false, ('between 1 and %d tasks'):format(Config.Service.maxTasks)
    end

    if Jail.ActiveFor(target.citizenid) then return false, 'they are serving a sentence' end
    if Service.Active(target.citizenid) then return false, 'they are already on community service' end

    local recorded = pcall(MySQL.insert.await, [[
        INSERT INTO som_community_service (citizenid, case_id, issued_by, tasks_total)
        VALUES (?, ?, ?, ?)
    ]], { target.citizenid, caseId, issuedBy, tasks })
    if not recorded then return false, 'could not record it' end

    Jail.Confiscate(target.source or targetSource, target.citizenid)

    TriggerClientEvent('som-jail:client:serviceStarted', targetSource, tasks)
    Jail.Log(('%s sent %s to community service: %d tasks'):format(issuedBy, target.citizenid, tasks))
    return true
end

---Ends an active job without completing it (booked into jail, or an admin).
---@param citizenid string
---@return boolean ended
function Service.Cancel(citizenid)
    local ended = MySQL.update.await(
        "UPDATE som_community_service SET status = 'cancelled' WHERE citizenid = ? AND status = 'active'",
        { citizenid }) == 1

    if ended then
        tokens[citizenid] = nil
        local online = core:getPlayerByCitizenId(citizenid)
        if online then TriggerClientEvent('som-jail:client:serviceEnded', online.source, false) end
    end

    return ended
end

local function finishService(source, row)
    local done = MySQL.update.await([[
        UPDATE som_community_service SET status = 'completed', completed_at = NOW()
        WHERE id = ? AND status = 'active' AND tasks_done >= tasks_total
    ]], { row.id }) == 1

    if not done then return false end

    tokens[row.citizenid] = nil
    Jail.ReturnProperty(source, row.citizenid)
    TriggerClientEvent('som-jail:client:serviceEnded', source, true, Config.Service.release)
    Jail.Log(('%s finished community service'):format(row.citizenid))
    return true
end

lib.callback.register('som-jail:server:svc:begin', function(source, spotId)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local row = Service.Active(player.citizenid)
    if not row then return fail('you have no community service') end

    local spot = spotById(tonumber(spotId))
    if not spot then return fail('no such spot') end

    if distanceTo(source, spot.coords) > Config.Service.range then return fail('too far away') end
    if medical:isDowned(source) then return fail('you are in no state to work') end

    local held = tokens[player.citizenid]
    if held and held.lastSpot == spot.id then return fail('do a different task next') end

    tokens[player.citizenid] = { spot = spot.id, at = GetGameTimer(), lastSpot = held and held.lastSpot }

    local kind = Config.Service.kinds[spot.kind]
    return { success = true, duration = kind.duration, scenario = kind.scenario, label = kind.label }
end)

lib.callback.register('som-jail:server:svc:finish', function(source)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local token = tokens[player.citizenid]
    if not token or not token.spot then return fail('start a task first') end

    local spot = spotById(token.spot)
    local needed = Config.Service.kinds[spot.kind].duration - Config.Service.tolerance
    if GetGameTimer() - token.at < needed then
        tokens[player.citizenid] = nil
        return fail('that was too quick')
    end

    if distanceTo(source, spot.coords) > Config.Service.range then
        tokens[player.citizenid] = nil
        return fail('you left the task')
    end

    tokens[player.citizenid] = { lastSpot = spot.id }

    local counted = MySQL.update.await([[
        UPDATE som_community_service SET tasks_done = tasks_done + 1, last_task_at = NOW()
        WHERE citizenid = ? AND status = 'active' AND tasks_done < tasks_total
          AND (last_task_at IS NULL OR last_task_at <= DATE_SUB(NOW(), INTERVAL ? SECOND))
    ]], { player.citizenid, Config.Service.minGap })
    if counted ~= 1 then return fail('too soon after the last task') end

    local row = MySQL.single.await(
        "SELECT * FROM som_community_service WHERE citizenid = ? AND status = 'active'", { player.citizenid })
    if not row then return { success = true, done = true } end

    if row.tasks_done >= row.tasks_total and finishService(source, row) then
        return { success = true, done = true }
    end

    return { success = true, remaining = row.tasks_total - row.tasks_done }
end)

---An officer hands out a small job without a court case.
---@param source number
---@param targetId any
---@param tasks any
---@param needsRange boolean
---@return boolean ok, string|nil error
function Service.IssueByOfficer(source, targetId, tasks, needsRange)
    local officer = core:getPlayer(source)
    if not officer then return false, 'not loaded' end
    if officer.job.name ~= Config.Job then return false, 'not an officer' end
    if not officer.job.onduty then return false, 'you are off duty' end

    tasks = math.floor(tonumber(tasks) or 0)
    if tasks < 1 or tasks > Config.Service.officerMaxTasks then
        return false, ('an officer can order up to %d tasks'):format(Config.Service.officerMaxTasks)
    end

    targetId = tonumber(targetId)
    if not targetId or not core:getPlayer(targetId) then return false, 'they are not here' end
    if core:getPlayer(targetId).citizenid == officer.citizenid then return false, 'not yourself' end

    if needsRange then
        local a, b = GetPlayerPed(source), GetPlayerPed(targetId)
        if not a or a == 0 or not b or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > 8.0 then
            return false, 'too far away'
        end
    end

    if os.time() - (lastIssue[officer.citizenid] or 0) < Config.BookCooldown then return false, 'slow down' end
    lastIssue[officer.citizenid] = os.time()

    return Service.Start(targetId, tasks, nil, officer.citizenid)
end

lib.callback.register('som-jail:server:svc:issue', function(source, data)
    if type(data) ~= 'table' then return fail('bad request') end

    local ok, err = Service.IssueByOfficer(source, data.target, data.tasks, true)
    return ok and { success = true } or fail(err)
end)

--- ps-mdt's profile page sends this event name and it cannot be changed. It is
--- the one legacy event here; everything behind it is validated as above.
RegisterNetEvent('qb-communityservice:server:StartCommunityService', function(targetId, sentence)
    local source = source
    local ok, err = Service.IssueByOfficer(source, targetId, sentence, false)
    if not ok then TriggerClientEvent('som:client:notify', source, err, 'error') end
end)

---Admin end. Console (source 0) or som.admin only.
---@param source number
---@param targetId any
---@return boolean ok, string|nil error
function Service.End(source, targetId)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return false, 'no permission' end

    local target = core:getPlayer(tonumber(targetId))
    if not target then return false, 'they are not here' end

    if not Service.Cancel(target.citizenid) then return false, 'they are not on community service' end

    Jail.ReturnProperty(target.source or tonumber(targetId), target.citizenid)
    return true
end

RegisterCommand('endservice', function(source, args)
    local ok, err = Service.End(source, args[1])
    local msg = ok and 'ended' or (err or 'could not end it')
    if source == 0 then print('[som-jail] ' .. msg) else TriggerClientEvent('som:client:notify', source, msg, ok and 'success' or 'error') end
end, false)

function Service.Sweep()
    local rows = MySQL.query.await("SELECT * FROM som_community_service WHERE status = 'active'") or {}

    for _, row in ipairs(rows) do
        local online = core:getPlayerByCitizenId(row.citizenid)

        if online and not medical:isDowned(online.source) and Service.Outside(online.source) then
            local penalised = MySQL.update.await([[
                UPDATE som_community_service
                SET tasks_total = LEAST(tasks_total + ?, ?), strikes = strikes + 1, last_penalty_at = NOW()
                WHERE id = ? AND status = 'active'
                  AND (last_penalty_at IS NULL OR last_penalty_at <= DATE_SUB(NOW(), INTERVAL ? SECOND))
            ]], { Config.Service.escapePenalty, Config.Service.maxTasks, row.id, Config.Service.penaltyGap }) == 1

            if penalised then
                if row.strikes + 1 >= Config.Service.maxStrikes
                    and MySQL.update.await(
                        "UPDATE som_community_service SET status = 'absconded' WHERE id = ? AND status = 'active'",
                        { row.id }) == 1 then
                    dispatch:alert(online.source, Config.AbscondAlert, {})
                    Jail.Log(('%s absconded from community service'):format(row.citizenid))
                    TriggerClientEvent('som-jail:client:serviceEnded', online.source, false)
                else
                    TriggerClientEvent('som-jail:client:serviceReturn', online.source, Config.Service.spawn)
                end
            end
        end
    end
end

CreateThread(function()
    Wait(8000)

    while true do
        Wait(15000)
        pcall(Service.Sweep)
    end
end)
