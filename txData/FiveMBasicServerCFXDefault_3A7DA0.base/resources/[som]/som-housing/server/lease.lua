--- Player leases. The owner of a property offers it to the person next to them at a weekly rent; the
--- tenant gets a 'tenant' key while the lease is active. Rent goes from the tenant's bank to the
--- owner's bank, offline owners included. Weeks are claimed with conditional UPDATEs on next_due and
--- missed_cycles, so a sweep tick and a login settle cannot charge the same week twice. A week the
--- tenant cannot or does not pay is counted as missed, never retried every tick. Made by Lennox.

local core = exports['som-core']
local phone = exports['som-phone']

Lease = {}

local offers = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function whole(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

local function nameOf(player)
    return ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
end

local function maxRent(property)
    return math.max(Config.Lease.minRent, math.floor((tonumber(property.price) or 0) * Config.Lease.maxRentShare))
end

local function tell(citizenid, text, kind)
    local player = core:getPlayerByCitizenId(citizenid)
    if player then TriggerClientEvent('som:client:notify', player.source, text, kind or 'inform') end
end

---Ends an active lease and takes the tenant's key by citizenid, online or not. Only a 'tenant' key
---goes: a tenant who has since become an owner keeps that. `guard` adds one fixed condition.
---@return boolean closed, table|nil lease
local function close(id, status, guard, ...)
    local closed = MySQL.update.await(
        "UPDATE som_property_leases SET status = ?, ended_at = NOW() WHERE id = ? AND status = 'active'" .. (guard or ''),
        { status, id, ... })
    if (closed or 0) < 1 then return false end

    local lease = MySQL.single.await('SELECT property_id, landlord, tenant FROM som_property_leases WHERE id = ?', { id })
    if lease then
        MySQL.update.await("DELETE FROM som_property_owners WHERE role = 'tenant' AND property_id = ? AND citizenid = ?", { lease.property_id, lease.tenant })
    end
    return true, lease
end

-- ---------------------------------------------------------------------------
-- Offer and answer
-- ---------------------------------------------------------------------------

lib.callback.register('som-housing:server:leaseOffer', function(source, data)
    if type(data) ~= 'table' then return done(false, 'bad request') end

    local owner = core:getPlayer(source)
    if not owner then return done(false, 'not loaded') end

    local property = type(data.slug) == 'string' and Properties.BySlug(data.slug)
    if not property then return done(false, 'no such property') end
    if Ownership.RoleOf(owner.citizenid, property.id) ~= 'owner' then return done(false, 'only the owner can offer a lease') end

    local rent = whole(data.rent, Config.Lease.minRent, maxRent(property))
    if not rent then return done(false, ('the rent must be between $%d and $%d a week'):format(Config.Lease.minRent, maxRent(property))) end

    local targetSource = whole(data.target, 1, 65535)
    local target = targetSource and targetSource ~= source and core:getPlayer(targetSource)
    if not target then return done(false, 'they are not here') end

    local a, b = GetPlayerPed(source), GetPlayerPed(targetSource)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.Keys.distance then return done(false, 'they need to be next to you') end

    if Ownership.RoleOf(target.citizenid, property.id) then return done(false, 'they already have a key here') end
    if MySQL.scalar.await("SELECT 1 FROM som_property_leases WHERE property_id = ? AND status = 'active'", { property.id }) then
        return done(false, 'this property is already let')
    end

    offers[target.citizenid] = { property = property.id, landlord = owner.citizenid, source = source, rent = rent, expires = os.time() + Config.Lease.offerSeconds }
    TriggerClientEvent('som-housing:client:leaseOffer', target.source, property.label, nameOf(owner), rent)
    return done(true)
end)

lib.callback.register('som-housing:server:leaseAnswer', function(source, accept)
    local tenant = core:getPlayer(source)
    if not tenant or type(accept) ~= 'boolean' then return done(false, 'not available') end

    local offer = offers[tenant.citizenid]
    offers[tenant.citizenid] = nil
    if not offer or offer.expires < os.time() then return done(false, 'that offer is gone') end
    if not accept then return done(true) end

    local property = Properties.ById(offer.property)
    if not property or Ownership.RoleOf(offer.landlord, property.id) ~= 'owner' then return done(false, 'that offer is gone') end
    if Ownership.RoleOf(tenant.citizenid, property.id) then return done(false, 'you already have a key here') end

    -- The claim: one active lease per property and a cap per tenant, decided in one statement.
    local id = MySQL.insert.await([[
        INSERT INTO som_property_leases (property_id, landlord, tenant, rent, next_due)
        SELECT ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY) FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_property_leases WHERE property_id = ? AND status = 'active')
          AND (SELECT COUNT(*) FROM som_property_leases WHERE tenant = ? AND status = 'active') < ?
    ]], { property.id, offer.landlord, tenant.citizenid, offer.rent, Config.Lease.intervalDays, property.id, tenant.citizenid, Config.Lease.maxPerTenant })
    if not id or id < 1 then return done(false, 'this property is let already, or you have too many leases') end

    if not Ownership.Grant(property.id, tenant.citizenid, 'tenant', offer.landlord) then
        close(id, 'ended')
        return done(false, 'could not give you the key')
    end

    -- The first week is paid now, so a tenant who cannot afford it never gets the key.
    if not core:transferToCitizen(tenant.source, offer.landlord, 'bank', offer.rent, 'lease:first:' .. property.id) then
        close(id, 'ended')
        return done(false, 'you cannot afford the first week')
    end

    tell(offer.landlord, ('%s took the lease on %s'):format(nameOf(tenant), property.label), 'success')
    return done(true, nil, { label = property.label })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then offers[citizenid] = nil end
