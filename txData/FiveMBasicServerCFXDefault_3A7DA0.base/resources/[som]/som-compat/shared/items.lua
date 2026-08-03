-- QBCore.Shared.Items and QBCore.Shared.Weapons.
--
-- Both were empty tables, which is harmless until something reads them.
-- r14-evidence reads them 22 times between them, to resolve a weapon from a
-- shell casing and an item label from a name, so empty meant silent nils deep
-- inside an evidence lookup.
--
-- ox_inventory owns the real lists and merges weapons INTO its item list
-- (ox_inventory/modules/items/shared.lua), so both tables are projected from
-- the same source. Projected on demand rather than copied at boot, so an item
-- added to ox never needs adding here too.
--
-- Shared, because the projection is identical in both contexts and
-- exports.ox_inventory:Items() answers in both.

SomCompatShared = {}

---@return table<string, table>|nil ox's full item list, or nil if it is not up yet
local function oxItems()
    local ok, items = pcall(function() return exports.ox_inventory:Items() end)
    if not ok or type(items) ~= 'table' then return nil end
    return items
end

---@param items table ox's item list
local function buildItems(items)
    local out = {}
    for name, item in pairs(items) do
        out[name] = {
            name = name,
            label = item.label or name,
            weight = item.weight or 0,
            type = item.weapon and 'weapon' or 'item',
            -- ox stores an image path under client.image and strips the client
            -- table server side, so fall back to qb's filename convention.
            image = (item.client and item.client.image) or ('%s.png'):format(name),
            unique = item.stack == false,
            useable = true,
            shouldClose = item.close ~= false,
            description = item.description or '',
        }
    end

    return out
end

---Weapons in the qb shape, keyed by name AND by hash.
---
---Both, because callers reach for them either way: r14-evidence resolves a
---casing by the weapon HASH it gets from the shooting event
---(r14-evidence/client/main.lua:1308), while ps-mdt works by name. Keying both
---costs nothing and saves every caller guessing which it got.
---
---`item.weapon` and `item.hash` are set by ox itself, so neither is inferred
---from the name here. Matching a WEAPON_ prefix instead would wrongly catch
---ammo and weapon components, which share the prefix but are not weapons.
---@param items table ox's item list
local function buildWeapons(items)
    local out = {}

    for name, item in pairs(items) do
        if item.weapon then
            -- qb's weapon entries carry a human-readable caliber, which
            -- r14-evidence prints on a casing ("9mm Casing"). ox has no such
            -- field, but it records which ammo the weapon takes, and that ammo
            -- is itself an item with a label. Reading the label keeps the
            -- calibers correct for free instead of hand-maintaining a map of
            -- ammoname to caliber that drifts as soon as a weapon is added.
            local ammo = item.ammoname and items[item.ammoname]

            local entry = {
                name = name,
                label = item.label or name,
                caliber = (ammo and ammo.label) or item.ammoname or 'Unknown',
                ammotype = item.ammoname and item.ammoname:upper() or nil,
                hash = item.hash,
            }

            out[name] = entry
            if item.hash then out[item.hash] = entry end
        end
    end

    return out
end

---Registers Items and Weapons on `shared`.
---
---Both are built on first read and then cached: projecting several hundred
---items on every lookup would be wasteful and the list does not change at
---runtime. Building on first read rather than at boot also sidesteps load
---order, since ox_inventory may not have started when this file runs.
---
---Each builder returns nil while ox is still down, which the registry treats as
---"not ready" and does not cache, so the next read retries instead of pinning
---every future caller to an empty table.
---@param shared table QBCore.Shared
function SomCompatShared.attach(shared)
    SomCompatLazy.provide(shared, 'Items', function()
        local items = oxItems()
        return items and buildItems(items) or nil
    end, {})

    SomCompatLazy.provide(shared, 'Weapons', function()
        local items = oxItems()
        return items and buildWeapons(items) or nil
    end, {})
end
