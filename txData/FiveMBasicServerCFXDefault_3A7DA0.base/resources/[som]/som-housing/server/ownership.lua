--- Who owns what, who holds a key, and buying outright.
---
--- Reads through Properties for anything about the property itself. This file
--- owns som_property_owners and nothing else.
---
--- MORTGAGES ARE NOT HERE. Buying outright needs nobody else online and is the
--- whole of this file. Financing needs a realtor and lives in server/finance.lua,
--- which is the shape the owner asked for: the fast path is always open and the
--- cheaper one costs a conversation with another player.

local core = exports['som-core']

Ownership = {}
---Thousands separators, for text a player reads.
---
---Local rather than shared: it is two lines, and a formatting helper crossing
---a resource boundary is a dependency nobody wants to discover later.
---@param n number
---@return string
local function comma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end


-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

---Every role a citizen holds on a property, or nil.
---@param citizenid string
---@param propertyId number
---@return string|nil role
function Ownership.RoleOf(citizenid, propertyId)
    if type(citizenid) ~= 'string' then return nil end
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end

    return MySQL.scalar.await(
        'SELECT role FROM som_property_owners WHERE property_id = ? AND citizenid = ?',
        { propertyId, citizenid })
end

---Whether a citizen may open a property at all.
---
---Every role opens the door. The difference between them is what else they may
---do: only an owner can sell, grant keys or take a mortgage.
---@param citizenid string
---@param propertyId number
---@return boolean
function Ownership.HasAccess(citizenid, propertyId)
    return Ownership.RoleOf(citizenid, propertyId) ~= nil
end

---The citizenid of the owner, or nil if nobody has bought it.
---@param propertyId number
---@return string|nil
function Ownership.OwnerOf(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end

    return MySQL.scalar.await(
        "SELECT citizenid FROM som_property_owners WHERE property_id = ? AND role = 'owner' LIMIT 1",
        { propertyId })
end

---Every property a citizen holds any role on, newest first.
---@param citizenid string
---@return table
function Ownership.ListFor(citizenid)
    if type(citizenid) ~= 'string' then return {} end

    return MySQL.query.await([[
        SELECT p.id, p.slug, p.label, p.type, p.tier, p.price,
               p.door_x, p.door_y, p.door_z,
               o.role, o.granted_at
        FROM som_property_owners o
        JOIN som_properties p ON p.id = o.property_id
        WHERE o.citizenid = ?
        ORDER BY o.granted_at DESC
    ]], { citizenid }) or {}
end

---How many properties a citizen OWNS, ignoring keys they merely hold.
---
---Counting roles rather than rows is the point: being given a key to six
---houses must not stop somebody buying their first one.
---@param citizenid string
---@return number
function Ownership.OwnedCount(citizenid)
    if type(citizenid) ~= 'string' then return 0 end

    return tonumber(MySQL.scalar.await(
        "SELECT COUNT(*) FROM som_property_owners WHERE citizenid = ? AND role = 'owner'",
        { citizenid })) or 0
end

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

---Records a role. Used by purchase, by key sharing and by the mortgage path.
---
---INSERT ... ON DUPLICATE KEY so re-granting a key somebody already holds
---updates it rather than erroring, and so a tenant who buys the place they were
---renting becomes its owner instead of holding two roles at once.
---@param propertyId number
---@param citizenid string
---@param role string
---@param grantedBy string|nil
---@return boolean
function Ownership.Grant(propertyId, citizenid, role, grantedBy)
    propertyId = tonumber(propertyId)
    if not propertyId or type(citizenid) ~= 'string' then return false end
    if role ~= 'owner' and role ~= 'co_owner' and role ~= 'tenant' then return false end

    local ok = pcall(function()
        MySQL.insert.await([[
            INSERT INTO som_property_owners (property_id, citizenid, role, granted_by)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE role = VALUES(role), granted_by = VALUES(granted_by)
        ]], { propertyId, citizenid, role, grantedBy })
    end)

    return ok
end

---Removes a role.
---@param propertyId number
---@param citizenid string
---@return boolean
function Ownership.Revoke(propertyId, citizenid)
    propertyId = tonumber(propertyId)
    if not propertyId or type(citizenid) ~= 'string' then return false end

    local affected = MySQL.update.await(
        'DELETE FROM som_property_owners WHERE property_id = ? AND citizenid = ?',
        { propertyId, citizenid })

    return (affected or 0) > 0
end

-- ---------------------------------------------------------------------------
-- Buying outright
-- ---------------------------------------------------------------------------

--- The order here is som-garage's fleet purchase, kept deliberately.
---
--- The client sends a slug and an account name. It does not send a price, does
--- not send whether the property is for sale, and cannot send a property it is
--- not standing next to. Every one of those is re-read server side.
lib.callback.register('som-housing:server:buy', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    -- Re-resolved from the database by slug. Never from anything the client sent.
    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end

    if property.for_sale ~= 1 then
        return { success = false, error = 'not for sale' }
    end

    -- The expensive tier is the realtor's job and cannot be bought outright at
    -- all. Refused here rather than hidden in the UI, because the UI is a
    -- filter and this is the rule.
    if property.realtor_only == 1 then
        return { success = false, error = 'this one is sold through an estate agent' }
    end

    -- MEASURED SERVER SIDE, from the server's own view of the ped. The client
    -- picking which property it is near buys it a menu, never a purchase.
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, error = 'no ped' } end

    local here = GetEntityCoords(ped)
    local door = vec3(property.door_x, property.door_y, property.door_z)

    if #(here - door) > Config.Purchase.distance then
        return { success = false, error = 'too far from the property' }
    end

    if Ownership.OwnerOf(property.id) then
        return { success = false, error = 'somebody already owns it' }
    end

    if Ownership.OwnedCount(player.citizenid) >= Config.Purchase.maxOwned then
        return { success = false, error = ('you already own %d properties'):format(Config.Purchase.maxOwned) }
    end

    -- payWith validates the account against som-core's payable list, so a
    -- client asking to pay from 'dirty' is refused there rather than here.
    local paid, payErr = core:payWith(source, data.account, property.price,
        ('property:%s'):format(property.slug))

    if not paid then
        return { success = false, error = payErr or 'could not pay' }
    end

    if not Ownership.Grant(property.id, player.citizenid, 'owner', nil) then
        -- Refunded in full. The alternative is taking the money and handing
        -- back nothing, which is the failure som-garage refunds against too.
        core:addMoney(source, data.account, property.price, 'property-refund')
        return { success = false, error = 'could not register the sale' }
    end

    MySQL.update.await('UPDATE som_properties SET for_sale = 0 WHERE id = ?', { property.id })

    return { success = true, label = property.label, price = property.price }
end)

