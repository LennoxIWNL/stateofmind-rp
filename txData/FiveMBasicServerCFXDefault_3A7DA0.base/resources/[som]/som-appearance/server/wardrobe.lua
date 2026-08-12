-- Taking clothes off and putting them back on.
--
-- WHY THIS LIVES HERE AND NOT IN som-inventory. The inventory is where a player
-- asks, but appearance is what changes, and appearance is this resource's to
-- own. Putting the mutation next to the data means there is still exactly one
-- place that writes som_characters.appearance, which is the property that makes
-- the scope system in server/main.lua worth anything.
--
-- HOW REMOVING WORKS, AND WHY IT IS NOT DESTRUCTIVE.
--
-- A removed garment is copied into an `appearance.hidden` map and the live
-- record is set to the nude drawable IN PLACE:
--
--   hidden['component:11'] = { drawable = 15, texture = 2 }  <- what came off
--
-- So the original is never lost, wearing it again is a copy back, and
-- `Appearance.Apply` needs no changes: it applies components as stored, which
-- are already nude. `hidden` is an extra key every other reader ignores,
-- including any fivem-appearance compatible tool.
--
-- THE SHAPE. `components` and `props` are ARRAYS OF RECORDS, not maps keyed by
-- id:
--
--   components = { { component_id = 11, drawable = 15, texture = 2 }, ... }
--   props      = { { prop_id = 0,       drawable = 4,  texture = 0 }, ... }
--
-- built that way by `Appearance.Get` and `Appearance.Default`
-- (client/appearance.lua:39, 250) and read that way by `ApplyApparel`, which
-- does `tonumber(c.component_id)` and SKIPS any record without one.
--
-- That matters more than it looks. An earlier version of this file indexed
-- `list[id]`, which on an array hits a POSITION, so component 3 read the record
-- for component 4, and writing a fresh `{drawable, texture}` table dropped
-- `component_id` and made the entry invisible to ApplyApparel forever. Records
-- are therefore MUTATED IN PLACE below, never replaced, which is what keeps the
-- id attached.

-- Components use 0 for bare. Props use -1 for none: ApplyApparel clamps a prop
-- to a -1 floor and calls ClearPedProp for it, where 0 would be a real hat.
local NUDE_COMPONENT = 0
local NUDE_PROP = -1

---Component ids this is willing to touch, built from config rather than
---hardcoded, so adding a slot to Config.Components is the only edit needed.
---
---Hair is deliberately excluded. It is component 2 and is edited with its
---colour elsewhere; "remove all clothes" should not make somebody bald.
local REMOVABLE = {}
for _, entry in ipairs(Config.Components) do
    if entry.id ~= Config.HairComponent then REMOVABLE[entry.id] = true end
end

local REMOVABLE_PROPS = {}
for _, entry in ipairs(Config.Props) do REMOVABLE_PROPS[entry.id] = true end

