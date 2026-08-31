--- Furniture: what is in a room, and who may put it there.
---
--- OFFSETS ARE RELATIVE TO THE SHELL ORIGIN. The shell is spawned somewhere
--- different in every bucket, so a world coordinate would be correct exactly
--- once and wrong for every other property using the same model.
---
--- The client places a ghost and reports where it ended up. Everything about
--- whether that is allowed is decided here: the model against a whitelist, the
--- distance against a maximum, the count against a cap, and the right to place
--- anything at all against the key the player holds.

local core = exports['som-core']

Furniture = {}

---The catalogue entry for a model, or nil if it is not placeable.
---
---A WHITELIST LOOKUP, and the only thing that decides whether a model is
---allowed. A client that could name its own model could place a locked door or
---a wall inside a room only it can reach.
---@param model string
---@return table|nil
local function catalogued(model)
    if type(model) ~= 'string' then return nil end

    for _, entry in ipairs(Config.Furniture.catalogue) do
        if entry.model == model then return entry end
    end

    return nil
end

---Everything placed in a property.
---@param propertyId number
---@return table
function Furniture.For(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return {} end

    return MySQL.query.await([[
        SELECT id, model, off_x, off_y, off_z, rot_x, rot_y, rot_z
        FROM som_property_furniture WHERE property_id = ?
    ]], { propertyId }) or {}
end

exports('furnitureFor', Furniture.For)

---Whether this player may rearrange this property.
---
---An owner or a co-owner. A tenant lives there and a raiding officer is
---standing in it, and neither of those is a reason to be allowed to redecorate.
---@param citizenid string
---@param propertyId number
---@return boolean
local function mayDecorate(citizenid, propertyId)
    local role = Ownership.RoleOf(citizenid, propertyId)
    return role == 'owner' or role == 'co_owner'
end

lib.callback.register('som-housing:server:furniture', function(source)
    local propertyId = Interior.PropertyOf(source)
    if not propertyId then return { success = false, error = 'not inside anything' } end

    return {
        success = true,
        furniture = Furniture.For(propertyId),
        catalogue = Config.Furniture.catalogue,
        canDecorate = mayDecorate((core:getPlayer(source) or {}).citizenid, propertyId),
    }
end)

--- Placing.
---
--- THE PROPERTY COMES FROM THE SERVER'S OWN RECORD of where this player is, not
--- from anything the client sent. There is no propertyId in the payload at all,
--- which is what stops somebody furnishing a house they are not standing in.
lib.callback.register('som-housing:server:placeFurniture', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local propertyId = Interior.PropertyOf(source)
    if not propertyId then return { success = false, error = 'not inside anything' } end

    if not mayDecorate(player.citizenid, propertyId) then
        return { success = false, error = 'you cannot rearrange this place' }
    end

    if not catalogued(data.model) then
        return { success = false, error = 'that is not something you can place' }
    end

    local ox, oy, oz = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not ox or not oy or not oz then return { success = false, error = 'bad position' } end

    -- NaN survives tonumber and compares false against everything, so it would
    -- slip past a range check written only as `> max`. This is the same guard
    -- som-inventory puts on a throw coordinate.
    if ox ~= ox or oy ~= oy or oz ~= oz then return { success = false, error = 'bad position' } end

    local reach = math.sqrt(ox * ox + oy * oy + oz * oz)
    if reach > Config.Furniture.maxOffset then
        return { success = false, error = 'too far from the room' }
    end

    local count = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM som_property_furniture WHERE property_id = ?', { propertyId })) or 0

    if count >= Config.Furniture.maxPerProperty then
        return { success = false, error = ('a property holds %d pieces at most'):format(
            Config.Furniture.maxPerProperty) }
    end

    local rz = tonumber(data.heading) or 0.0
    if rz ~= rz then rz = 0.0 end

    local id = MySQL.insert.await([[
        INSERT INTO som_property_furniture
            (property_id, model, off_x, off_y, off_z, rot_x, rot_y, rot_z, placed_by)
        VALUES (?, ?, ?, ?, ?, 0.0, 0.0, ?, ?)
    ]], { propertyId, data.model, ox, oy, oz, rz % 360.0, player.citizenid })

    return { success = true, id = id }
end)

--- Taking a piece back out.
---
--- Scoped by property_id in the DELETE itself rather than checked beforehand,
--- so a furniture id belonging to a different house cannot be removed by
--- guessing the number.
lib.callback.register('som-housing:server:removeFurniture', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local propertyId = Interior.PropertyOf(source)
    if not propertyId then return { success = false, error = 'not inside anything' } end

    if not mayDecorate(player.citizenid, propertyId) then
        return { success = false, error = 'you cannot rearrange this place' }
    end

    local id = tonumber(data.id)
    if not id then return { success = false, error = 'nothing selected' } end

    local affected = MySQL.update.await(
        'DELETE FROM som_property_furniture WHERE id = ? AND property_id = ?',
        { id, propertyId })

    if (affected or 0) < 1 then return { success = false, error = 'not in this property' } end

    return { success = true }
end)
