--- Records a disconnect while a scene was on the character, for staff to judge.
--- Nothing here punishes anyone: the row says which signals fired and the staff
--- member decides (a crash looks like a quit).

local core = exports['som-core']
local C = Config.combatLog

local lastRow, reasons = {}, {}
local CRIME = { shotsFired = true, driveBy = true, meleeAttack = true, vehicleTheft = true, explosion = true, heistInProgress = true }

local function within(a, b, distance)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy <= distance * distance
end

local function policeNear(source, pos)
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        local o = other and other ~= source and core:getPlayer(other)
        if o and o.job and o.job.name == 'police' and o.job.onduty then
            local ped = GetPlayerPed(other)
            if ped ~= 0 and within(GetEntityCoords(ped), pos, C.policeRadius) then return true end
        end
    end
    return false
end

local function crimeNear(pos)
    local at = os.time()
    for _, call in pairs(exports['som-dispatch']:getCalls()) do
        if call.status ~= 'closed' and CRIME[call.alertType] and at - call.createdAt <= C.callWindow and within(call.coords, pos, C.callRadius) then
            return true
        end
    end
    return false
end

---The names of the signals that fired. Hard ones count alone, the soft pair only together.
local function signals(source, player, pos)
    local out = {}
    if exports['som-medical']:isDowned(player.citizenid) then out[#out + 1] = 'downed' end
    if core:getMetadata(source, 'cuffed') == true then out[#out + 1] = 'cuffed' end
    if pos and crimeNear(pos) and policeNear(source, pos) then
        out[#out + 1] = 'crime-call'
        out[#out + 1] = 'police-near'
    end
    return out
end

local function clean(text)
    if type(text) ~= 'string' then return 'unknown' end
    return text:gsub('[%z\1-\31\127]', ' '):sub(1, 60)
end

AddEventHandler('playerDropped', function(reason)
    local source = source
    reasons[source] = reason
    CreateThread(function() Wait(1000); reasons[source] = nil end)
end)

AddEventHandler('som:server:playerUnloaded', function(source, citizenid)
    local player = type(citizenid) == 'string' and core:getPlayer(source)
    if not player then return end

    -- The saved position is current only when the ped still existed at the drop;
    -- a stale one would make the crime call and police checks guess.
    local live = GetPlayerPed(source) ~= 0
    local pos = player.position
    local found = signals(source, player, live and pos or nil)
    if #found == 0 then return end

    local at = os.time()
    if lastRow[citizenid] and at - lastRow[citizenid] < C.cooldown then return end
    lastRow[citizenid] = at

    local where = pos and ('%d,%d,%d'):format(pos.x, pos.y, pos.z) or 'unknown'
    CreateThread(function()
        Wait(0)
        local detail = ('%s | %s %s | %s'):format(table.concat(found, ','), live and 'live' or 'saved', where, clean(reasons[source]))
        MySQL.insert.await('INSERT INTO som_staff_audit (staff, action, target, detail) VALUES (?, ?, ?, ?)', { 'system', 'combatlog', citizenid, detail:sub(1, 200) })

        local url = GetConvar('som_combatlog_webhook', '')
        if url == '' then return end
        local count = MySQL.scalar.await("SELECT COUNT(*) FROM som_staff_audit WHERE action = 'combatlog' AND target = ? AND created_at > NOW() - INTERVAL 24 HOUR", { citizenid }) or 1
        local text = ('Combat log: %s | %s | %s%s'):format(citizenid, table.concat(found, ','), where, count >= C.repeatCount and (' | repeat x%d'):format(count) or '')
        PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
    end)
end)

lib.addCommand('combatlogs', {
    help = 'Recent disconnects during a scene: /combatlogs [hours]',
    params = { { name = 'hours', type = 'number', optional = true } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.mod') then return end

    local hours = math.min(math.max(math.floor(tonumber(args.hours) or 24), 1), 168)
    local rows = MySQL.query.await("SELECT target, detail, created_at FROM som_staff_audit WHERE action = 'combatlog' AND created_at > NOW() - INTERVAL ? HOUR ORDER BY id DESC LIMIT ?", { hours, C.listMax }) or {}
    for _, r in ipairs(rows) do print(('[som-staff] combat log %s %s | %s'):format(r.created_at, r.target, r.detail)) end
    if source ~= 0 then
        TriggerClientEvent('som:client:notify', source, ('%d combat logs in %d hours, listed in the server console'):format(#rows, hours), 'inform')
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then lastRow, reasons = {}, {} end
end)
