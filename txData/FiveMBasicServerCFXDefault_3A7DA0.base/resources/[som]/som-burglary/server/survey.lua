--- Staff measure where the search spots are inside a burglary shell. Nothing
--- records them, so an admin walks into the shell, stands at a drawer and runs
--- /burglaryspot. The server reads the admin's own position, subtracts the
--- shell origin it computed itself, and keeps the offset in som_placements, the
--- same table /place uses, so it loads at boot (SomPlacements.Apply in main.lua)
--- and is exactly what spotsOf reads. A survey is not a run: it creates no run
--- row, pays nothing and uses its own routing bucket. Made by Lennox.

local core = exports['som-core']
local S = Config.survey

local surveys = {}

local function notify(source, text, kind)
    TriggerClientEvent('som:client:notify', source, text, kind or 'inform')
end

local function pathOf(shell) return ('shells.%s.spots+'):format(shell) end

local function bucketOf(survey) return Config.bucketBase + S.bucketOffset + survey.index end

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

---The admin behind a command, or nil after telling them why not.
local function staff(source)
    if source == 0 then return nil end
    local player = core:getPlayer(source)
    if not player or not core:hasPermission(source, 'som.admin') then
        notify(source, 'You do not have permission to do that', 'error')
        return nil
    end
    return player
end

local function audit(player, action, target, detail)
    MySQL.insert.await('INSERT INTO som_staff_audit (staff, action, target, detail) VALUES (?, ?, ?, ?)',
        { player.citizenid, action, target:sub(1, 48), detail and detail:sub(1, 200) or nil })
end

---The survey a command runs in, once the admin is inside the shell.
local function current(source)
    local survey = surveys[source]
    if not survey then
        notify(source, 'Enter a shell first with /burglarysurvey <house id>', 'error')
        return nil
    end
    if GetPlayerRoutingBucket(source) ~= bucketOf(survey) then
        notify(source, 'You are not inside the shell', 'error')
        return nil
    end
    return survey
end

local function cleanLabel(text)
    if type(text) ~= 'string' then return nil end
    -- Printable ASCII only: the stored value is a VARCHAR(200) and a prompt label needs no more.
    local label = text:gsub('[^\32-\126]', ''):match('^%s*(.-)%s*$')
    if #label < 1 or #label > S.maxLabel then return nil end
    return label
end

local function leave(source)
    local survey = surveys[source]
    if not survey then return nil end
    surveys[source] = nil
    SetPlayerRoutingBucket(source, 0)
    return survey.back
end

