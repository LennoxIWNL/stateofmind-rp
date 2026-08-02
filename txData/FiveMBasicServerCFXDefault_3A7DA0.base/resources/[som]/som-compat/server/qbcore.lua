-- qb-core compatibility shim, server side.
--
-- ps-mdt is preserved byte-for-byte and calls exports['qb-core']:GetCoreObject().
-- Rather than patch it, we answer that call with a SOM-backed object, exactly
-- the way qbx_core does today (see qbx_core/bridge/qb/server/main.lua and its
-- `provide 'qb-core'` line). AUDIT.md section 7.3 lists the full surface.
--
-- This shim is deliberately MINIMAL. It exposes only what the preserved
-- resources actually call. It is not a general QBCore emulation layer, and no
-- new som-* code may use it: new code calls som-core exports directly.
--
-- Nothing here creates money or items. Money-adjacent members are intentionally
-- absent, so a legacy resource cannot mint currency through the shim.

local QBCore = {
    Functions = {},
    Shared = { Vehicles = {}, Items = {} },
    Commands = {},
}

local core = exports['som-core']

---Wraps a SOM player in the field layout legacy resources expect.
---@param player table som-core player
---@return table|nil
local function wrap(player)
    if not player then return nil end

    return {
        PlayerData = {
            source = player.source,
            citizenid = player.citizenid,
            license = player.license,
            name = GetPlayerName(player.source),
            charinfo = player.charinfo,
            job = {
                name = player.job.name,
                label = player.job.label,
                type = player.job.type,
                onduty = player.job.onduty,
                isboss = player.job.isboss,
                grade = { name = player.job.gradeLabel, level = player.job.grade },
            },
            gang = {
                name = player.gang.name,
                label = player.gang.label,
                isboss = player.gang.isboss,
                grade = { name = player.gang.gradeLabel, level = player.gang.grade },
            },
            metadata = player.metadata,
        },
    }
end

function QBCore.Functions.GetPlayer(source)
    return wrap(core:getPlayer(source))
end

function QBCore.Functions.GetPlayerByCitizenId(citizenid)
    return wrap(core:getPlayerByCitizenId(citizenid))
end

---@param source number
---@param idType string 'license', 'discord', 'steam', 'fivem'
function QBCore.Functions.GetIdentifier(source, idType)
    idType = idType or 'license'

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:sub(1, #idType + 1) == idType .. ':' then return id end
    end
    return nil
end

function QBCore.Functions.CreateCallback(name, cb)
    lib.callback.register(name, function(source, ...)
        -- QBCore callbacks take (source, cb, ...) and return by CALLING cb,
        -- possibly long after the handler body has finished. lib.callback
        -- returns by value. Bridging with a plain local would return nil for
        -- any handler that resolves asynchronously, so wait on a promise and
        -- preserve the full return tuple.
        local p = promise.new()

        cb(source, function(...)
            p:resolve(table.pack(...))
        end, ...)

        local packed = Citizen.Await(p)
        return table.unpack(packed, 1, packed.n)
    end)
end

function QBCore.Functions.TriggerCallback(name, cb, ...)
    lib.callback(name, false, cb, ...)
end

function QBCore.Commands.Add(name, help, arguments, argsrequired, callback, permission)
    lib.addCommand(name, {
        help = help,
        restricted = permission and ('som.' .. permission) or false,
    }, function(source, args, raw)
        callback(source, args, raw)
    end)
end

exports('GetCoreObject', function()
    return QBCore
end)

-- Legacy consumers that reach for the object by event rather than export.
AddEventHandler('QBCore:GetObject', function(cb)
    cb(QBCore)
end)

-- ---------------------------------------------------------------------------
-- Orphaned dependencies
--
-- ps-mdt/client/cl_impound.lua calls a callback and an event that belong to
-- resources on the Phase 1 delete list. Without these, impound release fails
-- silently. See AUDIT.md section 7.3.
-- ---------------------------------------------------------------------------

lib.callback.register('qb-garage:server:GetVehicleProperties', function(_, plate)
    if type(plate) ~= 'string' then return nil end

    local props = MySQL.scalar.await('SELECT props FROM som_vehicles WHERE plate = ?', { plate })
    return props and json.decode(props) or nil
end)
