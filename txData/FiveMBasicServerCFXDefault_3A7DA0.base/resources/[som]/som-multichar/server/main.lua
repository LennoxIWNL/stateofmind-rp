-- Routing bucket isolation for the character selection scene.
--
-- Without this, every player selecting a character stands as an invisible ped
-- in the same interior and their preview peds collide. Each player gets a
-- private bucket while selecting, and returns to bucket 0 once loaded.
--
-- Buckets are offset well clear of 0 so they never collide with any gameplay
-- bucket a later phase introduces.
local BUCKET_OFFSET = 100000

local function enterSelection(source)
    if not Config.UseRoutingBuckets then return end
    SetPlayerRoutingBucket(source, BUCKET_OFFSET + source)
end

local function leaveSelection(source)
    if not Config.UseRoutingBuckets then return end
    SetPlayerRoutingBucket(source, 0)
end

RegisterNetEvent('som-multichar:server:enterSelection', function()
    local source = source
    -- A loaded player has no business re-entering the selection scene, and
    -- letting them would move them out of the shared world.
    if exports['som-core']:getPlayer(source) then return end

    enterSelection(source)
end)

RegisterNetEvent('som-multichar:server:leaveSelection', function()
    local source = source
    -- Only release the bucket once the server agrees a character is loaded.
    if not exports['som-core']:getPlayer(source) then return end

    leaveSelection(source)
end)

-- Belt and braces: som-core is the authority on when a character is live, so
-- release the bucket from its event too rather than relying on the client.
AddEventHandler('som:server:playerLoaded', function(source)
    leaveSelection(source)
end)

-- Scene tuning is client-side cosmetic only, but the keybinds should not be in
-- players' hands. The client cannot read ACE, so it asks here.
lib.callback.register('som-multichar:server:canTuneScene', function(source)
    local cfg = Config.SceneTuning
    if not cfg or not cfg.enabled then return false end

    -- `enabled` is the real gate, see config.lua. The ACE check is opt-in.
    if not cfg.requireAce then return true end

    local ok = exports['som-core']:hasPermission(source, cfg.ace or 'som.admin')
    if not ok then
        -- Report what the server actually believes, so a denial is not
        -- indistinguishable from the feature being broken.
        exports['som-core']:debugPermissions(source)
    end

    return ok
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- After a restart, anyone stranded in a selection bucket is put back.
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source and GetPlayerRoutingBucket(source) >= BUCKET_OFFSET then
            SetPlayerRoutingBucket(source, 0)
        end
    end
end)
