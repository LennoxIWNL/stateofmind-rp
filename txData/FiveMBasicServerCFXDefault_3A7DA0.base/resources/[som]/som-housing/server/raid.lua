--- Warrants and raids.
---
--- A WARRANT IS AUTHORITY, NOT A KEY. Nothing in this file unlocks a door. A
--- warrant records that an entry was lawful; the entry itself is always
--- physical, and works exactly as well without one.
---
--- That is the whole design and it is deliberate. Every surveyed script makes
--- the warrant open the door, which turns a roleplay beat into a permission
--- check and removes the only interesting decision in a raid: whether to go in
--- anyway. Here you always can, and it is written down that you did.

local core = exports['som-core']

Raid = {}

--- Doors forced open, and until when.
---
--- In memory rather than a column, because it is a fact about right now and
--- should not survive a restart. A raid that is still in progress when the
--- server goes down is over.
local breached = {}

---@param source number
---@return table|nil player, table|nil job
local function officer(source)
    local player = core:getPlayer(source)
    if not player then return nil end

    local job = player.job
    -- Read off the player rather than through core:hasJob, which is client
    -- only. See the same note in finance.lua.
    if not job or job.name ~= Config.Raid.job or not job.onduty then return nil end

    return player, job
end

-- ---------------------------------------------------------------------------
-- Warrants
-- ---------------------------------------------------------------------------

