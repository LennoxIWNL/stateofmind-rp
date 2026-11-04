--- Booking, time served and the yard. Owns som_jail_sentences; bail.lua reads
--- through it, the same split som-housing uses between ownership and finance.

local core = exports['som-core']
local dispatch = exports['som-dispatch']
local medical = exports['som-medical']
local ox = exports.ox_inventory

local lastBook = {}

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

---@param text string
local function log(text)
    local url = GetConvar('som_jail_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }),
        { ['Content-Type'] = 'application/json' })
end

---True when the ped is missing (still loading) or outside the yard radius.
---@param source number
---@return boolean
local function outsideYard(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return true end
    return #(GetEntityCoords(ped) - Config.Cell.yard) > Config.Cell.yardRadius
end

local function randomSpawn()
    return Config.Cell.spawns[math.random(#Config.Cell.spawns)]
end

---Moves items between inventories, skipping `keep`. An item that cannot be
---added stays where it was, and a failed removal rolls the add back.
local function moveItems(from, to, keep)
    for _, item in pairs(ox:GetInventoryItems(from) or {}) do
        if not (keep and keep[item.name]) and ox:AddItem(to, item.name, item.count, item.metadata) then
            if not ox:RemoveItem(from, item.name, item.count, item.metadata, item.slot, true) then
                ox:RemoveItem(to, item.name, item.count, item.metadata, nil, true)
            end
        end
    end
end

local function stashFor(citizenid)
    local id = 'jail_' .. citizenid
    ox:RegisterStash(id, 'Held property', Config.Cell.stashSlots, Config.Cell.stashWeight, nil, nil, nil)
    return id
end

---@param source number
---@param citizenid string
function Jail.Confiscate(source, citizenid)
    moveItems(source, stashFor(citizenid), Config.Cell.keepItems)
end

---@param source number
---@param citizenid string
function Jail.ReturnProperty(source, citizenid)
    moveItems(stashFor(citizenid), source)
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

--- Asked on spawn. A serving inmate who logs in outside the yard is sent back
--- to a cell so the relog does not read as an escape, and someone released
--- while offline is sent to the gate with their property.
lib.callback.register('som-jail:server:myStatus', function(source)
    local player = core:getPlayer(source)
    if not player then return { serving = false } end

    if Jail.ActiveFor(player.citizenid) then
        return { serving = true, spawn = outsideYard(source) and randomSpawn() or nil }
    end

    local pending = MySQL.update.await(
        'UPDATE som_jail_sentences SET release_pending = 0 WHERE citizenid = ? AND release_pending = 1',
        { player.citizenid }) > 0

    if not pending then return { serving = false } end

    Jail.ReturnProperty(source, player.citizenid)
    return { serving = false, freedom = Config.Cell.freedom }
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

    if os.time() - (lastBook[player.citizenid] or 0) < Config.BookCooldown then
        return { success = false, error = 'slow down' }
    end

    local court = exports['som-court']
    local caseId = math.floor(tonumber(data.caseId) or 0)
    local kind, months, seconds = 'sentence', nil, nil
    local claimed = false

    if caseId > 0 then
        if court:openCase(caseId, target.citizenid) then
            kind, seconds = 'remand', Config.Jail.remandHours * 3600
        else
            local case = court:claimForSentence(caseId, target.citizenid, player.citizenid)
            if not case then return { success = false, error = 'that case cannot be carried out' } end
            claimed, months = true, case.sentence_months
            seconds = months * Config.Cell.secondsPerMonth
        end
    else
        months = math.floor(tonumber(data.months) or 0)
        if months < 1 or months > Config.Jail.directMaxMonths then
            return { success = false,
                error = ('without a court case, between 1 and %d months'):format(Config.Jail.directMaxMonths) }
        end
        seconds = months * Config.Cell.secondsPerMonth
    end

    local charges = type(data.charges) == 'string' and data.charges:sub(1, 255) or nil

    -- Bail was spent when it was posted, so this is a record flag, not a refund.
    MySQL.update.await(
        "UPDATE som_jail_bail SET status = 'forfeited' WHERE citizenid = ? AND status = 'posted'",
        { target.citizenid })

    local inserted = pcall(MySQL.insert.await, [[
        INSERT INTO som_jail_sentences
            (citizenid, officer_cid, case_id, charges, total_seconds, kind, status)
        VALUES (?, ?, ?, ?, ?, ?, 'serving')
    ]], { target.citizenid, player.citizenid, caseId > 0 and caseId or nil, charges, seconds, kind })

    if not inserted then
        if claimed then court:unclaimSentence(caseId) end
        return { success = false, error = 'could not record the booking' }
    end

    court:serveWarrants(target.citizenid)

    core:setMetadata(targetSource, 'cuffed', false)
    Jail.Confiscate(targetSource, target.citizenid)

    lastBook[player.citizenid] = os.time()
    log(('%s booked %s (%s): %s'):format(
        player.citizenid, target.citizenid, kind == 'remand' and 'remand' or (months .. ' mo'),
        charges or 'no charges'))

    TriggerClientEvent('som-jail:client:booked', targetSource, randomSpawn())

    return { success = true, months = months, remand = kind == 'remand' }
end)

--- What an officer may book this person on: cases from the court and any warrant.
lib.callback.register('som-jail:server:bookOptions', function(source, targetSource)
    local _, err = officer(source)
    if err then return { success = false, error = err } end

    local target = core:getPlayer(tonumber(targetSource))
    if not target then return { success = false, error = 'they are not here' } end

    return { success = true,
        cases = exports['som-court']:casesFor(target.citizenid),
        warrants = #exports['som-court']:activeWarrants(target.citizenid),
        directMax = Config.Jail.directMaxMonths }
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
        Jail.ReturnProperty(online.source, sentence.citizenid)
        TriggerClientEvent('som-jail:client:released', online.source, Config.Cell.freedom)
    else
        MySQL.update.await('UPDATE som_jail_sentences SET release_pending = 1 WHERE id = ?', { sentence.id })
    end
    log(('%s freed'):format(sentence.citizenid))
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
                and not medical:isDowned(online.source)
                and #(GetEntityCoords(ped) - Config.Cell.yard) > Config.Cell.yardRadius
                and MySQL.update.await(
                    "UPDATE som_jail_sentences SET status = 'absconded' WHERE id = ? AND status = 'serving'",
                    { sentence.id }) == 1
            then
                dispatch:alert(online.source, Config.AbscondAlert, {})
                log(('%s left the yard'):format(sentence.citizenid))
            end
        end
    end
end

---Admin early release. Console (source 0) or som.admin only.
---@param source number
---@param targetId any
---@return boolean ok, string|nil error
function Jail.Unjail(source, targetId)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return false, 'no permission' end

    local target = core:getPlayer(tonumber(targetId))
    if not target then return false, 'they are not here' end

    local sentence = Jail.ActiveFor(target.citizenid)
    if not sentence then return false, 'they are not serving' end

    local by = source ~= 0 and core:getPlayer(source) or nil
    return Jail.Release(sentence, 'released', by and by.citizenid or 'console'), nil
end

RegisterCommand('unjail', function(source, args)
    local ok, err = Jail.Unjail(source, args[1])
    local msg = ok and 'released' or (err or 'could not release')
    if source == 0 then print('[som-jail] ' .. msg) else TriggerClientEvent('som:client:notify', source, msg, ok and 'success' or 'error') end
end, false)

---A revive or hospital respawn lands the inmate outside the yard, so they are
---returned once the respawn teleport has finished.
---@param source number
function Jail.ReturnToYard(source)
    local player = core:getPlayer(source)
    if not player or not Jail.ActiveFor(player.citizenid) or not outsideYard(source) then return end
    TriggerClientEvent('som-jail:client:booked', source, randomSpawn())
end

AddEventHandler('som:server:playerRevived', function(source)
    SetTimeout(3000, function() Jail.ReturnToYard(source) end)
end)

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
