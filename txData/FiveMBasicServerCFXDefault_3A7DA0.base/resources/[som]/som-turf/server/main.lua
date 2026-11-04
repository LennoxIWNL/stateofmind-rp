--- Turf and the street drug market. A gang owns a zone by tagging a wall
--- there; a rival contests it, and takes it only by tagging again after the
--- hold window, which is computed from database timestamps. Only the owning
--- gang may sell in a zone. A sale removes the item, prices it from the market
--- table and pays marked bills minted by som-launder, so nothing here creates
--- clean cash. The client only shows where to go and what was said.

local core = exports['som-core']
local ox = exports.ox_inventory

Turf = {}

local tagging = {}
local lastSale = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function usable(z)
    return z.enabled == true and z.center ~= nil and z.radius ~= nil and z.tag ~= nil
end

local function zoneByName(name)
    if type(name) ~= 'string' then return nil end
    for _, z in ipairs(Config.zones) do
        if z.name == name and usable(z) then return z end
    end
end

local function near(source, point, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - point) <= distance
end

local function who(source)
    local player = core:getPlayer(source)
    local gang = player and player.gang
    if not gang or not gang.name or gang.name == 'none' then return nil end
    return player, gang
end

local function policeOnDuty()
    return #core:getPlayersByJob('police', true)
end

local function row(name)
    return MySQL.single.await([[
        SELECT name, owner_gang, contested_by,
               TIMESTAMPDIFF(SECOND, contest_started, NOW()) AS contest_age
        FROM som_turf WHERE name = ?
    ]], { name })
end

local function logEvent(name, gang, citizenid, points, action)
    MySQL.insert.await(
        'INSERT INTO som_turf_events (turf_id, gang, citizenid, points, action) SELECT id, ?, ?, ?, ? FROM som_turf WHERE name = ?',
        { gang, citizenid, points, action, name })
end

local function tell(gang, text)
    for _, p in pairs(core:getPlayersByGang(gang) or {}) do
        TriggerClientEvent('som:client:notify', p.source, text, 'error')
    end
end

function Turf.Seed()
    for _, z in ipairs(Config.zones) do
        MySQL.insert.await('INSERT IGNORE INTO som_turf (name, label) VALUES (?, ?)', { z.name, z.label })
    end
end

-- ---------------------------------------------------------------------------
-- Tagging
-- ---------------------------------------------------------------------------

