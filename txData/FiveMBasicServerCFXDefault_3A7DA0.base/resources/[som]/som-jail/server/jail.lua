--- Booking, time served and the yard. Owns som_jail_sentences; bail.lua reads
--- through it, the same split som-housing uses between ownership and finance.

local core = exports['som-core']
local dispatch = exports['som-dispatch']

Jail = {}

---On duty Config.Job, or nil plus why not.
---@param source number
---@return table|nil player, string|nil error
local function officer(source)
    local player = core:getPlayer(source)
    if not player then return nil, 'not loaded' end
    if player.job.name ~= Config.Job then return nil, 'not an officer' end
    if not player.job.onduty then return nil, 'you are off duty' end
    return player
end

---Distance measured here, never sent by the client.
---@return number
local function distanceBetween(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return math.huge end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

---@param citizenid string
---@return table|nil
function Jail.ActiveFor(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    return MySQL.single.await(
        "SELECT * FROM som_jail_sentences WHERE citizenid = ? AND status = 'serving'",
        { citizenid })
end

exports('activeFor', Jail.ActiveFor)

--- Asked on spawn so a relog while serving still shows the bail prompt.
lib.callback.register('som-jail:server:myStatus', function(source)
    local player = core:getPlayer(source)
    if not player then return { serving = false } end

    return { serving = Jail.ActiveFor(player.citizenid) ~= nil }
end)

--- The client sends a target, months and free text. Cuffed state, distance
--- and eligibility are all re-derived here.
lib.callback.register('som-jail:server:book', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player, err = officer(source)
    if not player then return { success = false, error = err } end

    local targetSource = tonumber(data.target)
    if not targetSource then return { success = false, error = 'no one selected' } end

    local target = core:getPlayer(targetSource)
    if not target then return { success = false, error = 'they are not here' } end

    if distanceBetween(source, targetSource) > 3.0 then
        return { success = false, error = 'too far away' }
    end

    if core:getMetadata(targetSource, 'cuffed') ~= true then
        return { success = false, error = 'they are not cuffed' }
    end

    if Jail.ActiveFor(target.citizenid) then
        return { success = false, error = 'they are already serving a sentence' }
    end

    local months = math.floor(tonumber(data.months) or 0)
    if months < 1 or months > Config.Cell.maxMonths then
        return { success = false, error = ('between 1 and %d months'):format(Config.Cell.maxMonths) }
    end

    local charges = type(data.charges) == 'string' and data.charges:sub(1, 255) or nil
    local convictionId = tonumber(data.convictionId)

    -- Bail was spent when it was posted, so this is a record flag, not a refund.
    MySQL.update.await(
        "UPDATE som_jail_bail SET status = 'forfeited' WHERE citizenid = ? AND status = 'posted'",
        { target.citizenid })

    MySQL.insert.await([[
        INSERT INTO som_jail_sentences
            (citizenid, officer_cid, conviction_id, charges, total_seconds, status)
        VALUES (?, ?, ?, ?, ?, 'serving')
    ]], { target.citizenid, player.citizenid, convictionId, charges, months * Config.Cell.secondsPerMonth })

    core:setMetadata(targetSource, 'cuffed', false)

    local spawn = Config.Cell.spawns[math.random(#Config.Cell.spawns)]
    TriggerClientEvent('som-jail:client:booked', targetSource, spawn)

    return { success = true, months = months }
end)

---Atomically takes a serving sentence out of 'serving'. Whoever gets true owns
---the release, so the sweep and a bail payment cannot both free the same row.
---@param sentence table
---@param status string 'released' or 'bailed'
---@param byOfficer string|nil
---@return boolean
function Jail.Claim(sentence, status, byOfficer)
    return MySQL.update.await([[
        UPDATE som_jail_sentences
        SET status = ?, released_at = CURRENT_TIMESTAMP, released_by = ?
        WHERE id = ? AND status = 'serving'
    ]], { status, byOfficer, sentence.id }) == 1
end

---Undoes a Claim whose follow-up (the bail payment) failed.
---@param sentence table
function Jail.Unclaim(sentence)
    MySQL.update.await([[
        UPDATE som_jail_sentences
        SET status = 'serving', released_at = NULL, released_by = NULL
        WHERE id = ? AND status = 'bailed'
    ]], { sentence.id })
end

---Sends the citizen to the gate if they are online.
---@param sentence table
function Jail.Free(sentence)
    local online = core:getPlayerByCitizenId(sentence.citizenid)
    if online then
        TriggerClientEvent('som-jail:client:released', online.source, Config.Cell.freedom)
    end
end

---@param sentence table
---@param status string
---@param byOfficer string|nil
---@return boolean
function Jail.Release(sentence, status, byOfficer)
    if not Jail.Claim(sentence, status, byOfficer) then return false end
    Jail.Free(sentence)
    return true
end

--- Yard position is read from the server's view of the ped. A client-reported
--- "I left" would let an inmate suppress the report.
function Jail.Sweep()
    local serving = MySQL.query.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, booked_at, NOW()) AS elapsed
        FROM som_jail_sentences WHERE status = 'serving'
    ]]) or {}

    for _, sentence in ipairs(serving) do
        if (tonumber(sentence.elapsed) or 0) >= sentence.total_seconds then
            Jail.Release(sentence, 'released', nil)
        else
            local online = core:getPlayerByCitizenId(sentence.citizenid)
            local ped = online and GetPlayerPed(online.source)

            if ped and ped ~= 0
                and #(GetEntityCoords(ped) - Config.Cell.yard) > Config.Cell.yardRadius
                and MySQL.update.await(
                    "UPDATE som_jail_sentences SET status = 'absconded' WHERE id = ? AND status = 'serving'",
                    { sentence.id }) == 1
            then
                dispatch:alert(online.source, Config.AbscondAlert, {})
            end
        end
    end
end

CreateThread(function()
    Wait(5000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_jail_sentences LIMIT 1')
    end)

    if not ok then
        print('[som-jail] som_jail_sentences is missing. Import setup.sql.')
        return
    end

    while true do
        Wait(20000)
        pcall(Jail.Sweep)
    end
end)

exports('release', Jail.Release)
