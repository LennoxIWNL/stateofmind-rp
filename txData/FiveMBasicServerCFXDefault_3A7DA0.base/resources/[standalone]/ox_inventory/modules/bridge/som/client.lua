-- SOM framework bridge, client side.
--
-- Patch to a third-party resource, see the header of som/server.lua.

RegisterNetEvent('som:client:playerLoaded', function()
    -- The server drives inventory setup from som:server:playerLoaded. Nothing
    -- to do here beyond letting ox know a character is live.
end)

AddStateBagChangeHandler('som:citizenid', ('player:%s'):format(cache.serverId), function(_, _, value)
    -- Clearing the citizenid means the character was unloaded.
    if not value then client.onLogout() end
end)

RegisterNetEvent('som:client:onJobChanged', function(job)
    if not job or not job.name then return end

    local groups = PlayerData.groups or {}
    groups[job.name] = job.grade or 0
    client.setPlayerData('groups', groups)
end)

RegisterNetEvent('som:client:onGangChanged', function(gang)
    if not gang or not gang.name then return end

    local groups = PlayerData.groups or {}
    if gang.name ~= 'none' then
        groups[gang.name] = gang.grade or 0
    end
    client.setPlayerData('groups', groups)
end)

---Applies item status effects (food, drink) to SOM metadata.
---ox passes deltas in its own scale; som-core clamps to 0-100 server side.
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    for name, value in pairs(values) do
        -- ox_inventory item definitions use the large ESX-style scale
        -- (hunger = 200000). Normalise before handing it to som-core.
        if value > 100 or value < -100 then
            value = value * 0.0001
        end

        TriggerServerEvent('som:server:adjustStatus', name, value)
    end
end
