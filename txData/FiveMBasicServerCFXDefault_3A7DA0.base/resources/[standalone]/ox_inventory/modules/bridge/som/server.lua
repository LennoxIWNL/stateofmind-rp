-- SOM framework bridge, server side.
--
-- This file is a PATCH to a third-party resource. It is the only SOM code that
-- does not live in a som-* resource, because ox_inventory resolves its bridge
-- by folder name from the inventory:framework convar (see modules/bridge/
-- server.lua:64). Keep it documented in som-core/README.md and re-apply it on
-- every ox_inventory upgrade.
--
-- MONEY IS NOT AN ITEM IN SOM.
--
-- cash, bank, crypto and dirty are all balances owned outright by som-core.
-- Unlike the stock ESX and QBox bridges, this one deliberately does NOT
-- register a 'money' account item, so `inventory:accounts` must be set to an
-- empty array in server.cfg.
--
-- Rationale: making cash an item hands the authoritative count to
-- ox_inventory, splitting ownership of the economy across two systems. The two
-- records then drift, and drift is indistinguishable from a dupe.
--
-- Cash is still robbable, through som-theft, which performs a validated
-- server-side transfer rather than letting a thief drag a stack out of a bag.

local Inventory = require 'modules.inventory.server'
local SOM = exports['som-core']

AddEventHandler('som:server:playerUnloaded', function(source)
    server.playerDropped(source)
end)

---Builds the ox_inventory groups map from SOM job and gang.
---Used by stash access rules and the police evidence grade check.
---@param player table som-core player
---@return table<string, number>
local function buildGroups(player)
    local groups = {}

    if player.job and player.job.name then
        groups[player.job.name] = player.job.grade or 0
    end
    if player.gang and player.gang.name and player.gang.name ~= 'none' then
        groups[player.gang.name] = player.gang.grade or 0
    end

    return groups
end

---@param player table som-core player
local function setupPlayer(player)
    if not player then return end

    server.setPlayerInventory({
        source = player.source,
        identifier = player.citizenid,
        name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        groups = buildGroups(player),
        sex = player.charinfo.gender,
        dateofbirth = player.charinfo.dob,
    })
end

AddEventHandler('som:server:playerLoaded', function(source)
    -- som-core fires this once the character is live and its money is loaded.
    setupPlayer(SOM:getPlayer(source))
end)

AddEventHandler('som:server:jobChanged', function(source)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    inventory.player.groups = buildGroups(SOM:getPlayer(source))
end)

AddEventHandler('som:server:gangChanged', function(source)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    inventory.player.groups = buildGroups(SOM:getPlayer(source))
end)

-- Cover a resource restart while players are already loaded.
SetTimeout(500, function()
    for _, player in ipairs(SOM:getPlayers() or {}) do
        setupPlayer(player)
    end
end)

function server.UseItem(source, itemName, data)
    -- New SOM code declares item behaviour per item in data/items.lua via
    -- client.export / server.export, which ox handles itself.
    --
    -- Preserved third-party resources instead register through
    -- QBCore.Functions.CreateUseableItem, so check som-compat's registry and
    -- fall through to ox when there is no legacy handler.
    if GetResourceState('som-compat') ~= 'started' then return nil end

    local cb = exports['som-compat']:getUseableItem(itemName)
    return cb and cb(source, data) or nil
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source = player.source,
        name = player.name,
        groups = player.groups or {},
        sex = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

---Called by ox whenever an inventory's contents change.
---
---Nothing to reconcile: SOM has no account items, so an inventory change can
---never alter a money balance. Money moves only through som-core's transaction
---bus. This is intentionally a no-op.
---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv) end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = SOM:getPlayerByCitizenId(inv.owner) or SOM:getPlayer(inv.id)
    if not player then return false end

    local licenses = player.metadata and player.metadata.licenses
    return licenses and licenses[license] or false
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = SOM:getPlayer(inv.id)
    if not player then return false end

    local licenses = player.metadata.licenses or {}

    if licenses[license.name] then
        return false, 'already_have'
    end

    -- Charge the som-core cash balance, not a money item, and let the
    -- transaction bus ledger it.
    local paid = SOM:removeMoney(inv.id, 'cash', license.price, ('license:%s'):format(license.name))
    if not paid then
        return false, 'can_not_afford'
    end

    licenses[license.name] = true
    SOM:setMetadata(inv.id, 'licenses', licenses)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    local jobs = SOM:getJobs()
    local gangs = SOM:getGangs()

    local def = jobs[group] or gangs[group]
    if not def then return false end

    local gradeData = def.grades[grade]
    return gradeData and gradeData.isboss or false
end

---@param entityId number
---@return number|string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local stateId = Entity(entityId).state.vehicleid
    if stateId then return stateId end

    local plate = GetVehicleNumberPlateText(entityId)
    if not plate then return nil end

    return MySQL.scalar.await('SELECT id FROM som_vehicles WHERE plate = ?', { plate:gsub('%s+$', '') })
end