exports('hasAccess', Ownership.HasAccess)
exports('ownerOf', Ownership.OwnerOf)
exports('listFor', Ownership.ListFor)

--- Does this citizen own a warehouse, and where is it.
---
--- Exported for the drug system that does not exist yet. It is the entire
--- interface housing intends to offer it: growing asks what somebody owns and
--- housing answers, so neither has to know how the other stores anything.
---@param citizenid string
---@return table
exports('ownedWarehouses', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end

    return MySQL.query.await([[
        SELECT p.id, p.slug, p.label, p.tier
        FROM som_property_owners o
        JOIN som_properties p ON p.id = o.property_id
        WHERE o.citizenid = ? AND o.role = 'owner' AND p.type = 'warehouse'
    ]], { citizenid }) or {}
end)

--- What a door says about itself before you commit to anything.
---
--- Deliberately thin. It reports whether it is for sale, what it costs and
--- whether you hold a key, and nothing about WHO owns it: a stranger being able
--- to read an owner's name off every door in the city is a stalking tool, not a
--- feature.
lib.callback.register('som-housing:server:inspect', function(source, slug)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local property = Properties.BySlug(slug)
    if not property then return { success = false, error = 'no such property' } end

    local role = Ownership.RoleOf(player.citizenid, property.id)
    local owner = Ownership.OwnerOf(property.id)

    if role then
        return {
            success = true, owned = true, role = role,
            text = ('%s. You hold this as %s.'):format(property.label,
                role == 'owner' and 'the owner' or role:gsub('_', '-')),
        }
    end

    if owner then
        return { success = true, owned = true, text = ('%s. Already sold.'):format(property.label) }
    end

    if property.realtor_only == 1 then
        return {
            success = true, owned = false, forSale = false,
            text = ('%s. Sold through an estate agent only.'):format(property.label),
        }
    end

    return {
        success = true, owned = false, forSale = property.for_sale == 1,
        price = property.price,
        label = property.label,
        -- The accounts this player could actually pay from, resolved server
        -- side. The client renders them and sends back a NAME, which payWith
        -- re-validates, so an edited list buys nothing.
        accounts = core:paymentOptions(source),
        text = ('%s. For sale at $%s.'):format(property.label, comma(property.price)),
    }
end)

