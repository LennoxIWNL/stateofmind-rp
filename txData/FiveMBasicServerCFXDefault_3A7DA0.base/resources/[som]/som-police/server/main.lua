-- Authority, duty, certifications and the station services.
--
-- Everything a client can reach is a REQUEST. The eye showing an option, the
-- armoury listing an item and a keybind firing are all just messages; this file
-- decides whether any of it happens.

local core = exports['som-core']

Police = {}

-- ---------------------------------------------------------------------------
-- Authority
-- ---------------------------------------------------------------------------

---@param source number
---@return table|nil player, string|nil error
function Police.Officer(source, requireDuty)
    local player = core:getPlayer(source)
    if not player then return nil, 'not loaded' end
    if player.job.name ~= Config.Job then return nil, 'not an officer' end

    -- Off duty is off duty. An officer who has clocked out is a civilian with
    -- a uniform, which is the entire point of a duty toggle.
    if requireDuty ~= false and not player.job.onduty then
        return nil, 'you are off duty'
    end

    return player
end

---Distance between two players, measured HERE rather than sent by the client.
---@return number
local function distanceBetween(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return math.huge end

    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

Police.DistanceBetween = distanceBetween

---@param source number
---@param targetId number
---@param maxDistance number
---@return boolean
function Police.InRange(source, targetId, maxDistance)
    return distanceBetween(source, targetId) <= (maxDistance or Config.Custody.distance)
end

---@param source number
---@param coords vector3
---@param maxDistance number
function Police.NearCoords(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - coords) <= (maxDistance or 5.0)
end

-- ---------------------------------------------------------------------------
-- Certifications
--
-- Read here and NEVER sent by the client. A client that could name its own
-- certifications would be a client that could issue itself a rifle.
-- ---------------------------------------------------------------------------

---@param citizenid string
---@param cert string
---@return boolean
function Police.HasCert(citizenid, cert)
    if not cert then return true end
    if not Config.Certifications[cert] then return false end

    local revoked = MySQL.scalar.await(
        'SELECT revoked FROM som_licenses WHERE citizenid = ? AND type = ?',
        { citizenid, cert })

    -- nil means no row at all, so it was never granted.
    if revoked == nil then return false end

    return not (revoked == true or revoked == 1)
end

---@param citizenid string
---@return table<string, boolean>
function Police.GetCerts(citizenid)
    local rows = MySQL.query.await(
        'SELECT type, revoked FROM som_licenses WHERE citizenid = ? AND type LIKE ?',
        { citizenid, 'cert.%' }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        out[row.type] = not (row.revoked == true or row.revoked == 1)
    end

    return out
end

---Grants or revokes. Supervisory, so it records who did it.
---
---A revoked certification is UPDATED rather than deleted, so the history of a
---grant survives it being taken away. That is why som_licenses has a `revoked`
---column instead of the row simply going.
---@param source number the granting officer
---@param citizenid string
---@param cert string
---@param granted boolean
---@return boolean success, string|nil error
function Police.SetCert(source, citizenid, cert, granted)
    local officer, err = Police.Officer(source, false)
    if not officer then return false, err end

    if officer.job.grade < Config.CertGrantGrade
        and not core:hasPermission(source, 'som.admin') then
        return false, 'only command staff may certify'
    end

    if type(citizenid) ~= 'string' or #citizenid < 3 then return false, 'bad citizen id' end
    if not Config.Certifications[cert] then return false, 'no such certification' end

    -- The target must actually be an officer. Certifying a civilian would
    -- create a row that nothing ever reads and that looks like an error later.
    local target = core:getPlayerByCitizenId(citizenid)
    if target and target.job.name ~= Config.Job then
        return false, 'they are not an officer'
    end

    if granted then
        MySQL.query.await([[
            INSERT INTO som_licenses (citizenid, type, issued_by, revoked)
            VALUES (?, ?, ?, 0)
            ON DUPLICATE KEY UPDATE revoked = 0, issued_by = VALUES(issued_by),
                                    issued_at = CURRENT_TIMESTAMP
        ]], { citizenid, cert, officer.citizenid })
    else
        MySQL.update.await(
            'UPDATE som_licenses SET revoked = 1 WHERE citizenid = ? AND type = ?',
            { citizenid, cert })
    end

    local label = Config.Certifications[cert].label

    if target then
        TriggerClientEvent('som:client:notify', target.source,
            granted and ('You have been certified: %s'):format(label)
                or ('Certification revoked: %s'):format(label),
            granted and 'success' or 'error')
    end

    return true
end

exports('hasCert', Police.HasCert)
exports('getCerts', Police.GetCerts)
exports('setCert', Police.SetCert)

lib.callback.register('som-police:server:myCerts', function(source)
    local officer = Police.Officer(source, false)
    if not officer then return {} end

    return Police.GetCerts(officer.citizenid)
end)

---The certifications panel in the MDT reads this.
---
---Returns the full catalogue with a held flag, rather than only what is held,
---so the panel can render an ungranted certification as an empty checkbox
---without knowing the list itself.
lib.callback.register('som-police:server:certsFor', function(source, citizenid)
    local officer = Police.Officer(source, false)
    if not officer then return { success = false, error = 'not an officer' } end
    if type(citizenid) ~= 'string' then return { success = false, error = 'bad citizen id' } end

    local held = Police.GetCerts(citizenid)
    local list = {}

    for id, def in pairs(Config.Certifications) do
        list[#list + 1] = {
            id = id,
            label = def.label,
            description = def.description,
            held = held[id] == true,
        }
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return {
        success = true,
        certifications = list,
        -- Whether THIS officer may change them, so the panel can render the
        -- toggles as read-only rather than offering a click that will be
        -- refused. The server checks again on the way in regardless.
        canGrant = officer.job.grade >= Config.CertGrantGrade
            or core:hasPermission(source, 'som.admin'),
    }
end)

lib.callback.register('som-police:server:setCert', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local ok, err = Police.SetCert(source, data.citizenid, data.cert, data.granted == true)
    return { success = ok, error = err }
end)

-- ---------------------------------------------------------------------------
-- Duty
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:toggleDuty', function(source)
    -- Duty is checked WITHOUT requiring duty, because going on duty is exactly
    -- the case where the player is not on it yet.
    local officer, err = Police.Officer(source, false)
    if not officer then return { success = false, error = err } end

    local station = Config.Stations.mrpd
    if not Police.NearCoords(source, station.duty.coords, 5.0) then
        return { success = false, error = 'you are not at the station' }
    end

    local going = not officer.job.onduty
    local ok = core:setDuty(source, going)
    if not ok then return { success = false, error = 'could not change duty' } end

    if going then Police.GrantWeaponLicence(source, officer) end

    return { success = true, onduty = going }
end)

---Officers hold a weapons licence by virtue of the job.
---
---ox_inventory gates WEAPON_PISTOL and the carbine on a `weapon` licence
---(data/licenses.lua), which a civilian buys for $5000. An officer being told
---to go and buy one before they can carry a service pistol is nonsense, so the
---badge grants it.
---
---Written on going on duty rather than on being hired, because that is a point
---this resource actually observes. It is idempotent, so repeating it is free.
---
---Deliberately NOT revoked when going off duty: taking the licence away would
---make an off-duty officer's own registered pistol contraband.
---@param source number
---@param officer table
function Police.GrantWeaponLicence(source, officer)
    local licences = core:getMetadata(source, 'licenses')
    licences = type(licences) == 'table' and licences or {}

    if licences.weapon then return end

    licences.weapon = true
    core:setMetadata(source, 'licenses', licences)
end

-- ---------------------------------------------------------------------------
-- Armoury
--
-- som-economy owns the money: it holds the department account and the prices.
-- This file owns eligibility. Keeping them apart means a price change never
-- touches police code and a certification change never touches the economy.
-- ---------------------------------------------------------------------------

---Builds the stock list this officer may actually see.
---@param officer table
---@return table issue, table personal
local function stockFor(officer)
    local certs = Police.GetCerts(officer.citizenid)

    local function allowed(entry)
        if entry.grade and officer.job.grade < entry.grade then return false end
        if entry.cert and not certs[entry.cert] then return false end
        return true
    end

    local issue, personal = {}, {}

    for _, entry in ipairs(Config.Armoury.issue) do
        if allowed(entry) then
            issue[#issue + 1] = {
                item = entry.item, label = entry.label,
                count = entry.count, price = 0,
            }
        end
    end

    for _, entry in ipairs(Config.Armoury.personal) do
        if allowed(entry) then
            local price = exports['som-economy']:armouryPrice(entry.item)

            -- An item som-economy does not price is NOT shown. Defaulting to
            -- zero would advertise a rifle as free and then have the purchase
            -- refused at the till, which reads as a bug rather than as the
            -- config mismatch it actually is.
            if price then
                personal[#personal + 1] = {
                    item = entry.item, label = entry.label,
                    count = entry.count, price = price,
                }
            else
                print(('[som-police] %s is stocked but som-economy has no price for it')
                    :format(entry.item))
            end
        end
    end

    return issue, personal
end

lib.callback.register('som-police:server:armoury', function(source)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local station = Config.Stations.mrpd
    if not Police.NearCoords(source, station.armoury.coords, 5.0) then
        return { success = false, error = 'you are not at the armoury' }
    end

    local issue, personal = stockFor(officer)

    return {
        success = true,
        label = station.label,
        issue = issue,
        personal = personal,
        -- Cash or card, with balances, so the choice is informed. som-core
        -- owns the list and validates whatever comes back.
        payment = core:paymentOptions(source),
    }
end)

lib.callback.register('som-police:server:takeItem', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local station = Config.Stations.mrpd
    if not Police.NearCoords(source, station.armoury.coords, 5.0) then
        return { success = false, error = 'you are not at the armoury' }
    end

    -- Re-resolved from config by name. The client sends an item name and
    -- nothing else: not a price, not a count, not whether it is free.
    local issue, personal = stockFor(officer)

    local entry
    for _, candidate in ipairs(issue) do
        if candidate.item == data.item then entry = candidate break end
    end
    for _, candidate in ipairs(personal) do
        if candidate.item == data.item then entry = candidate break end
    end

    if not entry then return { success = false, error = 'not stocked, or not for you' } end

    -- som-economy moves the money: department account for issue, the officer's
    -- chosen account for personal. It refuses anything it does not stock.
    local paid, payError = exports['som-economy']:issueEquipment(
        source, Config.Business, entry.item, data.account)

    if not paid then return { success = false, error = payError or 'could not pay' } end

    -- Firearms are issued REGISTERED, with a serial carrying the officer's
    -- citizenid. ox_inventory's own armoury did this and it is worth keeping:
    -- it is what lets a casing at a scene be traced back to the weapon that
    -- fired it, which is the whole point of the forensics coming later.
    local metadata
    if entry.item:find('^weapon_') then
        metadata = {
            registered = true,
            serial = ('POL%s'):format(officer.citizenid:sub(-5):upper()),
        }
    end

    local added = exports.ox_inventory:AddItem(source, entry.item, entry.count, metadata)

    if not added then
        -- Refunded rather than lost. A full inventory is not a reason to take
        -- somebody's money.
        if entry.price > 0 and data.account then
            core:addMoney(source, data.account, entry.price, 'armoury-refund')
        end
        return { success = false, error = 'no room for that' }
    end

    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Stashes
--
-- Registered on request rather than at boot. A personal locker is keyed to the
-- citizenid, so it cannot exist before the officer does, and registering the
-- shared ones here keeps all three in one place.
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:openStash', function(source, stashId)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local station = Config.Stations.mrpd

    local def
    for _, candidate in ipairs(station.stashes) do
        if candidate.id == stashId then def = candidate break end
    end

    if not def then return { success = false, error = 'no such stash' } end

    if not Police.NearCoords(source, def.coords, 5.0) then
        return { success = false, error = 'you are not there' }
    end

    -- A personal locker is per officer and per station; a shared one is per
    -- station. The name IS the access control for the personal case, since it
    -- is derived from the citizenid the server resolved rather than sent.
    local name = def.kind == 'personal'
        and ('police_%s_%s_%s'):format('mrpd', def.id, officer.citizenid)
        or ('police_%s_%s'):format('mrpd', def.id)

    exports.ox_inventory:RegisterStash(
        name, def.label, def.slots, def.weight,
        def.kind == 'personal' and officer.citizenid or nil,
        -- Shared stashes are gated on the job group as well, so a stash name
        -- guessed by a civilian still opens nothing.
        def.kind == 'personal' and nil or { [Config.Job] = 0 },
        def.coords)

    return { success = true, stash = name }
end)

-- ---------------------------------------------------------------------------
-- Radial entries
--
-- Registered with som-radial rather than declared in its config, so the police
-- entries live with the police code. som-radial filters these SERVER side on
-- the job and duty fields below, so a client cannot restore an entry it is not
-- entitled to by editing its own menu.
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- After som-radial has started.
    Wait(1000)

    if GetResourceState('som-radial') ~= 'started' then return end

    local radial = exports['som-radial']

    radial:register({
        id = 'police.mdt',
        section = 'job',
        label = 'MDT',
        icon = 'laptop',
        order = 10,
        export = 'som-police.openMDT',
        job = Config.Job,
        duty = true,
    })

    radial:register({
        id = 'police.certs',
        section = 'job',
        label = 'Certifications',
        icon = 'badge',
        order = 20,
        export = 'som-police.showCerts',
        job = Config.Job,
    })
end)

-- ---------------------------------------------------------------------------
-- Coordinate helpers
--
-- The config coordinates are harvested from other servers' MLOs and are
-- expected to be wrong somewhere. These make correcting them a minute's work
-- rather than a guessing game.
-- ---------------------------------------------------------------------------

-- Not `restricted`, for two reasons. It hands the check to FiveM's ACE, which
-- does not resolve on this server, so the command would be refused before its
-- handler ran and print nothing. And 'group.admin' is a PRINCIPAL, not an ACE,
-- so it was the wrong kind of value to begin with.
--
-- som-core's hasPermission has an owner-by-identifier fallback that works.
lib.addCommand('pdcoords', {
    help = 'Print your position formatted for the som-police config',
}, function(source)
    if source == 0 then return end

    if not core:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source,
            'You do not have permission to do that', 'error')
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)

    TriggerClientEvent('som-police:client:coords', source,
        ('vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z),
        ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h))
end)
