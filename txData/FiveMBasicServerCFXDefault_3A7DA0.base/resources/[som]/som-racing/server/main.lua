--- Street racing. Tracks are recorded by driving them: the server reads the
--- driver's own position for every checkpoint, the client sends no coordinates.
--- Races, escrow and checkpoint judging are in race.lua, the phone app in app.lua.

local core = exports['som-core']
local T = Config.track

Racing = { live = {}, byRacer = {}, recording = {}, picked = {} }

function Racing.Done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

function Racing.Tell(source, text, kind)
    TriggerClientEvent('som:client:notify', source, text, kind or 'inform')
end

function Racing.Log(text)
    print('[som-racing] ' .. text)
end

local function newUid()
    return ('%08X%08X'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
end

---Issues a dongle: a ledger row plus an item that points at it. `creator` records tracks and hosts,
---`racer` hosts and joins.
function Racing.MintDongle(source, tier, tag)
    if tier ~= 'creator' and tier ~= 'racer' then return nil, 'tier is creator or racer' end
    local uid = newUid()
    MySQL.insert.await('INSERT INTO som_race_dongles (uid, tier, source_tag) VALUES (?, ?, ?)', { uid, tier, tostring(tag):sub(1, 32) })
    if not exports.ox_inventory:AddItem(source, Config.item, 1, { uid = uid, tier = tier }) then
        MySQL.update.await("UPDATE som_race_dongles SET status = 'void' WHERE uid = ? AND status = 'issued'", { uid })
        return nil, 'could not carry it'
    end
    return uid
end

---The best tier among the dongles this character carries that the ledger still honours. The
---first character to use a dongle owns it, so a copy of the item is of no use to anyone else.
function Racing.Tier(source, player)
    local best, bestUid
    for _, item in ipairs(exports.ox_inventory:Search(source, 'slots', Config.item) or {}) do
        local uid = item.metadata and item.metadata.uid
        local row = type(uid) == 'string' and uid:match('^%x+$') and #uid == 16
            and MySQL.single.await('SELECT tier, status, holder_cid FROM som_race_dongles WHERE uid = ?', { uid })
        if row and row.status == 'issued' and (row.holder_cid == player.citizenid
            or MySQL.update.await('UPDATE som_race_dongles SET holder_cid = ? WHERE uid = ? AND holder_cid IS NULL', { player.citizenid, uid }) == 1) then
            if row.tier == 'creator' then return 'creator', uid end
            best, bestUid = 'racer', uid
        end
    end
    return best, bestUid
end

---Letters, digits, space, underscore and dash only, so an alias or a track name is never markup.
function Racing.Clean(value, min, max)
    if type(value) ~= 'string' then return nil end
    local text = value:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    if #text < min or #text > max or not text:match('^[%w _%-]+$') then return nil end
    return text
end

function Racing.InVehicle(source)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
end

function Racing.NearStart(source, at)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - at) <= Config.startRadius
end

function Racing.Alias(citizenid)
    return MySQL.scalar.await('SELECT alias FROM som_race_aliases WHERE citizenid = ?', { citizenid })
end

function Racing.SetAlias(player, text)
    local alias = Racing.Clean(text, Config.alias.min, Config.alias.max)
    if not alias then return Racing.Done(false, ('an alias is %d to %d letters, digits, spaces, _ or -'):format(Config.alias.min, Config.alias.max)) end
    if Racing.Alias(player.citizenid) then return Racing.Done(false, 'you already have an alias') end
    if MySQL.update.await('INSERT IGNORE INTO som_race_aliases (citizenid, alias) VALUES (?, ?)', { player.citizenid, alias }) ~= 1 then
        return Racing.Done(false, 'that alias is taken')
    end
    return Racing.Done(true)
end

-- ---------------------------------------------------------------------------
-- Recording a track
-- ---------------------------------------------------------------------------

function Racing.Record(source, player)
    if not Config.enabled then return Racing.Done(false, 'street racing is closed') end
    if Racing.Tier(source, player) ~= 'creator' then return Racing.Done(false, 'you need a creator racing dongle') end
    if Racing.byRacer[source] then return Racing.Done(false, 'you are in a race') end
    if MySQL.scalar.await('SELECT COUNT(*) FROM som_race_tracks WHERE creator_cid = ? AND active = 1', { player.citizenid }) >= T.maxPerPerson then
        return Racing.Done(false, 'you have as many tracks as you can keep')
    end
    Racing.recording[source] = { expires = GetGameTimer() + T.recordSeconds * 1000, points = {}, length = 0.0 }
    TriggerClientEvent('som-racing:client:record', source, T.maxPoints)
    return Racing.Done(true)
end

