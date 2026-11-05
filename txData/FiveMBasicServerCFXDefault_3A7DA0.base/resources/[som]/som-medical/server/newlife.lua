--- The new life rule. When a player goes down the server records how (was the
--- killer another player or not) and where, from its own view of the ped. When
--- they respawn at the hospital the record becomes a timestamped row, and they
--- are told what they must forget and for how long. Staff can look it up. This
--- records and informs; it does not teleport or punish anyone.

local core = exports['som-core']

local pending = {}

local function classify(ped)
    local killer = GetPedSourceOfDeath(ped)
    if killer and killer ~= 0 and killer ~= ped and IsPedAPlayer(killer) then return 'violence' end
    return 'accident'
end

AddEventHandler('som:server:playerDowned', function(src, citizenid)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or type(citizenid) ~= 'string' then return end

    local pos = GetEntityCoords(ped)
    pending[citizenid] = { class = classify(ped), x = pos.x, y = pos.y, z = pos.z }
end)

AddEventHandler('som:server:playerRespawned', function(src, citizenid)
    local death = pending[citizenid]
    pending[citizenid] = nil
    if not death then return end

    local minutes = Config.NewLife[death.class] or 0
    if minutes < 1 then return end

    MySQL.insert.await(
        'INSERT INTO som_new_life (citizenid, class, x, y, z, until_at) VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
        { citizenid, death.class, death.x, death.y, death.z, minutes })

    TriggerClientEvent('som:client:notify', src,
        ('New life: you forget how you died. Stay away from where it happened for %d minutes.'):format(minutes), 'inform')
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then pending[citizenid] = nil end
end)

---The active new life row for a character, or nil.
---@param citizenid string
---@return table|nil { class, x, y, z, minutes_left }
local function active(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    return MySQL.single.await([[
        SELECT class, x, y, z, CEIL(TIMESTAMPDIFF(SECOND, NOW(), until_at) / 60) AS minutes_left
        FROM som_new_life WHERE citizenid = ? AND until_at > NOW() ORDER BY id DESC LIMIT 1
    ]], { citizenid })
end

exports('getNewLife', active)

lib.addCommand('nlr', {
    help = 'Show a player\'s new life restriction',
    params = { { name = 'target', type = 'playerId' } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.mod') then
        return TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    end

    local player = core:getPlayer(args.target)
    local row = player and active(player.citizenid)
    local text = row and ('%s, %d min left, at %.0f %.0f'):format(row.class, row.minutes_left, row.x, row.y) or 'No active new life'
    if source == 0 then print('[som-medical] ' .. text) else TriggerClientEvent('som:client:notify', source, text, 'inform') end
end)