---@param source number
---@return table|nil player, table|nil appearance
local function load(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    local stored = MySQL.scalar.await(
        'SELECT appearance FROM som_characters WHERE citizenid = ?', { player.citizenid })

    return player, stored and json.decode(stored) or nil
end

---@param player table
---@param appearance table
local function persist(player, appearance)
    MySQL.update.await('UPDATE som_characters SET appearance = ? WHERE citizenid = ?',
        { json.encode(appearance), player.citizenid })
end

---Key for the hidden map. JSON turns integer keys into strings on the way to
---the database and back, so they are stored as strings from the start rather
---than being a number on the first read and a string on the second.
local function key(id, kind)
    return ('%s:%d'):format(kind, id)
end

---Finds a record in the array by its id field.
---
---A linear scan, because these arrays are at most eleven entries and a map
---built per call would cost more than it saved.
---@param list table|nil
---@param kind 'component'|'prop'
---@param id number
---@return table|nil record
local function findRecord(list, kind, id)
    if type(list) ~= 'table' then return nil end

    local field = kind == 'prop' and 'prop_id' or 'component_id'

    for _, entry in ipairs(list) do
        if type(entry) == 'table' and tonumber(entry[field]) == id then return entry end
    end

    return nil
end

---@param appearance table
---@param kind 'component'|'prop'
---@param id number
---@return boolean changed
local function removeOne(appearance, kind, id)
    local list = kind == 'component' and appearance.components or appearance.props
    local record = findRecord(list, kind, id)
    if not record then return false end

    appearance.hidden = appearance.hidden or {}
    local k = key(id, kind)

    -- Already off. Removing twice must not overwrite the record of what was
    -- originally worn with the nude value written the first time.
    if appearance.hidden[k] then return false end

    appearance.hidden[k] = { drawable = record.drawable, texture = record.texture }

    -- IN PLACE. Replacing the table would drop component_id/prop_id and make
    -- the entry invisible to ApplyApparel.
    record.drawable = kind == 'prop' and NUDE_PROP or NUDE_COMPONENT
    record.texture = 0

    return true
end

---@param appearance table
---@param kind 'component'|'prop'
---@param id number
---@return boolean changed
local function wearOne(appearance, kind, id)
    if type(appearance.hidden) ~= 'table' then return false end

    local k = key(id, kind)
    local stashed = appearance.hidden[k]
    if type(stashed) ~= 'table' then return false end

    local list = kind == 'component' and appearance.components or appearance.props
    local record = findRecord(list, kind, id)
    if not record then return false end

    record.drawable = stashed.drawable
    record.texture = stashed.texture
    appearance.hidden[k] = nil

    return true
end

RegisterNetEvent('som-appearance:server:wardrobe', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local action = data.action
    if action ~= 'remove' and action ~= 'wear' and action ~= 'removeAll' and action ~= 'wearAll' then
        return
    end

    local player, appearance = load(src)
    if not player or type(appearance) ~= 'table' then return end

    local changed = false

    if action == 'removeAll' or action == 'wearAll' then
        local fn = action == 'removeAll' and removeOne or wearOne

        for id in pairs(REMOVABLE) do
            if fn(appearance, 'component', id) then changed = true end
        end
        for id in pairs(REMOVABLE_PROPS) do
            if fn(appearance, 'prop', id) then changed = true end
        end
    else
        local kind = data.kind == 'prop' and 'prop' or 'component'
        local id = tonumber(data.id)
        if not id or id ~= id or id % 1 ~= 0 then return end

        -- The allow list is the whole of the validation here. A crafted id for
        -- a component nobody is meant to strip is refused rather than clamped.
        local allowed = kind == 'prop' and REMOVABLE_PROPS[id] or REMOVABLE[id]
        if not allowed then return end

        local fn = action == 'remove' and removeOne or wearOne
        changed = fn(appearance, kind, id)
    end

    if not changed then return end

    persist(player, appearance)

    -- The kind and id ride along so the client can pick an animation that
    -- matches the garment. COSMETIC ONLY: the client has already been told
    -- what its appearance is by this point, and this changes nothing about
    -- what was written. A client ignoring it just gets a generic motion.
    TriggerClientEvent('som-appearance:client:refresh', src, {
        action = action,
        kind = data.kind == 'prop' and 'prop' or 'component',
        id = tonumber(data.id),
    })
end)

---What is currently off, so the inventory rail can render each slot's state.
---
---Read only, and derived from the STORED record rather than from the ped, so a
---slot that failed to apply visually still reports what the character actually
---owns.
lib.callback.register('som-appearance:server:wardrobeState', function(source)
    local player, appearance = load(source)
    if not player or type(appearance) ~= 'table' then
        return { success = false, error = 'no appearance' }
    end

    local hidden = type(appearance.hidden) == 'table' and appearance.hidden or {}
    local slots = {}

    for _, entry in ipairs(Config.Components) do
        if entry.id ~= Config.HairComponent then
            slots[#slots + 1] = {
                kind = 'component',
                id = entry.id,
                label = entry.label,
                group = entry.group,
                off = hidden[key(entry.id, 'component')] ~= nil,
            }
        end
    end

    for _, entry in ipairs(Config.Props) do
        slots[#slots + 1] = {
            kind = 'prop',
            id = entry.id,
            label = entry.label,
            group = entry.group,
            off = hidden[key(entry.id, 'prop')] ~= nil,
        }
    end

    return { success = true, slots = slots }
end)
