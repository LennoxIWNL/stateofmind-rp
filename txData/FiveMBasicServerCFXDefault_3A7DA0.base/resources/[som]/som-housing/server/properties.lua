--- The property authority.
---
--- Every other server file in this resource reads through this one, the same
--- split som-garage uses with vehicles.lua: one file mints and reconciles rows,
--- and nothing else touches som_properties directly.
---
--- RECONCILIATION, and what it deliberately does not do. Config decides which
--- properties EXIST. A row carries what has happened to that property since,
--- which is ownership, furniture and debt. So a slug added to config gains a
--- row, a slug whose details changed has those details updated in place, and a
--- slug removed from config is retired ONLY IF NOBODY OWNS IT. Deleting a house
--- out from under its owner because somebody tidied a config file is not a
--- trade this system is willing to make.

Properties = {}

local cache = {}

---Everything the seed knows about one config entry, resolved through the tier
---and warehouse tables so callers never have to.
---
---A warehouse takes its capacity from Config.Warehouses and everything else
---from its tier, because size is the only thing that varies between them.
---@param entry table
---@return table
local function resolve(entry)
    local tier = Config.Tiers[entry.tier] or Config.Tiers.standard
    local slots, weight = tier.stashSlots, tier.stashWeight

    if entry.type == 'warehouse' and entry.warehouse then
        local size = Config.Warehouses[entry.warehouse]
        if size then
            slots, weight = size.stashSlots, size.stashWeight
        end
    end

    return {
        slug        = entry.slug,
        label       = entry.label,
        type        = entry.type or 'house',
        tier        = entry.tier or 'standard',
        shell       = entry.shell,
        door        = entry.door,
        price       = math.floor(entry.price or 0),
        stashSlots  = slots,
        stashWeight = weight,
        realtorOnly = tier.realtorOnly and 1 or 0,
    }
end

---Inserts a property, or updates the parts of it config owns.
---
---The UPDATE deliberately does not touch `for_sale`. That is runtime state: a
---property is not for sale because somebody bought it, and re-importing a
---config must not put it back on the market with an owner still living in it.
---@param entry table
local function seedProperty(entry)
    local p = resolve(entry)

    local existing = MySQL.single.await(
        'SELECT id FROM som_properties WHERE slug = ?', { p.slug })

    if existing then
        MySQL.update.await([[
            UPDATE som_properties
            SET label = ?, type = ?, tier = ?, shell = ?,
                door_x = ?, door_y = ?, door_z = ?, door_heading = ?,
                price = ?, stash_slots = ?, stash_weight = ?, realtor_only = ?
            WHERE id = ?
        ]], {
            p.label, p.type, p.tier, p.shell,
            p.door.x, p.door.y, p.door.z, p.door.w,
            p.price, p.stashSlots, p.stashWeight, p.realtorOnly,
            existing.id,
        })

        cache[p.slug] = existing.id
        return
    end

    local id = MySQL.insert.await([[
        INSERT INTO som_properties
            (slug, label, type, tier, shell,
             door_x, door_y, door_z, door_heading,
             price, stash_slots, stash_weight, for_sale, realtor_only)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
    ]], {
        p.slug, p.label, p.type, p.tier, p.shell,
        p.door.x, p.door.y, p.door.z, p.door.w,
        p.price, p.stashSlots, p.stashWeight, p.realtorOnly,
    })

    cache[p.slug] = id
end

---Removes rows whose slug is no longer in config, and refuses to remove owned
---ones.
---
---An owned property that vanished from config is a mistake somebody made in a
---config file, and the loud version of that is a line in the console. The quiet
---version is a player logging in to find their house and everything stored in
---it gone, with the foreign keys having cascaded the furniture and the debt
---away too.
local function retireProperties()
    local configured = {}
    for _, entry in ipairs(Config.Properties) do
        configured[entry.slug] = true
    end

    local rows = MySQL.query.await([[
        SELECT p.id, p.slug, COUNT(o.citizenid) AS owners
        FROM som_properties p
        LEFT JOIN som_property_owners o ON o.property_id = p.id
        GROUP BY p.id, p.slug
    ]]) or {}

    for _, row in ipairs(rows) do
        if not configured[row.slug] then
            if tonumber(row.owners) > 0 then
                print(('[som-housing] %s is gone from config but still has %d owner(s). Kept. Restore the config entry or transfer it before removing.')
                    :format(row.slug, row.owners))
            else
                MySQL.update.await('DELETE FROM som_properties WHERE id = ?', { row.id })
            end
        end
    end
end

---The property row for a slug, or nil.
---@param slug string
---@return table|nil
function Properties.BySlug(slug)
    if type(slug) ~= 'string' then return nil end
    return MySQL.single.await('SELECT * FROM som_properties WHERE slug = ?', { slug })
end

---The property row for an id, or nil.
---@param id number
---@return table|nil
function Properties.ById(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM som_properties WHERE id = ?', { id })
end

---The routing bucket a property's interior lives in.
---
---Derived rather than stored, so it cannot drift from the property it belongs
---to. See Config.BucketBase for why the range is where it is.
---@param propertyId number
---@return number|nil
function Properties.BucketFor(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end
    return Config.BucketBase + propertyId
end

---Where a property's shell is spawned inside its bucket.
---
---Spaced by property id so two shells can never occupy the same coordinates
---even though their buckets already keep them apart.
---@param propertyId number
---@return vector3|nil
function Properties.VoidFor(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end

    local origin = Config.Void.origin
    return vec3(origin.x + (propertyId * Config.Void.spacing), origin.y, origin.z)
end

exports('getProperty', Properties.ById)
exports('getPropertyBySlug', Properties.BySlug)

CreateThread(function()
    -- After som-core has confirmed the schema is present, same as som-garage.
    Wait(3000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_properties LIMIT 1')
    end)

    if not ok then
        print('[som-housing] som_properties is missing. Import setup.sql.')
        return
    end

    -- Retire first, then seed. The other order would delete a row this boot
    -- just created, because a slug removed from config is absent from the
    -- seed loop and therefore looks retired either way.
    retireProperties()

    for _, entry in ipairs(Config.Properties) do
        seedProperty(entry)
    end

    print(('[som-housing] %d propert%s available.')
        :format(#Config.Properties, #Config.Properties == 1 and 'y' or 'ies'))
end)