lib.addCommand('burglarysurvey', {
    help = 'Staff: walk into a burglary house shell to measure its search spots: /burglarysurvey <house id>',
    params = { { name = 'house', type = 'string' } },
}, function(source, args)
    local player = staff(source)
    if not player then return end

    if surveys[source] then return notify(source, 'You are already in a shell. Leave it first.', 'error') end
    if Burglary.RunOf(source) then return notify(source, 'Finish your job first', 'error') end

    local house, index
    local ids = {}
    for i, h in ipairs(Config.houses) do
        ids[#ids + 1] = h.id
        if h.id == args.house then house, index = h, i end
    end
    if not house then return notify(source, 'No such house. Use one of: ' .. table.concat(ids, ', '), 'error') end

    local offset = exports['som-housing']:shellOffset(house.shell)
    if not offset or not Config.shells[house.shell] then return notify(source, 'That shell has no measured exit', 'error') end

    local ped = GetPlayerPed(source)
    if ped == 0 then return end

    local survey = { house = house, index = index, back = GetEntityCoords(ped) }
    surveys[source] = survey
    SetPlayerRoutingBucket(source, bucketOf(survey))

    local origin = Burglary.Origin(index)
    TriggerClientEvent('som-burglary:client:survey', source, {
        shell = house.shell, void = { x = origin.x, y = origin.y, z = origin.z }, offset = offset, spots = {}, survey = true,
    })
    audit(player, 'burglarysurvey', house.id)
end)

lib.callback.register('som-burglary:server:surveyLeave', function(source)
    local back = leave(source)
    if not back then return { success = false, error = 'you are not in a shell' } end
    return { success = true, coords = { x = back.x, y = back.y, z = back.z } }
end)

lib.addCommand('burglaryspot', {
    help = 'Staff, inside a shell: save where you stand as a search spot: /burglaryspot <label>',
    params = { { name = 'label', type = 'longString' } },
}, function(source, args)
    local player = staff(source)
    if not player then return end
    local survey = current(source)
    if not survey then return end

    local label = cleanLabel(args.label)
    if not label then return notify(source, ('Give a label of 1 to %d characters'):format(S.maxLabel), 'error') end

    local shell = survey.house.shell
    local spots = Config.shells[shell].spots
    if #spots >= S.maxSpots then
        return notify(source, ('%s already has %d spots. Remove one with /burglaryspotundo.'):format(shell, S.maxSpots), 'error')
    end

    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local diff = GetEntityCoords(ped) - Burglary.Origin(survey.index)
    if #diff > S.maxRadius then return notify(source, 'That is too far from the shell', 'error') end

    local offset = vec3(round2(diff.x), round2(diff.y), round2(diff.z))
    local spot = { offset = offset, label = label }

    -- Added before the write so the cap holds while the insert waits.
    spots[#spots + 1] = spot
    local id = MySQL.insert.await('INSERT INTO som_placements (resource, path, kind, value, placed_by) VALUES (?, ?, ?, ?, ?)',
        { 'som-burglary', pathOf(shell), 'point', json.encode({ x = offset.x, y = offset.y, z = offset.z, label = label }), player.citizenid })
    if not id then
        for i = #spots, 1, -1 do if spots[i] == spot then table.remove(spots, i) break end end
        return notify(source, 'Could not save the spot', 'error')
    end

    audit(player, 'burglaryspot', shell, ('%s %.2f %.2f %.2f'):format(label, offset.x, offset.y, offset.z))
    notify(source, ('Saved spot %d of %s: %s at offset %.2f, %.2f, %.2f'):format(#spots, shell, label, offset.x, offset.y, offset.z))
end)

lib.addCommand('burglaryspots', { help = 'Staff, inside a shell: list its search spots' }, function(source)
    if not staff(source) then return end
    local survey = current(source)
    if not survey then return end

    local spots = Config.shells[survey.house.shell].spots
    if #spots == 0 then return notify(source, survey.house.shell .. ' has no spots yet') end
    for i, spot in ipairs(spots) do
        notify(source, ('%d. %s (%.2f, %.2f, %.2f)'):format(i, spot.label, spot.offset.x, spot.offset.y, spot.offset.z))
    end
end)

-- shortcut: two staff editing one shell at the same moment can leave the list in memory
-- different from the table until the next restart; surveys are one admin at a time.
lib.addCommand('burglaryspotundo', { help = 'Staff, inside a shell: remove the last spot staff saved' }, function(source)
    local player = staff(source)
    if not player then return end
    local survey = current(source)
    if not survey then return end

    local shell = survey.house.shell
    local spots = Config.shells[shell].spots
    local removed = MySQL.update.await('DELETE FROM som_placements WHERE resource = ? AND path = ? ORDER BY id DESC LIMIT 1',
        { 'som-burglary', pathOf(shell) })
    if (removed or 0) < 1 then return notify(source, 'There is no spot saved by staff to remove', 'error') end

    local gone = table.remove(spots)
    audit(player, 'burglaryspotundo', shell, gone and gone.label)
    notify(source, ('Removed the last spot of %s (%d left)'):format(shell, #spots))
end)

AddEventHandler('som:server:playerUnloaded', function(source)
    local back = leave(source)
    if back then TriggerClientEvent('som-burglary:client:exit', source, { x = back.x, y = back.y, z = back.z }) end
end)

AddEventHandler('playerDropped', function()
    surveys[source] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for source in pairs(surveys) do SetPlayerRoutingBucket(source, 0) end
end)