local function recordingOf(source)
    local rec = Racing.recording[source]
    if rec and rec.expires > GetGameTimer() then return rec end
    Racing.recording[source] = nil
end

lib.callback.register('som-racing:server:drop', function(source)
    local rec = recordingOf(source)
    if not rec then return Racing.Done(false, 'you are not recording a track', { ended = true }) end
    if not Racing.InVehicle(source) then return Racing.Done(false, 'drop checkpoints from the car') end
    if #rec.points >= T.maxPoints then return Racing.Done(false, 'that is the most checkpoints a track takes') end

    local here = GetEntityCoords(GetPlayerPed(source))
    local last = rec.points[#rec.points]
    if last then
        local gap = #(here - last)
        if gap < T.minGap then return Racing.Done(false, 'too close to the last checkpoint') end
        if gap > T.maxGap then return Racing.Done(false, 'too far from the last checkpoint, drop more on the way') end
        rec.length = rec.length + gap
    end
    rec.points[#rec.points + 1] = vec3(here.x, here.y, here.z)
    return Racing.Done(true, nil, { count = #rec.points, length = math.floor(rec.length) })
end)

lib.callback.register('som-racing:server:save', function(source, name)
    local rec = recordingOf(source)
    local player = core:getPlayer(source)
    if not rec or not player then return Racing.Done(false, 'you are not recording a track', { ended = true }) end
    local tier, uid = Racing.Tier(source, player)
    if tier ~= 'creator' then return Racing.Done(false, 'you need a creator racing dongle', { ended = true }) end

    local clean = Racing.Clean(name, T.nameMin, T.nameMax)
    if not clean then return Racing.Done(false, ('a name is %d to %d letters, digits, spaces, _ or -'):format(T.nameMin, T.nameMax)) end
    if #rec.points < T.minPoints then return Racing.Done(false, ('a track needs at least %d checkpoints'):format(T.minPoints)) end

    local closing = #(rec.points[1] - rec.points[#rec.points])
    if closing > T.maxGap then return Racing.Done(false, 'the last checkpoint is too far from the start') end
    local length = rec.length + closing
    if length < T.minLength then return Racing.Done(false, 'that track is too short') end

    local points = {}
    for i, p in ipairs(rec.points) do points[i] = { x = p.x, y = p.y, z = p.z } end
    local id = MySQL.insert.await('INSERT IGNORE INTO som_race_tracks (name, creator_cid, points, length_m) VALUES (?, ?, ?, ?)',
        { clean, player.citizenid, json.encode(points), math.floor(length) })
    if not id or id < 1 then return Racing.Done(false, 'a track already has that name') end

    Racing.recording[source] = nil
    Racing.Log(('track %d saved by %s with dongle %s'):format(id, player.citizenid, uid))
    return Racing.Done(true, nil, { id = id })
end)

RegisterNetEvent('som-racing:server:abortRecording', function()
    Racing.recording[source] = nil
end)

---Only the creator takes a track down, and never while a race is using it. Times are kept.
function Racing.DeleteTrack(player, trackId)
    local track = MySQL.single.await('SELECT creator_cid FROM som_race_tracks WHERE id = ? AND active = 1', { trackId })
    if not track or track.creator_cid ~= player.citizenid then return Racing.Done(false, 'not your track') end
    for _, race in pairs(Racing.live) do
        if race.trackId == trackId then return Racing.Done(false, 'a race is using that track') end
    end
    MySQL.update.await('UPDATE som_race_tracks SET active = 0 WHERE id = ?', { trackId })
    return Racing.Done(true)
end

AddEventHandler('playerDropped', function()
    Racing.recording[source] = nil
    Racing.picked[source] = nil
end)

exports('mintDongle', Racing.MintDongle)

local function staff(source, text)
    if source ~= 0 then Racing.Tell(source, text) else Racing.Log(text) end
end

lib.addCommand('giveracedongle', {
    help = 'Issue a racing dongle (creator or racer)',
    params = { { name = 'target', type = 'playerId', help = 'server id' }, { name = 'tier', type = 'string', help = 'creator or racer' } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return staff(source, 'You do not have permission to do that') end
    local uid, err = Racing.MintDongle(args.target, args.tier, 'admin')
    staff(source, uid and ('Issued dongle %s'):format(uid) or ('Could not issue: %s'):format(err))
end)

lib.addCommand('voidracedongle', {
    help = 'Void a racing dongle by its uid, every copy stops working',
    params = { { name = 'uid', type = 'string' } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return staff(source, 'You do not have permission to do that') end
    local gone = MySQL.update.await("UPDATE som_race_dongles SET status = 'void' WHERE uid = ? AND status = 'issued'", { tostring(args.uid) })
    staff(source, gone == 1 and 'Voided' or 'No such issued dongle')
end)
