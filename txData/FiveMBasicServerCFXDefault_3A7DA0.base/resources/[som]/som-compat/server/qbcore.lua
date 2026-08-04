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

-- Items, Weapons and Vehicles are deliberately ABSENT from this literal. They
-- are built on first read (see shared/lazy.lua, shared/items.lua and
-- shared/vehicles.lua), and the metamethod that serves them only fires for keys
-- the table does not already have.
local QBCore = {
    Functions = {},
    Shared = {},
    Commands = {},
}

local core = exports['som-core']

-- qb spells it `licences`, SOM spells it `licenses`.
--
-- ps-mdt reads Player.PlayerData.metadata.licences directly and hands the
-- result to its UI, which calls Object.entries() on it. A nil there is an
-- uncaught TypeError and the profile never renders. Its OFFLINE branch falls
-- back to a default table, so only online lookups broke, which made it look
-- like a database problem rather than a spelling one.
--
-- Aliased in a COPY. Mutating som-core's live metadata table to add a second
-- spelling would leave the alias to be written back to the database and
-- rejected, since som-core only accepts keys it knows.
---@param metadata table
---@return table
local function aliasMetadata(metadata)
    if type(metadata) ~= 'table' then return {} end

    local out = {}
    for key, value in pairs(metadata) do out[key] = value end

    out.licences = metadata.licenses or {}

    return out
end

---Wraps a SOM player in the field layout legacy resources expect.
---
---`Functions` is the important half and was missing entirely until now: the
---wrapper returned only PlayerData, so every Player.Functions.* call errored.
---That is why setting a callsign in the MDT did nothing.
---
---Only what the preserved resources actually call is implemented, and nothing
---that mints money or items. ps-mdt needs SetMetaData and RemoveMoney;
---r14-evidence needs the same plus the shared item tables.
---@param player table som-core player
---@return table|nil
-- qb calls it `birthdate`, SOM calls it `dob`.
--
-- ps-mdt renders a profile's date of birth from charinfo.birthdate
-- (server/main.lua:412), so passing SOM's charinfo through untranslated left
-- the DOB field blank on every online character. The offline path reads the
-- `players` view, which already emits `birthdate`, so only online lookups were
-- wrong, which made it look like a display bug rather than a naming one.
--
-- Aliased in a COPY, and BOTH spellings are kept: som-* code reads `dob` and
-- must keep working.
---@param charinfo table
---@return table
local function aliasCharinfo(charinfo)
    if type(charinfo) ~= 'table' then return {} end

    local out = {}
    for key, value in pairs(charinfo) do out[key] = value end

    out.birthdate = charinfo.birthdate or charinfo.dob

    return out
end

local function wrap(player)
    if not player then return nil end

    local source = player.source

    local wrapped = {
        PlayerData = {
            source = source,
            citizenid = player.citizenid,
            license = player.license,
            name = GetPlayerName(source),
            charinfo = aliasCharinfo(player.charinfo),
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
            metadata = aliasMetadata(player.metadata),
            money = player.money,
        },
    }

    wrapped.Functions = {
        ---som-core rejects any key not in Config.DefaultMetadata, so a legacy
        ---resource cannot invent state through this.
        ---
        ---The `licences` spelling is translated back on the way in. ps-mdt
        ---writes it under the qb spelling, which som-core would reject as an
        ---unknown key, so revoking a licence from the MDT would have silently
        ---done nothing.
        SetMetaData = function(key, value)
            if key == 'licences' then key = 'licenses' end
            return core:setMetadata(source, key, value)
        end,

        GetMetaData = function(key)
            if key == 'licences' then key = 'licenses' end
            return core:getMetadata(source, key)
        end,

        ---Reads only. Writing a balance goes through the transaction bus.
        GetMoney = function(account)
            return core:getMoney(source, account == 'money' and 'cash' or account)
        end,

        ---qb calls the cash account 'money'. Reason is required by the bus, so
        ---the calling resource is recorded even when it does not supply one.
        AddMoney = function(account, amount, reason)
            return core:addMoney(source, account == 'money' and 'cash' or account,
                amount, reason or 'compat')
        end,

        RemoveMoney = function(account, amount, reason)
            return core:removeMoney(source, account == 'money' and 'cash' or account,
                amount, reason or 'compat')
        end,

        SetJob = function(job, grade)
            return core:setJob(source, job, grade)
        end,

        SetGang = function(gang, grade)
            return core:setGang(source, gang, grade)
        end,

        SetDuty = function(onduty)
            return core:setDuty(source, onduty)
        end,

        Notify = function(text, notifyType, duration)
            TriggerClientEvent('som:client:notify', source, text, notifyType, duration)
        end,

        ---ox_inventory owns items. These exist because legacy resources call
        ---them on the player object rather than on the inventory.
        AddItem = function(item, amount, slot, info)
            return exports.ox_inventory:AddItem(source, item, amount, info, slot)
        end,

        RemoveItem = function(item, amount, slot)
            return exports.ox_inventory:RemoveItem(source, item, amount, nil, slot)
        end,

        GetItemByName = function(item)
            local items = exports.ox_inventory:Search(source, 'slots', item)
            return items and items[1] or nil
        end,
    }

    return wrapped
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

-- Useable items.
--
-- Legacy resources register item behaviour with CreateUseableItem. ox_inventory
-- has no equivalent registry: it expects each item to declare a client.export
-- or server.export in data/items.lua. Rather than force every preserved
-- resource to be rewritten, keep the registry here and let the ox bridge look
-- items up in it (see ox_inventory/modules/bridge/som/server.lua).
local useableItems = {}

function QBCore.Functions.CreateUseableItem(name, cb)
    if type(name) ~= 'string' or type(cb) ~= 'function' then return end
    useableItems[name] = cb
end

function QBCore.Functions.CanUseItem(name)
    return useableItems[name]
end

exports('getUseableItem', function(name)
    return useableItems[name]
end)

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

function QBCore.Functions.Notify(source, text, notifyType, duration)
    TriggerClientEvent('som:client:notify', source, text, notifyType, duration)
end

---@param vehicle number entity
function QBCore.Functions.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    -- Trailing whitespace is part of the game's plate string and is not part of
    -- the plate, so it is stripped. The extra parentheses truncate gsub to its
    -- first return; without them the count leaks into any table this builds.
    return (GetVehicleNumberPlateText(vehicle):gsub('%s+$', ''))
end

function QBCore.Functions.GetPlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
    return list
end

-- Shared.Items, Shared.Weapons and Shared.Vehicles are projected on first read.
SomCompatShared.attach(QBCore.Shared)
SomCompatVehicles.attach(QBCore.Shared)

-- Registering an export under ANOTHER resource's name.
--
-- `provide 'qb-core'` in the manifest only satisfies dependency checks. It does
-- not forward exports, so exports('GetCoreObject', ...) would publish under
-- som-compat and exports['qb-core']:GetCoreObject() would still fail.
--
-- The actual mechanism is the __cfx_export_<resource>_<name> event: the export
-- caller raises it and takes whatever the handler passes to setCB. This is how
-- qbx_core served qb-core, and how qb-target serves the ox_target names.
---@param name string
---@param fn function
local function qbExport(name, fn)
    AddEventHandler(('__cfx_export_qb-core_%s'):format(name), function(setCB)
        setCB(fn)
    end)
end

qbExport('GetCoreObject', function()
    return QBCore
end)

-- Also publish under our own name, for anything addressing som-compat directly.
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
