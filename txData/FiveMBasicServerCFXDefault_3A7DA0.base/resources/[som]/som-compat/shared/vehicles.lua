-- QBCore.Shared.Vehicles.
--
-- qb servers hand-maintain a vehicles.lua listing every spawn name with its
-- brand and display name. qb-core is gone and SOM never had that file, so the
-- table was empty.
--
-- Empty is NOT harmless here. ps-mdt indexes the result without a nil guard:
--
--     local vehData = QBCore.Shared.Vehicles[vehicle['vehicle']]
--     result[i]['model'] = vehData["brand"] .. ' ' .. vehData["name"]
--
-- (ps-mdt/client/main.lua lines 665, 813 and 454). With an empty table that is
-- "attempt to index a nil value", so MDT vehicle profiles error out today.
--
-- The game already knows every model's make and display name, so rather than
-- reintroduce a hand-maintained list that drifts the moment an addon car is
-- streamed, entries are derived from natives. Two consequences worth knowing:
--
--   * Lookups are answered for ANY key, so the unguarded indexing above can no
--     longer throw. An unrecognised model degrades to its own spawn name.
--   * Streamed addon vehicles work for free, which a static list never does.
--
-- Client only: the label natives do not exist on the server, and both consumers
-- (ps-mdt and r14-evidence) read this client side.

SomCompatVehicles = {}

local isServer = IsDuplicityVersion()

---Resolves a GTA text label, or nil when the label is not present.
---
---GetLabelText returns the string "NULL" for a missing label rather than
---failing, so it is checked first. DoesTextLabelExist is the same guard
---r14-evidence uses (client/main.lua:207).
local function label(key)
    if not key or key == '' then return nil end
    if not DoesTextLabelExist(key) then return nil end

    local text = GetLabelText(key)
    if not text or text == '' or text == 'NULL' then return nil end

    return text
end

---TRUFFADE to Truffade.
---
---Only ever applied to a raw native return, never to a resolved label: the
---labels are already written the way they should be displayed, and forcing
---them through this would wreck names like "RUINER 2000" or "Z-Type".
local function titleCase(s)
    return (s:lower():gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest
    end))
end

---@param spawn string vehicle spawn name
---@return table entry in the qb shape
local function entryFor(spawn)
    local hash = joaat(spawn)
    local display = GetDisplayNameFromVehicleModel(hash)
    local make = GetMakeNameFromVehicleModel(hash)

    -- GetMakeNameFromVehicleModel returns the make directly on some builds and
    -- a label key on others, so resolve it as a label first and keep the raw
    -- value when it is not one. The raw value is upper case ("TRUFFADE"), which
    -- would read as "TRUFFADE Adder" in the MDT, hence the title casing.
    -- CARNOTFOUND is the game's own placeholder for an unknown model.
    local brand = label(make)
    if not brand then
        brand = (make and make ~= '' and make ~= 'CARNOTFOUND') and titleCase(make) or ''
    end

    local name = label(display) or display
    if not name or name == '' or name == 'CARNOTFOUND' then name = spawn end

    return {
        model = spawn,
        name = name,
        brand = brand,
        hash = hash,
        -- qb entries carry these. Nothing preserved reads them, but they are
        -- present so an index does not surprise a caller with nil.
        price = 0,
        category = 'unknown',
        shop = 'pdm',
    }
end

-- Computes an entry for any key it is asked for and remembers it, so a caller
-- that indexes the table without a nil check cannot throw even for a model the
-- enumeration missed.
local perKeyFallback = {
    __index = function(self, key)
        if type(key) ~= 'string' then return nil end

        local computed = entryFor(key:lower())
        rawset(self, key, computed)
        return computed
    end,
}

local function build()
    local out = setmetatable({}, perKeyFallback)

    -- Feature-detected rather than assumed: nothing else on this server calls
    -- GetAllVehicleModels, so it is not confirmed present in this build. An
    -- absent native is simply a nil global, so this cannot error.
    --
    -- It matters only for enumeration. r14-evidence walks this table with
    -- pairs() to build a hash lookup, and the fallback metatable above yields
    -- nothing to pairs(). Without the native, keyed lookups still work and only
    -- that one hash lookup comes back empty.
    if type(GetAllVehicleModels) ~= 'function' then return out end

    local models = GetAllVehicleModels()
    if type(models) ~= 'table' then return out end

    for i = 1, #models do
        local spawn = tostring(models[i]):lower()
        rawset(out, spawn, entryFor(spawn))
    end

    return out
end

---Registers Vehicles on `shared`.
---@param shared table QBCore.Shared
function SomCompatVehicles.attach(shared)
    -- The server has neither the label natives nor a consumer, but the key must
    -- still answer with a table so a stray server-side read gets an empty
    -- result rather than a nil index.
    if isServer then
        SomCompatLazy.provide(shared, 'Vehicles', function() return {} end, {})
        return
    end

    SomCompatLazy.provide(shared, 'Vehicles', build, {})
end