lib.callback.register('som-turf:server:zones', function(source)
    local out = {}
    for _, z in ipairs(Config.zones) do
        if usable(z) then
            local r = row(z.name)
            out[#out + 1] = { name = z.name, label = z.label, center = z.center, radius = z.radius, tag = z.tag, owner = r and r.owner_gang or nil }
        end
    end
    local drugs = {}
    for item, d in pairs(Config.drugs) do drugs[#drugs + 1] = { item = item, label = d.label } end
    table.sort(drugs, function(a, b) return a.item < b.item end)
    return { zones = out, drugs = drugs }
end)

lib.callback.register('som-turf:server:tagBegin', function(source, name)
    local player, gang = who(source)
    if not player then return done(false, 'you are not in a gang') end
    if gang.grade < Config.claimGrade then return done(false, 'your rank is too low to claim turf') end

    local z = zoneByName(name)
    if not z then return done(false, 'there is nothing to claim here') end
    if not near(source, z.tag, Config.tagDistance) then return done(false, 'you are too far away') end

    tagging[player.citizenid] = { zone = name, at = GetGameTimer() }
    return done(true)
end)

lib.callback.register('som-turf:server:tagFinish', function(source, name)
    local player, gang = who(source)
    if not player then return done(false, 'you are not in a gang') end

    local t = tagging[player.citizenid]
    tagging[player.citizenid] = nil
    local z = zoneByName(name)
    if not t or t.zone ~= name or not z then return done(false, 'you have not started tagging') end
    if GetGameTimer() - t.at < (Config.tagSeconds - 1) * 1000 then return done(false, 'you were too quick') end
    if gang.grade < Config.claimGrade then return done(false, 'your rank is too low to claim turf') end
    if not near(source, z.tag, Config.tagDistance) then return done(false, 'you are too far away') end

    local r = row(name)
    if not r then return done(false, 'this zone is not set up') end
    local me, owner = gang.name, r.owner_gang

    if owner == nil then
        local n = MySQL.update.await(
            'UPDATE som_turf SET owner_gang = ?, claimed_at = NOW(), contested_by = NULL, contest_started = NULL WHERE name = ? AND owner_gang IS NULL',
            { me, name })
        if (n or 0) < 1 then return done(false, 'someone got there first') end
        logEvent(name, me, player.citizenid, 0, 'claim')
        return done(true, nil, { message = ('%s is yours'):format(z.label) })
    end

    if owner == me then
        local n = MySQL.update.await(
            'UPDATE som_turf SET contested_by = NULL, contest_started = NULL WHERE name = ? AND owner_gang = ? AND contested_by IS NOT NULL',
            { name, me })
        if (n or 0) < 1 then return done(false, 'this is already yours and nobody is contesting it') end
        logEvent(name, me, player.citizenid, 0, 'defend')
        return done(true, nil, { message = 'You pushed them back' })
    end

    if r.contested_by == nil then
        local n = MySQL.update.await(
            'UPDATE som_turf SET contested_by = ?, contest_started = NOW() WHERE name = ? AND owner_gang = ? AND contested_by IS NULL',
            { me, name, owner })
        if (n or 0) < 1 then return done(false, 'it changed hands, look again') end
        logEvent(name, me, player.citizenid, 0, 'contest')
        tell(owner, ('Someone is tagging over %s'):format(z.label))
        return done(true, nil, { message = ('Hold on for %d minutes, then tag again'):format(Config.holdMinutes) })
    end

    if r.contested_by ~= me then return done(false, 'another gang is already contesting this') end
    if (r.contest_age or 0) < Config.holdMinutes * 60 then return done(false, 'it is not time yet') end

    local n = MySQL.update.await([[
        UPDATE som_turf SET owner_gang = ?, claimed_at = NOW(), contested_by = NULL, contest_started = NULL
        WHERE name = ? AND owner_gang = ? AND contested_by = ?
          AND contest_started <= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { me, name, owner, me, Config.holdMinutes })
    if (n or 0) < 1 then return done(false, 'it changed hands, look again') end
    logEvent(name, me, player.citizenid, 0, 'takeover')
    tell(owner, ('%s has been taken from you'):format(z.label))
    return done(true, nil, { message = ('%s is yours'):format(z.label) })
end)

-- ---------------------------------------------------------------------------
-- Selling
-- ---------------------------------------------------------------------------

---Price of one unit right now, before the owner bonus.
local function marketPrice(item)
    local m, d = Config.market, Config.drugs[item]
    local sold = MySQL.scalar.await([[
        SELECT GREATEST(0, units - FLOOR(TIMESTAMPDIFF(SECOND, updated_at, NOW()) / 3600 * ?))
        FROM som_drug_market WHERE item = ?
    ]], { m.recoverPerHour, item }) or 0
    return d.base * math.max(m.floor, 1 - sold * m.dropPerUnit)
end

Turf.Price = marketPrice
Turf.Usable = usable

local function recordSale(item)
    MySQL.update.await([[
        INSERT INTO som_drug_market (item, units) VALUES (?, 1)
        ON DUPLICATE KEY UPDATE
            units = GREATEST(0, units - FLOOR(TIMESTAMPDIFF(SECOND, updated_at, NOW()) / 3600 * ?)) + 1,
            updated_at = NOW()
    ]], { item, Config.market.recoverPerHour })
end

lib.callback.register('som-turf:server:sell', function(source, name, item)
    local player, gang = who(source)
    if not player then return done(false, 'you are not in a gang') end
    if type(item) ~= 'string' or not Config.drugs[item] then return done(false, 'nobody wants that') end

    local z = zoneByName(name)
    if not z then return done(false, 'there is nobody to sell to here') end
    if not near(source, z.center, z.radius) then return done(false, 'you are too far away') end

    local r = row(name)
    if not r or r.owner_gang ~= gang.name then return done(false, 'this is not your turf') end
    if policeOnDuty() < Config.policeMin then return done(false, 'it is too quiet out here') end

    local now = GetGameTimer()
    if lastSale[player.citizenid] and now - lastSale[player.citizenid] < Config.sellCooldown * 1000 then
        return done(false, 'wait a moment')
    end
    lastSale[player.citizenid] = now

    if not ox:RemoveItem(source, item, 1) then return done(false, 'you have nothing to sell') end

    local price = math.max(1, math.floor(marketPrice(item) * (1 + Config.ownerBonus)))
    local uids = exports['som-launder']:mintBills(source, { price }, 'turf:' .. name)
    if not uids then
        ox:AddItem(source, item, 1)
        return done(false, 'the deal fell through')
    end

    recordSale(item)
    logEvent(name, gang.name, player.citizenid, 1, 'sale')
    exports['som-dispatch']:alert(source, 'drugDeal', { message = 'Suspicious exchange reported' })
    return done(true, nil, { message = ('Sold for $%d'):format(price) })
end)

AddEventHandler('som:server:playerUnloaded', function(source)
    local player = core:getPlayer(source)
    if player then
        tagging[player.citizenid] = nil
        lastSale[player.citizenid] = nil
    end
end)

CreateThread(function() Turf.Seed() end)
