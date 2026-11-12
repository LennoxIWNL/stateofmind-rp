--- Scene evidence: what a crime leaves behind, and an officer collecting it.
--- Every position comes from the server's view of the ped. A client only ever
--- sends an id, and the bag it is handed carries nothing but that id.

local core = exports['som-core']
local ox = exports.ox_inventory

Evidence = {}

local lastShot, lastCasing, lastAction = {}, {}, {}

local function fail(err) return { success = false, error = err } end

---@param text string
function Evidence.Log(text)
    local url = GetConvar('som_evidence_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }),
        { ['Content-Type'] = 'application/json' })
end

---@param id number
---@param actor string citizenid
---@param action string
---@param detail string|nil
function Evidence.Custody(id, actor, action, detail)
    MySQL.insert.await(
        'INSERT INTO som_evidence_custody (evidence_id, actor_cid, action, detail) VALUES (?, ?, ?, ?)',
        { id, actor, action, detail })
    Evidence.Log(('evidence #%d %s by %s%s'):format(id, action, actor, detail and (': ' .. detail) or ''))
end

---On duty Config.Job, or nil plus why not.
---@param source number
---@return table|nil player, string|nil error
function Evidence.Officer(source)
    local player = core:getPlayer(source)
    if not player then return nil, 'not loaded' end
    if player.job.name ~= Config.Job then return nil, 'not an officer' end
    if not player.job.onduty then return nil, 'you are off duty' end
    return player
end

---At most one action per `gap` seconds per officer.
---@return boolean
function Evidence.Throttle(citizenid, key, gap)
    local now = os.time()
    local slot = citizenid .. ':' .. key
    if now - (lastAction[slot] or 0) < gap then return false end
    lastAction[slot] = now
    return true
end

