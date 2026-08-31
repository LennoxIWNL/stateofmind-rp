--- Going in and coming out.
---
--- THE SERVER MOVES THE BUCKET. The client is told where the shell is and puts
--- one there, but which bucket a player is in is set here and never asked for.
--- A client that could choose its own bucket could walk into anybody's house.

local core = exports['som-core']

Interior = {}

--- Who is inside what, by server id.
---
--- Server ids are recycled, so this is cleared on drop as well as on leave.
--- som-medical records what happens when a table keyed this way is not: a body
--- left by somebody who logged off kept firing events at their old id until it
--- landed on a different player.
local inside = {}

--- Where a player was standing before they went in, so leaving puts them back
--- rather than at the door's configured coordinate. The two differ when the
--- door coordinate is slightly off, which for a config full of unverified
--- coordinates is most of them.
local returnTo = {}

-- ---------------------------------------------------------------------------
-- Stash
-- ---------------------------------------------------------------------------

--- Registers a property's stash and hands back its name.
---
--- Lazily, inside a validated call, exactly as som-police registers its
--- armoury stashes. THE NAME IS THE ACCESS CONTROL and is built from ids the
--- server resolved, never from anything the client sent, so a name guessed by
--- somebody without a key opens nothing.
---
--- `owner` is nil because access is a property of the KEY, not of one citizen:
--- a co-owner and a tenant must open the same stash the owner does. The guard
--- is that nothing calls this without HasAccess having passed first.
---@param property table
---@return string
local function registerStash(property)
    local name = ('property_%d'):format(property.id)

    exports.ox_inventory:RegisterStash(
        name,
        property.label,
        property.stash_slots,
        property.stash_weight,
        nil,
        nil,
        nil
    )

    return name
end

-- ---------------------------------------------------------------------------
-- Entering
-- ---------------------------------------------------------------------------

lib.callback.register('som-housing:server:enter', function(source, slug)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local property = Properties.BySlug(slug)
    if not property then return { success = false, error = 'no such property' } end

    -- A key, OR a door that police have already forced. Raid.CanEnter is false
    -- for everyone else including the owner's friends, so a breach opens the
    -- property to the raid rather than to the public.
    if not Ownership.HasAccess(player.citizenid, property.id)
        and not Raid.CanEnter(source, property.id) then
        return { success = false, error = 'you do not have a key' }
    end

    local offset = Shells.OffsetFor(property.shell)
    if not offset then
        -- Refused rather than risked. A shell with no measured exit offset would
        -- put the player inside geometry, and being unable to enter is a far
        -- better failure than being stuck under the world.
        return { success = false, error = 'this interior is not available yet' }
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, error = 'no ped' } end

    local here = GetEntityCoords(ped)
    local door = vec3(property.door_x, property.door_y, property.door_z)

    if #(here - door) > Config.Interior.enterDistance then
        return { success = false, error = 'too far from the door' }
    end

    local bucket = Properties.BucketFor(property.id)
    local void = Properties.VoidFor(property.id)

    returnTo[source] = here
    inside[source] = property.id

    SetPlayerRoutingBucket(source, bucket)

    return {
        success = true,
        property = {
            id = property.id,
            slug = property.slug,
            label = property.label,
            shell = property.shell,
        },
        void = { x = void.x, y = void.y, z = void.z },
        offset = offset,
        stash = registerStash(property),
    }
end)

-- ---------------------------------------------------------------------------
-- Leaving
-- ---------------------------------------------------------------------------

---Puts a player back in the world.
---
---Safe to call for somebody who is not inside anything, because that is exactly
---what the drop handler and the resource-stop sweep do.
---@param source number
---@return vector3|nil where they were put
local function sendOut(source)
    local propertyId = inside[source]
    inside[source] = nil

    SetPlayerRoutingBucket(source, 0)

    local back = returnTo[source]
    returnTo[source] = nil

    if back then return back end
    if not propertyId then return nil end

    -- No remembered position, so fall back to the configured door. Happens when
    -- the resource restarted while somebody was indoors.
    local property = Properties.ById(propertyId)
    if not property then return nil end

    return vec3(property.door_x, property.door_y, property.door_z)
end

lib.callback.register('som-housing:server:leave', function(source)
    if not inside[source] then return { success = false, error = 'not inside' } end

    local back = sendOut(source)
    if not back then return { success = false, error = 'nowhere to put you' } end

    return { success = true, coords = { x = back.x, y = back.y, z = back.z } }
end)

---Where a player currently is, for anything that needs to know.
---@param source number
---@return number|nil propertyId
function Interior.PropertyOf(source)
    return inside[source]
end

exports('propertyOf', Interior.PropertyOf)

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

--- A player who disconnects indoors must not come back indoors with no shell
--- around them, and must not leave a stale id in the table for somebody else to
--- inherit when the id is recycled.
AddEventHandler('playerDropped', function()
    local source = source
    if not inside[source] then return end

    inside[source] = nil
    returnTo[source] = nil
end)

--- On stop, everyone indoors goes back to bucket 0 and to their door.
---
--- Without this a restart strands them: the shell is a client-side object that
--- dies with the resource, so they would be left standing in an empty void at
--- the shell coordinates with nothing to walk to.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for source in pairs(inside) do
        local back = sendOut(source)
        if back then
            SetEntityCoords(GetPlayerPed(source), back.x, back.y, back.z, false, false, false, false)
        end
    end
end)

--- A player who logs in while the database still thinks nothing is wrong, but
--- whose last position was inside a property, is put at its door.
---
--- (source, citizenid) with citizenid a STRING. som-medical's handler took this
--- for a table, indexed it, got nil through the string metatable rather than an
--- error, and silently never ran. Type-guarded for that reason.
AddEventHandler('som:server:playerLoaded', function(source, citizenid)
    if type(citizenid) ~= 'string' then return end

    -- Nothing to restore yet: interiors are not persisted across a restart on
    -- purpose, so a player always resumes outside. This handler exists so the
    -- bucket is known-good rather than inherited.
    if GetPlayerRoutingBucket(source) ~= 0 then
        SetPlayerRoutingBucket(source, 0)
    end
end)
