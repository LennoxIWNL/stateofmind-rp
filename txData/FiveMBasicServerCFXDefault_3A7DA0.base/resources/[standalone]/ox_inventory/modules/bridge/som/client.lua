-- SOM framework bridge, client side.
--
-- Patch to a third-party resource, see the header of som/server.lua.

-- ---------------------------------------------------------------------------
-- Notifications
--
-- ox_inventory's own notifications are off: inventory:itemnotify and
-- inventory:weaponnotify are 0 in server.cfg, which removes the item pickup,
-- drop, equip and holster cards entirely.
--
-- What is left are ox_lib error toasts, and those are redirected here rather
-- than silenced. Two toast designs on screen is the inconsistency we are
-- removing, but a player who cannot open a stash still needs telling why.
--
-- `lib` is per-resource in FiveM, so replacing lib.notify affects only
-- ox_inventory. This file is required first by client.lua, before anything
-- that could fire a notification.
-- ---------------------------------------------------------------------------

do
    local passthrough = lib.notify

    -- ox_lib calls its neutral type 'inform'; som-ui calls it 'info'. Unmapped
    -- values fall through to som-ui's own default.
    local TYPES = { inform = 'info', success = 'success', error = 'error', warning = 'warning' }

    ---@param data { type?: string, description?: string, title?: string, duration?: number }
    lib.notify = function(data)
        if type(data) ~= 'table' then return end

        local text = data.description or data.title
        if not text then return end

        if GetResourceState('som-ui') ~= 'started' then
            -- som-ui missing is a broken install, not a reason to swallow the
            -- message. Fall back to ox_lib rather than losing it.
            return passthrough(data)
        end

        TriggerEvent('som:client:notify', text, TYPES[data.type] or 'info', data.duration)
    end
end

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
