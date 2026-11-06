--- The armoury ledger: department weapons signed out and returned. Every step
--- is decided here. The client sends an item name and nothing else; the serial
--- is made from the database id, the officer and the armoury are checked from
--- the server's own view, and a row stays open until the same officer hands the
--- weapon back, whatever happens to their job, health or freedom meanwhile.

local ox = exports.ox_inventory

local STATUS_OPEN = "('out','missing')"

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function atArmoury(source)
    return Police.NearCoords(source, Config.Stations.mrpd.armoury.coords, 5.0)
end

local function entryFor(item)
    if type(item) ~= 'string' then return nil end
    for _, entry in ipairs(Config.Armoury.loan) do
        if entry.item == item then return entry end
    end
end

local function labelOf(item)
    local entry = entryFor(item)
    return entry and entry.label or item
end

---An officer on duty at the armoury, or the reason they are not.
local function officerAtArmoury(source)
    local officer, err = Police.Officer(source)
    if not officer then return nil, err end
    if not atArmoury(source) then return nil, 'you are not at the armoury' end
    return officer
end

local function holdings(citizenid)
    return MySQL.query.await([[
        SELECT id, item, serial, status FROM som_police_armoury
        WHERE citizenid = ? AND status IN ('out','missing') ORDER BY id
    ]], { citizenid }) or {}
end

