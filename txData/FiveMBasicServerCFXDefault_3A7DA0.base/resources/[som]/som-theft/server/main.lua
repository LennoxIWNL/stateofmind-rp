-- Cash robbery.
--
-- Cash is not an inventory item in SOM, so it cannot be dragged out of a
-- victim's bag. A thief performs this action instead and the server decides
-- everything: whether it is allowed, and how much moves.
--
-- Every check here is server side on purpose. The client sends one thing, the
-- target's server id, and nothing else it says is trusted.

local SOM = exports['som-core']

local cooldowns = {}

---@param victim table som-core player
---@return boolean allowed, string|nil reason
local function victimIsRobbable(victim)
    if Config.ExemptJobs[victim.job.name] and victim.job.onduty then
        return false, 'They cannot be robbed right now'
    end

    for state in pairs(Config.RequiredVictimState) do
        if victim.metadata[state] then return true end
    end

    return false, 'They need to be incapacitated first'
end

lib.callback.register('som-theft:server:stealCash', function(source, targetId)
    local thief = SOM:getPlayer(source)
    if not thief then return { success = false, error = 'Not loaded' } end

    -- The client sends a server id. Everything else is derived here.
    targetId = tonumber(targetId)
    if not targetId then return { success = false, error = 'Invalid target' } end
    if targetId == source then return { success = false, error = 'Invalid target' } end

    local victim = SOM:getPlayer(targetId)
    if not victim then return { success = false, error = 'Target not found' } end

    -- Distance is checked here, not on the client, because a client can trigger
    -- this from anywhere on the map.
    local thiefPed = GetPlayerPed(source)
    local victimPed = GetPlayerPed(targetId)
    if not thiefPed or not victimPed or thiefPed == 0 or victimPed == 0 then
        return { success = false, error = 'Target not found' }
    end

    local distance = #(GetEntityCoords(thiefPed) - GetEntityCoords(victimPed))
    if distance > Config.MaxDistance then
        return { success = false, error = 'Too far away' }
    end

    local allowed, reason = victimIsRobbable(victim)
    if not allowed then return { success = false, error = reason } end

    local now = GetGameTimer()
    if cooldowns[victim.citizenid] and now - cooldowns[victim.citizenid] < Config.CooldownMs then
        return { success = false, error = 'They have already been searched recently' }
    end

    local available = SOM:getMoney(targetId, 'cash')
    if available <= 0 then
        -- Still set the cooldown, or an empty victim can be probed endlessly to
        -- discover the moment they next receive cash.
        cooldowns[victim.citizenid] = now
        return { success = false, error = 'They have no cash on them' }
    end

    local amount = math.floor(available * Config.StealFraction)
    if amount < 1 then amount = 1 end

    local ok, stolen = SOM:stealCash(targetId, source, amount)
    if not ok then
        return { success = false, error = 'Robbery failed' }
    end

    cooldowns[victim.citizenid] = now

    TriggerClientEvent('som:client:notify', source,
        ('You took $%s'):format(stolen), 'success')
    TriggerClientEvent('som:client:notify', targetId,
        ('$%s was taken from you'):format(stolen), 'error')

    return { success = true, amount = stolen }
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    cooldowns[citizenid] = nil
end)