end)

-- ---------------------------------------------------------------------------
-- Rent
-- ---------------------------------------------------------------------------

local function evictIfDue(id)
    local closed, lease = close(id, 'evicted', ' AND missed_cycles >= ?', Config.Lease.evictAfterMissed)
    if not closed or not lease then return end
    tell(lease.tenant, 'You were evicted for missing rent. Your key is gone.', 'error')
    tell(lease.landlord, 'A tenant was evicted for missing rent.', 'inform')
end

---One week. The claim advances next_due first (and counts a miss in the same statement for an offline
---tenant). A tenant who is here is charged; if the transfer fails the week is counted as missed.
function Lease.Collect(lease)
    local tenant = core:getPlayerByCitizenId(lease.tenant)

    local claimed = MySQL.update.await([[
        UPDATE som_property_leases SET next_due = DATE_ADD(next_due, INTERVAL ? DAY), missed_cycles = missed_cycles + ?
        WHERE id = ? AND status = 'active' AND UNIX_TIMESTAMP(next_due) = ?
    ]], { Config.Lease.intervalDays, tenant and 0 or 1, lease.id, lease.due })
    if (claimed or 0) < 1 then return end

    if tenant and not core:transferToCitizen(tenant.source, lease.landlord, 'bank', lease.rent, 'lease:' .. lease.property_id) then
        MySQL.update.await("UPDATE som_property_leases SET missed_cycles = missed_cycles + 1 WHERE id = ? AND status = 'active'", { lease.id })
        TriggerClientEvent('som:client:notify', tenant.source, 'You could not pay your rent this week', 'error')
    end

    evictIfDue(lease.id)
end

---Pays what a returning tenant owes. The missed count is claimed (set to zero only if it is still what
---was read) before money moves, and put back if the transfer fails.
function Lease.Settle(citizenid)
    local tenant = type(citizenid) == 'string' and core:getPlayerByCitizenId(citizenid)
    if not tenant then return end

    local owed = MySQL.query.await(
        "SELECT id, property_id, landlord, rent, missed_cycles FROM som_property_leases WHERE tenant = ? AND status = 'active' AND missed_cycles > 0",
        { citizenid }) or {}

    for _, lease in ipairs(owed) do
        local claimed = MySQL.update.await(
            "UPDATE som_property_leases SET missed_cycles = 0 WHERE id = ? AND status = 'active' AND missed_cycles = ?",
            { lease.id, lease.missed_cycles })

        if (claimed or 0) >= 1 and not core:transferToCitizen(tenant.source, lease.landlord, 'bank', lease.rent * lease.missed_cycles, 'lease:arrears:' .. lease.property_id) then
            MySQL.update.await("UPDATE som_property_leases SET missed_cycles = missed_cycles + ? WHERE id = ? AND status = 'active'", { lease.missed_cycles, lease.id })
        end
    end
end

