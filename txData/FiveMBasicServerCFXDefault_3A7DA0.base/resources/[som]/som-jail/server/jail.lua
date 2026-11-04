--- Booking, time served, and the yard.
---
--- MORTGAGES ARE NOT HERE. Bail lives in server/bail.lua, which is the split
--- som-housing uses between ownership and finance: this file owns
--- som_jail_sentences and nothing else, bail.lua reads through it.

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

---Distance between two players, measured HERE rather than sent by the client.
---@return number
local function distanceBetween(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return math.huge end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

---The caller's own active sentence, or nil.
---@param citizenid string
---@return table|nil
function Jail.ActiveFor(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    return MySQL.single.await(
        "SELECT * FROM som_jail_sentences WHERE citizenid = ? AND status = 'serving'",
        { citizenid })
end

exports('activeFor', Jail.ActiveFor)

--- Asked on spawn so a relog while serving still shows the bail prompt,
--- rather than tracking jailed state purely client-side where a relog
--- would silently lose it.
lib.callback.register('som-jail:server:myStatus', function(source)
    local player = core:getPlayer(source)
    if not player then return { serving = false } end

    return { serving = Jail.ActiveFor(player.citizenid) ~= nil }
end)

-- ---------------------------------------------------------------------------
-- Booking
-- ---------------------------------------------------------------------------

--- The client sends a target and a months figure. It does not send a price,
--- a charge class, or whether the target is actually cuffed — every one of
--- those is re-read or re-derived server side.
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

    local months = math.floor(tonumber(data.months) or 0)
    if months < 1 or months > Config.Cell.maxMonths then
        return { success = false, error = ('between 1 and %d months'):format(Config.Cell.maxMonths) }
    end

    local charges = type(data.charges) == 'string' and data.charges:sub(1, 255) or nil
    local convictionId = tonumber(data.convictionId)

    -- Bail already spent at payment time (bail.lua), so forfeiture here is
    -- a record-keeping flag, not a second money movement.
    MySQL.update.await(
        "UPDATE som_jail_bail SET status = 'forfeited' WHERE citizenid = ? AND status = 'posted'",
        { target.citizenid })

    local totalSeconds = months * Config.Cell.secondsPerMonth

    MySQL.insert.await([[
        INSERT INTO som_jail_sentences
            (citizenid, officer_cid, conviction_id, charges, total_seconds, status)
        VALUES (?, ?, ?, ?, ?, 'serving')
    ]], { target.citizenid, player.citizenid, convictionId, charges, totalSeconds })

    core:setMetadata(targetSource, 'cuffed', false)

    local spawn = Config.Cell.spawns[math.random(#Config.Cell.spawns)]
    TriggerClientEvent('som-jail:client:booked', targetSource, spawn)

    return { success = true, months = months }
end)

-- ---------------------------------------------------------------------------
-- The sweep: time served, and the yard
-- ---------------------------------------------------------------------------

---Releases a sentence and, if the citizen is online, sends them to freedom.
---Shared across this resource's own files the same way Ownership/Properties
---are shared globals between som-housing's ownership.lua and finance.lua —
---an intra-resource call, not a cross-resource export round-trip.
---@param sentence table
---@param status string 'released' or 'bailed'
---@param byOfficer string|nil nil means not released by a specific officer
function Jail.Release(sentence, status, byOfficer)
    MySQL.update.await(
        "UPDATE som_jail_sentences SET status = ?, released_at = CURRENT_TIMESTAMP, released_by = ? WHERE id = ?",
        { status, byOfficer, sentence.id })

    local online = core:getPlayerByCitizenId(sentence.citizenid)
    if online then
        TriggerClientEvent('som-jail:client:released', online.source, Config.Cell.freedom)
    end
end

--- THE HOLE THIS CLOSES. A client-reported "I left the yard" would be a way
--- to suppress the report and walk out unflagged, so this is measured from
--- the server's own view of the ped, not from anything the client sends —
--- the same discipline som-housing's distance checks already use.
local function sweep()
    -- elapsed computed in the query itself, not one extra round trip per
    -- row: the exact N+1 shape this codebase's own audits flag elsewhere.
    local serving = MySQL.query.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, booked_at, NOW()) AS elapsed
        FROM som_jail_sentences WHERE status = 'serving'
    ]]) or {}

    for _, sentence in ipairs(serving) do
        if (tonumber(sentence.elapsed) or 0) >= sentence.total_seconds then
            Jail.Release(sentence, 'released', nil)
        else
            local online = core:getPlayerByCitizenId(sentence.citizenid)

            if online then
                local ped = GetPlayerPed(online.source)

                if ped and ped ~= 0 then
                    local here = GetEntityCoords(ped)

                    if #(here - Config.Cell.yard) > Config.Cell.yardRadius then
                        MySQL.update.await(
                            "UPDATE som_jail_sentences SET status = 'absconded' WHERE id = ?",
                            { sentence.id })

                        dispatch:alert(online.source, Config.AbscondAlert, {})
                    end
                end
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
        pcall(sweep)
    end
end)

exports('release', Jail.Release)