lib.callback.register('som-police:server:ledger', function(source)
    local officer, err = officerAtArmoury(source)
    if not officer then return done(false, err) end

    local certs = Police.GetCerts(officer.citizenid)
    local mine, held = {}, {}
    for _, row in ipairs(holdings(officer.citizenid)) do
        mine[#mine + 1] = { item = row.item, label = labelOf(row.item), serial = row.serial, status = row.status }
        held[row.item] = true
    end

    local loans = {}
    for _, entry in ipairs(Config.Armoury.loan) do
        if not held[entry.item] and not (entry.grade and officer.job.grade < entry.grade)
            and not (entry.cert and not certs[entry.cert]) then
            loans[#loans + 1] = { item = entry.item, label = entry.label }
        end
    end

    return done(true, nil, { loans = loans, mine = mine, supervisor = officer.job.grade >= Config.SupervisorGrade })
end)

lib.callback.register('som-police:server:signOut', function(source, item)
    local officer, err = officerAtArmoury(source)
    if not officer then return done(false, err) end

    local entry = entryFor(item)
    if not entry then return done(false, 'not stocked') end
    if entry.grade and officer.job.grade < entry.grade then return done(false, 'not for your rank') end
    if entry.cert and not Police.GetCerts(officer.citizenid)[entry.cert] then return done(false, 'you are not certified for that') end

    local name = ('%s %s'):format(officer.charinfo.firstname, officer.charinfo.lastname):sub(1, 64)

    -- The claim: one open line per officer and weapon type, decided by the database.
    local id = MySQL.insert.await(([[
        INSERT INTO som_police_armoury (citizenid, officer_name, item)
        SELECT ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (
            SELECT 1 FROM som_police_armoury WHERE citizenid = ? AND item = ? AND status IN %s
        )
    ]]):format(STATUS_OPEN), { officer.citizenid, name, entry.item, officer.citizenid, entry.item })
    if not id or id < 1 then return done(false, 'you already have one signed out') end

    local serial = ('LSPD-%04d'):format(id)
    local function void() MySQL.update.await("UPDATE som_police_armoury SET status = 'void' WHERE id = ? AND status = 'out'", { id }) end

    if (MySQL.update.await('UPDATE som_police_armoury SET serial = ? WHERE id = ?', { serial, id }) or 0) < 1 then
        void()
        return done(false, 'could not record the sign-out')
    end

    if not ox:AddItem(source, entry.item, 1, { registered = true, serial = serial }) then
        void()
        return done(false, 'no room for that')
    end

    return done(true, nil, { serial = serial, label = entry.label })
end)

lib.callback.register('som-police:server:returnWeapon', function(source, item)
    local officer, err = officerAtArmoury(source)
    if not officer then return done(false, err) end
    if not entryFor(item) then return done(false, 'not stocked') end

    local row = MySQL.single.await(([[
        SELECT id, serial, status FROM som_police_armoury
        WHERE citizenid = ? AND item = ? AND status IN %s ORDER BY id DESC LIMIT 1
    ]]):format(STATUS_OPEN), { officer.citizenid, item })
    if not row then return done(false, 'you have nothing signed out') end

    -- The weapon must really be on the officer, with this line's serial on it.
    local slot
    for _, candidate in ipairs(ox:Search(source, 'slots', item) or {}) do
        if candidate.metadata and candidate.metadata.serial == row.serial then slot = candidate.slot break end
    end
    if not slot then return done(false, 'that weapon is not in your inventory') end

    local claimed = MySQL.update.await(([[
        UPDATE som_police_armoury SET status = 'returned', returned_at = NOW()
        WHERE id = ? AND citizenid = ? AND status IN %s
    ]]):format(STATUS_OPEN), { row.id, officer.citizenid })
    if (claimed or 0) < 1 then return done(false, 'already returned') end

    if not ox:RemoveItem(source, item, 1, nil, slot) then
        MySQL.update.await("UPDATE som_police_armoury SET status = ?, returned_at = NULL WHERE id = ? AND status = 'returned'", { row.status, row.id })
        return done(false, 'could not take the weapon back')
    end

    return done(true, nil, { serial = row.serial })
end)

lib.callback.register('som-police:server:ledgerAudit', function(source)
    local officer, err = officerAtArmoury(source)
    if not officer then return done(false, err) end
    if officer.job.grade < Config.SupervisorGrade then return done(false, 'supervisors only') end

    local rows = MySQL.query.await([[
        SELECT id, officer_name, item, serial, status, TIMESTAMPDIFF(HOUR, issued_at, NOW()) AS hours
        FROM som_police_armoury WHERE status IN ('out','missing') ORDER BY issued_at LIMIT 50
    ]]) or {}

    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = { id = row.id, officer = row.officer_name, label = labelOf(row.item), serial = row.serial, status = row.status, hours = tonumber(row.hours) or 0 }
    end
    return done(true, nil, { rows = out })
end)

lib.callback.register('som-police:server:flagMissing', function(source, id)
    local officer, err = officerAtArmoury(source)
    if not officer then return done(false, err) end
    if officer.job.grade < Config.SupervisorGrade then return done(false, 'supervisors only') end

    id = tonumber(id)
    if not id or id % 1 ~= 0 or id < 1 then return done(false, 'bad request') end

    -- One flag per weapon: only an 'out' line can become 'missing'.
    local flagged = MySQL.update.await(
        "UPDATE som_police_armoury SET status = 'missing', flagged_by = ?, flagged_at = NOW() WHERE id = ? AND status = 'out'",
        { officer.citizenid, id })
    if (flagged or 0) < 1 then return done(false, 'already flagged, returned or not found') end

    local row = MySQL.single.await('SELECT officer_name, item, serial FROM som_police_armoury WHERE id = ?', { id })
    if row then
        exports['som-dispatch']:alert(source, 'armouryMissing', {
            coords = Config.Stations.mrpd.armoury.coords,
            message = ('Department %s %s reported missing, last signed to %s'):format(labelOf(row.item), row.serial, row.officer_name),
        })
    end
    return done(true)
end)

-- A reminder only: going off duty with a weapon out has no penalty, and the line
-- stays open.
AddEventHandler('som:server:dutyChanged', function(source, citizenid, jobName, onduty)
    if jobName ~= Config.Job or onduty or type(citizenid) ~= 'string' then return end
    local open = holdings(citizenid)
    if #open == 0 then return end
    TriggerClientEvent('som:client:notify', source, ('You still have %d department weapon(s) signed out. Return them at the armoury.'):format(#open), 'inform')
end)