-- ---------------------------------------------------------------------------
-- Keys
-- ---------------------------------------------------------------------------

--- Handing somebody a key.
---
--- ONLY THE OWNER, and only to somebody standing next to them. Both halves
--- matter: a key granted from across the map is a key granted to a citizenid
--- somebody typed, and being able to type an id is not the same as knowing the
--- person.
lib.callback.register('som-housing:server:grantKey', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local owner = core:getPlayer(source)
    if not owner then return { success = false, error = 'not loaded' } end

    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end

    if Ownership.RoleOf(owner.citizenid, property.id) ~= 'owner' then
        return { success = false, error = 'only the owner can hand out keys' }
    end

    local targetSource = tonumber(data.target)
    if not targetSource then return { success = false, error = 'no one selected' } end

    local target = core:getPlayer(targetSource)
    if not target then return { success = false, error = 'they are not here' } end

    if target.citizenid == owner.citizenid then
        return { success = false, error = 'you already have a key' }
    end

    local ownerPed, targetPed = GetPlayerPed(source), GetPlayerPed(targetSource)
    if not ownerPed or ownerPed == 0 or not targetPed or targetPed == 0 then
        return { success = false, error = 'no ped' }
    end

    if #(GetEntityCoords(ownerPed) - GetEntityCoords(targetPed)) > Config.Keys.distance then
        return { success = false, error = 'they need to be next to you' }
    end

    local role = data.role == 'tenant' and 'tenant' or 'co_owner'

    if not Ownership.Grant(property.id, target.citizenid, role, owner.citizenid) then
        return { success = false, error = 'could not hand over the key' }
    end

    TriggerClientEvent('som:client:notify', targetSource,
        ('You have been given a key to %s'):format(property.label), 'success')

    return { success = true, label = property.label, name = target.charinfo and
        ('%s %s'):format(target.charinfo.firstname, target.charinfo.lastname) or 'them' }
end)

--- Taking one back.
---
--- No distance check, deliberately. Revoking a key is something you should be
--- able to do the moment you decide to, and requiring the other person to stand
--- next to you while you do it is exactly backwards.
lib.callback.register('som-housing:server:revokeKey', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local owner = core:getPlayer(source)
    if not owner then return { success = false, error = 'not loaded' } end

    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end

    if Ownership.RoleOf(owner.citizenid, property.id) ~= 'owner' then
        return { success = false, error = 'only the owner can take keys back' }
    end

    if type(data.citizenid) ~= 'string' then return { success = false, error = 'no key selected' } end

    if data.citizenid == owner.citizenid then
        return { success = false, error = 'you cannot revoke your own ownership' }
    end

    if not Ownership.Revoke(property.id, data.citizenid) then
        return { success = false, error = 'they do not hold a key' }
    end

    return { success = true }
end)

---Who holds a key, for the owner to look at.
lib.callback.register('som-housing:server:keys', function(source, slug)
    local owner = core:getPlayer(source)
    if not owner then return { success = false, error = 'not loaded' } end

    local property = Properties.BySlug(slug)
    if not property then return { success = false, error = 'no such property' } end

    if Ownership.RoleOf(owner.citizenid, property.id) ~= 'owner' then
        return { success = false, error = 'not yours' }
    end

    -- Joined to som_characters so the list shows names rather than ids. An
    -- owner looking at their own keyring is the one place a name is the right
    -- thing to show, which is why inspect does not.
    local rows = MySQL.query.await([[
        SELECT o.citizenid, o.role, o.granted_at,
               c.firstname, c.lastname
        FROM som_property_owners o
        LEFT JOIN som_characters c ON c.citizenid = o.citizenid
        WHERE o.property_id = ? AND o.role <> 'owner'
        ORDER BY o.granted_at ASC
    ]], { property.id }) or {}

    return { success = true, keys = rows, label = property.label }
end)