---An unexpired, granted warrant on a property, or nil.
---@param propertyId number
---@return table|nil
function Raid.ActiveWarrant(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end

    return MySQL.single.await([[
        SELECT * FROM som_property_warrants
        WHERE property_id = ? AND status = 'granted' AND expires_at > NOW()
        ORDER BY granted_at DESC LIMIT 1
    ]], { propertyId })
end

lib.callback.register('som-housing:server:requestWarrant', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player = officer(source)
    if not player then return { success = false, error = 'police only, on duty' } end

    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end

    local reason = type(data.reason) == 'string' and data.reason or ''
    if #reason < 8 then return { success = false, error = 'a reason is required' } end
    if #reason > 255 then reason = reason:sub(1, 255) end

    if Raid.ActiveWarrant(property.id) then
        return { success = false, error = 'there is already a warrant on that address' }
    end

    local id = MySQL.insert.await([[
        INSERT INTO som_property_warrants (property_id, requested_by, reason, status)
        VALUES (?, ?, ?, 'requested')
    ]], { property.id, player.citizenid, reason })

    return { success = true, id = id, label = property.label }
end)

--- Approving.
---
--- A DIFFERENT PERSON, and a supervisor. Both checks matter: without the first
--- an officer signs their own warrants, and without the second every constable
--- can.
lib.callback.register('som-housing:server:approveWarrant', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player, job = officer(source)
    if not player then return { success = false, error = 'police only, on duty' } end

    -- job.grade is a NUMBER on this framework, not a table. Indexing it would
    -- raise 'attempt to index a number value' the first time a sergeant tried
    -- to approve anything.
    if (tonumber(job.grade) or 0) < Config.Raid.approveGrade then
        return { success = false, error = 'not senior enough to approve a warrant' }
    end

    local warrant = MySQL.single.await(
        "SELECT * FROM som_property_warrants WHERE id = ? AND status = 'requested'",
        { tonumber(data.id) })

    if not warrant then return { success = false, error = 'no such request' } end

    if warrant.requested_by == player.citizenid then
        return { success = false, error = 'somebody else has to approve your own request' }
    end

    local approve = data.approve ~= false

    if not approve then
        MySQL.update.await("UPDATE som_property_warrants SET status = 'refused', approved_by = ? WHERE id = ?",
            { player.citizenid, warrant.id })
        return { success = true, granted = false }
    end

    MySQL.update.await([[
        UPDATE som_property_warrants
        SET status = 'granted', approved_by = ?, granted_at = NOW(),
            expires_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE id = ?
    ]], { player.citizenid, Config.Raid.warrantMinutes, warrant.id })

    return { success = true, granted = true, minutes = Config.Raid.warrantMinutes }
end)

---Warrants waiting on a decision, for the MDT to show.
lib.callback.register('som-housing:server:warrants', function(source)
    if not officer(source) then return { success = false, error = 'police only' } end

    local rows = MySQL.query.await([[
        SELECT w.id, w.reason, w.status, w.created_at, w.expires_at,
               p.label, p.slug
        FROM som_property_warrants w
        JOIN som_properties p ON p.id = w.property_id
        WHERE w.status IN ('requested', 'granted')
        ORDER BY w.created_at DESC
        LIMIT 50
    ]]) or {}

    return { success = true, warrants = rows, approveGrade = Config.Raid.approveGrade }
end)

-- ---------------------------------------------------------------------------
-- Breaching
-- ---------------------------------------------------------------------------

---Whether a property is currently forced open, for whoever wants in.
---@param propertyId number
---@return boolean
function Raid.IsBreached(propertyId)
    local until_ = breached[propertyId]
    if not until_ then return false end

    if os.time() >= until_ then
        breached[propertyId] = nil
        return false
    end

    return true
end

--- Going through the door.
---
--- Records the raid WHETHER OR NOT there was a warrant, because the record of
--- an unlawful entry is the point of recording them at all. The door opens
--- either way; what changes is what the log says and, later, what the MDT will
--- accept as admissible.
lib.callback.register('som-housing:server:breach', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local player = officer(source)
    if not player then return { success = false, error = 'police only, on duty' } end

    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end

    local method = data.method == 'lockpick' and 'lockpick' or 'ram'
    local tool = Config.Raid[method]

    -- The item is re-checked here rather than trusted from the client, which
    -- only used it to decide which option to show.
    local count = exports.ox_inventory:GetItemCount(source, tool.item)
    if not count or count < 1 then
        return { success = false, error = ('you need a %s'):format(tool.item:gsub('_', ' ')) }
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, error = 'no ped' } end

    local door = vec3(property.door_x, property.door_y, property.door_z)
    if #(GetEntityCoords(ped) - door) > Config.Interior.enterDistance then
        return { success = false, error = 'too far from the door' }
    end

    local warrant = Raid.ActiveWarrant(property.id)
    local lawful = warrant ~= nil

    breached[property.id] = os.time() + (Config.Raid.breachOpenMinutes * 60)

    MySQL.insert.await([[
        INSERT INTO som_property_raids (property_id, officer, warrant_id, method, lawful)
        VALUES (?, ?, ?, ?, ?)
    ]], { property.id, player.citizenid, warrant and warrant.id or nil, method, lawful and 1 or 0 })

    if warrant then
        MySQL.update.await("UPDATE som_property_warrants SET status = 'served', served_at = NOW() WHERE id = ?",
            { warrant.id })
    end

    -- The owner is told their door went in, if they are here to be told. A ram
    -- is loud; a lockpick is not, which is the trade between the two.
    if tool.alertsOwner then
        local ownerCid = Ownership.OwnerOf(property.id)
        local owner = ownerCid and core:getPlayerByCitizenId(ownerCid)

        if owner then
            TriggerClientEvent('som:client:notify', owner.source,
                ('Someone has forced the door at %s'):format(property.label), 'error')
        end
    end

    TriggerEvent('som-housing:server:raidLogged', {
        property = property.label,
        officer = player.citizenid,
        method = method,
        lawful = lawful,
    })

    return { success = true, lawful = lawful, minutes = Config.Raid.breachOpenMinutes }
end)

exports('isBreached', Raid.IsBreached)
exports('activeWarrant', Raid.ActiveWarrant)

---Whether this player may walk into this property without a key.
---
---Only while it is breached, and only for on-duty police. A forced door is not
---a public door: the raid opens it for the people conducting the raid.
---@param source number
---@param propertyId number
---@return boolean
function Raid.CanEnter(source, propertyId)
    if not Raid.IsBreached(propertyId) then return false end
    return officer(source) ~= nil
end