---@param source number
---@return vector3|nil
function Evidence.Position(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

---An opaque code per citizen, so a lab result can match a sample without ever
---printing a citizen id. Random rather than derived, so it cannot be worked out.
---@param citizenid string
---@return string
function Evidence.Profile(citizenid)
    for _ = 1, 5 do
        local code = MySQL.scalar.await('SELECT code FROM som_evidence_profiles WHERE citizenid = ?', { citizenid })
        if code then return code end

        MySQL.insert.await('INSERT IGNORE INTO som_evidence_profiles (citizenid, code) VALUES (?, ?)',
            { citizenid, ('%08X'):format(math.random(0, 0x7fffffff)) })
    end

    error('could not allocate a profile code')
end

---@param kind string
---@param source number
---@param citizenid string
---@param serial string|nil
---@return number|nil id
local function drop(kind, source, citizenid, serial)
    local at = Evidence.Position(source)
    if not at then return nil end

    return MySQL.insert.await([[
        INSERT INTO som_evidence (kind, x, y, z, source_cid, profile, weapon_serial, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { kind, at.x, at.y, at.z, citizenid, Evidence.Profile(citizenid), serial, Config.Kinds[kind].fade })
end

---Gunfire and theft are reported by dispatch's detection; this runs for every
---detected report, whether or not dispatch raises a call for it.
AddEventHandler('som:server:crimeReported', function(source, alertType)
    local player = core:getPlayer(source)
    if not player then return end
    local cid = player.citizenid

    if alertType == 'shotsFired' or alertType == 'driveBy' then
        lastShot[cid] = os.time()

        -- A shot with no weapon in hand is a lie, not a casing.
        local weapon = ox:GetCurrentWeapon(source)
        if not weapon then return end

        local now = os.time()
        if now - (lastCasing[cid] or 0) < Config.Create.casingGap then return end
        lastCasing[cid] = now

        local at = Evidence.Position(source)
        if not at then return end

        local r = Config.Create.areaRadius
        local nearby = MySQL.scalar.await([[
            SELECT COUNT(*) FROM som_evidence
            WHERE kind = 'casing' AND status = 'scene' AND source_cid = ?
              AND x BETWEEN ? AND ? AND y BETWEEN ? AND ?
        ]], { cid, at.x - r, at.x + r, at.y - r, at.y + r })
        if (tonumber(nearby) or 0) >= Config.Create.areaCap then return end

        drop('casing', source, cid, weapon.metadata and weapon.metadata.serial or nil)
    elseif alertType == 'vehicleTheft' then
        drop('fingerprint', source, cid)
    end
end)

AddEventHandler('som:server:playerDowned', function(source, citizenid)
    if type(citizenid) == 'string' then drop('blood', source, citizenid) end
end)

---The slot holding the bag that points at this evidence, or nil.
---@param source number
---@param id number
---@return number|nil
function Evidence.BagSlot(source, id)
    for _, slot in ipairs(ox:Search(source, 'slots', Config.Items.filledBag) or {}) do
        if slot.metadata and slot.metadata.evidence_id == id then return slot.slot end
    end
end

---Bags a claimed row into the officer's inventory. Gives the claim back if the
---inventory refuses, so nothing is ever claimed without a bag to show for it.
---@param source number
---@param id number
---@return boolean ok, string|nil error
function Evidence.Bag(source, id)
    if not ox:RemoveItem(source, Config.Items.emptyBag, 1) then return false, 'you need an empty evidence bag' end

    if not ox:AddItem(source, Config.Items.filledBag, 1, { evidence_id = id }) then
        ox:AddItem(source, Config.Items.emptyBag, 1)
        return false, 'you cannot carry that'
    end

    return true
end

lib.callback.register('som-evidence:server:scan', function(source)
    local officer, err = Evidence.Officer(source)
    if not officer then return fail(err) end
    if not Evidence.Throttle(officer.citizenid, 'scan', Config.Scan.gap) then return fail('slow down') end

    local at = Evidence.Position(source)
    if not at then return fail('no position') end

    local r = Config.Scan.range
    local rows = MySQL.query.await([[
        SELECT id, kind, x, y, z FROM som_evidence
        WHERE status = 'scene' AND expires_at > NOW()
          AND x BETWEEN ? AND ? AND y BETWEEN ? AND ? LIMIT 30
    ]], { at.x - r, at.x + r, at.y - r, at.y + r }) or {}

    for _, row in ipairs(rows) do row.label = Config.Kinds[row.kind].label end
    return { success = true, evidence = rows }
end)

lib.callback.register('som-evidence:server:collect', function(source, id)
    local officer, err = Evidence.Officer(source)
    if not officer then return fail(err) end

    id = math.floor(tonumber(id) or 0)
    if id < 1 then return fail('no such evidence') end
    if not Evidence.Throttle(officer.citizenid, 'collect', Config.Collect.gap) then return fail('slow down') end

    local row = MySQL.single.await('SELECT * FROM som_evidence WHERE id = ?', { id })
    if not row then return fail('no such evidence') end

    local at = Evidence.Position(source)
    if not at or #(at - vec3(row.x, row.y, row.z)) > Config.Collect.range then return fail('too far away') end

    local won = MySQL.update.await([[
        UPDATE som_evidence SET status = 'collected', holder_cid = ?
        WHERE id = ? AND status = 'scene' AND expires_at > NOW()
    ]], { officer.citizenid, id })
    if won ~= 1 then return fail('that trace is gone') end

    local bagged, bagErr = Evidence.Bag(source, id)
    if not bagged then
        MySQL.update.await(
            "UPDATE som_evidence SET status = 'scene', holder_cid = NULL WHERE id = ? AND status = 'collected'", { id })
        return fail(bagErr)
    end

    Evidence.Custody(id, officer.citizenid, 'collected', row.kind)
    return { success = true }
end)

--- A reference sample from a person, so a lab result has something to match.
lib.callback.register('som-evidence:server:sample', function(source, targetSource, kind)
    local officer, err = Evidence.Officer(source)
    if not officer then return fail(err) end

    local def = Config.Kinds[kind]
    if not def or not def.reference then return fail('unknown sample') end

    local target = core:getPlayer(tonumber(targetSource))
    if not target then return fail('they are not here') end
    if target.citizenid == officer.citizenid then return fail('not yourself') end

    local a, b = Evidence.Position(source), Evidence.Position(tonumber(targetSource))
    if not a or not b or #(a - b) > Config.Sample.range then return fail('too far away') end
    if Config.Sample.needsCuffed and core:getMetadata(tonumber(targetSource), 'cuffed') ~= true then
        return fail('they are not cuffed')
    end

    local tool = kind == 'dna_sample' and Config.Items.dnaKit or Config.Items.printReader
    if (ox:Search(source, 'count', tool) or 0) < 1 then return fail('you need the right kit') end
    if not Evidence.Throttle(officer.citizenid, 'sample', Config.Collect.gap) then return fail('slow down') end

    local id = MySQL.insert.await([[
        INSERT INTO som_evidence (kind, x, y, z, status, holder_cid, source_cid, profile, expires_at)
        VALUES (?, ?, ?, ?, 'collected', ?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 YEAR))
    ]], { kind, a.x, a.y, a.z, officer.citizenid, target.citizenid, Evidence.Profile(target.citizenid) })

    local bagged, bagErr = Evidence.Bag(source, id)
    if not bagged then
        MySQL.update.await("UPDATE som_evidence SET status = 'destroyed' WHERE id = ?", { id })
        return fail(bagErr)
    end

    if kind == 'dna_sample' then ox:RemoveItem(source, Config.Items.dnaKit, 1) end

    Evidence.Custody(id, officer.citizenid, 'sampled', kind)
    return { success = true }
end)

--- Positive only inside the window after the person last fired a detected shot.
lib.callback.register('som-evidence:server:gsr', function(source, targetSource)
    local officer, err = Evidence.Officer(source)
    if not officer then return fail(err) end

    local target = core:getPlayer(tonumber(targetSource))
    if not target then return fail('they are not here') end

    local a, b = Evidence.Position(source), Evidence.Position(tonumber(targetSource))
    if not a or not b or #(a - b) > Config.Sample.range then return fail('too far away') end
    if (ox:Search(source, 'count', Config.Items.gsrKit) or 0) < 1 then return fail('you need a GSR kit') end
    if not Evidence.Throttle(officer.citizenid, 'gsr', Config.Collect.gap) then return fail('slow down') end

    if Config.Gsr.consumeKit then ox:RemoveItem(source, Config.Items.gsrKit, 1) end

    local shot = lastShot[target.citizenid]
    return { success = true, positive = shot ~= nil and os.time() - shot <= Config.Gsr.windowMinutes * 60 }
end)

function Evidence.Sweep()
    MySQL.update.await("UPDATE som_evidence SET status = 'destroyed' WHERE status = 'scene' AND expires_at <= NOW()")
end

CreateThread(function()
    Wait(9000)
    math.randomseed(os.time() + GetGameTimer())

    while true do
        Wait(300000)
        pcall(Evidence.Sweep)
    end
end)
