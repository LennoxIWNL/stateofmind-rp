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
-- A removed garment is moved into an `appearance.hidden` map rather than
-- overwritten, and the live component is set to the nude drawable:
--
--   components[11] = { drawable = 0,  texture = 0 }        <- what is worn now
--   hidden['11']   = { drawable = 15, texture = 2 }        <- what was taken off
--
-- So the original is never lost, wearing it again is a move back, and
-- `Appearance.Apply` needs no changes at all: it applies components as stored,
-- which are already nude. `hidden` is an extra key that every other reader,
-- including any fivem-appearance compatible tool, ignores.

local NUDE = { drawable = 0, texture = 0 }

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

---@param appearance table
---@param kind 'component'|'prop'
---@param id number
---@return boolean changed
local function removeOne(appearance, kind, id)
    local list = kind == 'component' and appearance.components or appearance.props
    if type(list) ~= 'table' then return false end

    local worn = list[tostring(id)] or list[id]
    if type(worn) ~= 'table' then return false end

    appearance.hidden = appearance.hidden or {}
    local k = key(id, kind)

    -- Already off. Removing twice must not overwrite the record of what was
    -- originally worn with the nude value we just wrote.
    if appearance.hidden[k] then return false end

    appearance.hidden[k] = { drawable = worn.drawable, texture = worn.texture }

    local nude = { drawable = NUDE.drawable, texture = NUDE.texture }
    if list[tostring(id)] ~= nil then list[tostring(id)] = nude else list[id] = nude end

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
    if type(list) ~= 'table' then return false end

    local restored = { drawable = stashed.drawable, texture = stashed.texture }
    if list[tostring(id)] ~= nil then list[tostring(id)] = restored else list[id] = restored end

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
    TriggerClientEvent('som-appearance:client:refresh', src)
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