function Lease.Sweep()
    local due = MySQL.query.await([[
        SELECT id, property_id, landlord, tenant, rent, UNIX_TIMESTAMP(next_due) AS due
        FROM som_property_leases WHERE status = 'active' AND next_due <= NOW()
    ]]) or {}

    for _, lease in ipairs(due) do
        -- A lease outlives neither its owner (a repossession takes every key) nor its tenant's key.
        if Ownership.RoleOf(lease.landlord, lease.property_id) ~= 'owner' or Ownership.RoleOf(lease.tenant, lease.property_id) ~= 'tenant' then
            close(lease.id, 'ended')
        else
            local ok, err = pcall(Lease.Collect, lease)
            if not ok then print(('[som-housing] lease %s failed: %s'):format(tostring(lease.id), tostring(err))) end
        end
    end
end

CreateThread(function()
    Wait(5000)

    if not pcall(MySQL.scalar.await, 'SELECT 1 FROM som_property_leases LIMIT 1') then
        print('[som-housing] som_property_leases is missing. Import setup.sql.')
        return
    end

    while true do
        Wait(Config.Lease.sweepMinutes * 60000)
        local ok, err = pcall(Lease.Sweep)
        if not ok then print(('[som-housing] lease sweep failed: %s'):format(tostring(err))) end
    end
end)

AddEventHandler('som:server:playerLoaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    SetTimeout(10000, function() pcall(Lease.Settle, citizenid) end)
end)

-- ---------------------------------------------------------------------------
-- Phone
-- ---------------------------------------------------------------------------

local actions = {}

function actions.view(_, _, player)
    local rents, lets = {}, {}

    for _, l in ipairs(MySQL.query.await([[
        SELECT l.id, l.rent, l.missed_cycles, GREATEST(0, UNIX_TIMESTAMP(l.next_due) - UNIX_TIMESTAMP(NOW())) AS secs, p.label
        FROM som_property_leases l JOIN som_properties p ON p.id = l.property_id
        WHERE l.tenant = ? AND l.status = 'active' ORDER BY l.id
    ]], { player.citizenid }) or {}) do
        rents[#rents + 1] = {
            title = l.label,
            sub = ('$%d a week, due in %d days%s, tap to leave'):format(l.rent, math.ceil(l.secs / 86400), l.missed_cycles > 0 and (', %d missed'):format(l.missed_cycles) or ''),
            action = 'leave', payload = { id = l.id },
        }
    end

    for _, l in ipairs(MySQL.query.await([[
        SELECT l.id, l.rent, l.missed_cycles, p.label, c.firstname, c.lastname
        FROM som_property_leases l JOIN som_properties p ON p.id = l.property_id JOIN som_characters c ON c.citizenid = l.tenant
        WHERE l.landlord = ? AND l.status = 'active' ORDER BY l.id
    ]], { player.citizenid }) or {}) do
        lets[#lets + 1] = {
            title = ('%s %s: %s'):format(l.firstname, l.lastname, l.label),
            sub = ('$%d a week%s, tap to end the lease'):format(l.rent, l.missed_cycles > 0 and (', %d missed'):format(l.missed_cycles) or ''),
            action = 'end', payload = { id = l.id },
        }
    end

    return done(true, nil, { view = { sections = { { title = 'You rent', rows = rents }, { title = 'You let out', rows = lets } }, empty = 'No leases' } })
end

function actions.leave(_, payload, player)
    local id = whole(payload.id, 1, 2147483647)
    if not id then return done(false, 'bad request') end

    -- Owing rent first: leaving is not a way to skip it.
    local closed, lease = close(id, 'ended', ' AND tenant = ? AND missed_cycles = 0', player.citizenid)
    if not closed then return done(false, 'pay what you owe first, or this lease is already over') end

    tell(lease.landlord, ('%s gave up the lease'):format(nameOf(player)), 'inform')
    return done(true)
end

actions['end'] = function(_, payload, player)
    local id = whole(payload.id, 1, 2147483647)
    if not id then return done(false, 'bad request') end

    -- The week the tenant paid for is theirs: the owner can end a lease once it has run out or the
    -- tenant is behind, not the moment after taking the first week.
    local closed, lease = close(id, 'ended', ' AND landlord = ? AND (missed_cycles > 0 OR next_due <= NOW())', player.citizenid)
    if not closed then
        local running = MySQL.scalar.await("SELECT 1 FROM som_property_leases WHERE id = ? AND landlord = ? AND status = 'active'", { id, player.citizenid })
        return done(false, running and 'wait until the week is up' or 'this lease is already over')
    end

    tell(lease.tenant, 'Your lease was ended. Your key is gone.', 'error')
    return done(true)
end

phone:registerApp({
    id = 'leases', label = 'Leases', icon = 'receipt', colour = '#ff9f0a', order = 67,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})
