-- Garage access, listing, retrieval and storage.
--
-- Every callback here re-derives what the player may do from the server's own
-- state. The garage id and vehicle id a client sends are treated as a request
-- to be checked, never as a claim to be trusted: the same rule som-police
-- follows, for the same reason.

local core = exports['som-core']

Garage = {}

-- netId -> { id, garage }. What this session has put on the road, so storing a
-- vehicle can find its row without trusting the client's word for it.
local outByNet = {}

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

---@param player table som-core player
---@param garage table config entry
---@return boolean
local function canAccess(player, garage)
    if not garage.groups then return true end

    -- One map covers jobs and gangs, so a gang garage needs no second code
    -- path. A grade of 0 means any member.
    for name, minGrade in pairs(garage.groups) do
        if player.job and player.job.name == name and (player.job.grade or 0) >= minGrade then
            return true
        end

        if player.gang and player.gang.name == name and (player.gang.grade or 0) >= minGrade then
            return true
        end
    end

    return false
end

Garage.CanAccess = canAccess

---Resolves a garage the player is actually standing at.
---@param source number
---@param garageId any
---@return table|nil garage, string|nil error
local function resolve(source, garageId)
    if type(garageId) ~= 'string' then return nil, 'unknown garage' end

    local garage = Config.Garages[garageId]
    if not garage then return nil, 'unknown garage' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'no ped' end

    -- Measured here. A client claiming to stand at the PD while in Sandy Shores
    -- is standing in Sandy Shores.
    if #(GetEntityCoords(ped) - garage.coords) > 12.0 then
        return nil, 'you are not at that garage'
    end

    return garage
end

-- ---------------------------------------------------------------------------
-- Listing
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:list', function(source, garageId)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local garage, err = resolve(source, garageId)
    if not garage then return { success = false, error = err } end

    if not canAccess(player, garage) then
        return { success = false, error = 'you do not have access here' }
    end

    local rows

    if garage.shared and garage.business then
        -- A shared garage shows the whole fleet, including what colleagues have
        -- out, so an officer can see the pool is empty rather than wondering
        -- why nothing is listed.
        rows = MySQL.query.await([[
            SELECT v.*, c.firstname, c.lastname
            FROM som_vehicles v
            LEFT JOIN som_characters c ON c.citizenid = v.assigned_to
            WHERE v.owner_group = ? AND v.state <> 'impounded'
            ORDER BY v.model, v.plate
        ]], { garage.business })
    else
        -- A personal garage shows only this character's vehicles, and only ones
        -- that are not locked to a group they are no longer part of.
        rows = MySQL.query.await([[
            SELECT * FROM som_vehicles
            WHERE citizenid = ? AND state <> 'impounded'
              AND (group_restricted = 0 OR owner_group = ?)
              AND (garage = ? OR state = 'out')
            ORDER BY model
        ]], { player.citizenid, garage.business or '', garageId })
    end

    local out = {}
    local certs = {}

    -- Certifications are read once for the whole list rather than per row.
    if garage.fleet and GetResourceState('som-police') == 'started' then
        certs = exports['som-police']:getCerts(player.citizenid) or {}
    end

    for _, row in ipairs(rows or {}) do
        local locked, lockReason

        if row.state == 'out' then
            locked = true
            lockReason = row.firstname
                and ('Out with %s %s'):format(row.firstname, row.lastname)
                or 'Currently out'
        end

        -- The certification gate is applied to the LIST as well as to the
        -- retrieval, so an uncertified officer is told why rather than being
        -- refused after clicking.
        local def = Garage.FleetEntry(garage, row.model)
        if def and def.cert and not certs[def.cert] then
            locked = true
            lockReason = 'Certification required'
        end

        out[#out + 1] = {
            id = row.id,
            plate = row.plate,
            model = row.model,
            label = def and def.label or nil,
            fuel = row.fuel,
            body = math.floor((tonumber(row.body) or 0) / 10),
            engine = math.floor((tonumber(row.engine) or 0) / 10),
            state = row.state,
            shared = garage.shared == true and row.citizenid == nil,
            mine = row.citizenid == player.citizenid,
            locked = locked or false,
            lockReason = lockReason,
            -- Sent so the preview can render the real modifications. It is
            -- display data the client already sees on the road.
            props = row.props and json.decode(row.props) or nil,
        }
    end

    -- What this officer could BUY here, as opposed to take. Filtered by the
    -- same certification check, so an uncertified officer is not shown an
    -- interceptor they cannot purchase.
    local catalogue = {}

    if garage.fleet then
        for _, entry in ipairs(Config.Fleets[garage.fleet].vehicles) do
            if entry.price and (not entry.cert or certs[entry.cert]) then
                catalogue[#catalogue + 1] = {
                    model = entry.model,
                    label = entry.label,
                    price = entry.price,
                }
            end
        end
    end

    return {
        success = true,
        label = garage.label,
        garage = garageId,
        vehicles = out,
        catalogue = catalogue,
        -- Cash or card, the same control every other shop offers. som-core owns
        -- the list and validates whatever comes back.
        payment = core:paymentOptions(source),
    }
end)

-- ---------------------------------------------------------------------------
-- Retrieval
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:take', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local garage, err = resolve(source, data.garage)
    if not garage then return { success = false, error = err } end

    if not canAccess(player, garage) then
        return { success = false, error = 'you do not have access here' }
    end

    local row = Vehicles.Get(data.id)
    if not row then return { success = false, error = 'no such vehicle' } end

    -- Ownership is re-derived, never taken from the request. A shared fleet car
    -- belongs to the group; anything else must be this character's.
    local ownedByGroup = row.owner_group and garage.shared and row.owner_group == garage.business
    local ownedByMe = row.citizenid == player.citizenid

    if not ownedByGroup and not ownedByMe then
        return { success = false, error = 'that is not yours' }
    end

    if row.group_restricted == 1 and row.owner_group ~= garage.business then
        return { success = false, error = 'that vehicle stays at its department' }
    end

    if row.state == 'impounded' then
        return { success = false, error = 'that vehicle is impounded' }
    end

    if row.state == 'out' then
        return { success = false, error = 'that vehicle is already out' }
    end

    -- Certification, re-checked against som-police rather than the list.
    local def = Garage.FleetEntry(garage, row.model)

    if def and def.cert then
        if GetResourceState('som-police') ~= 'started' then
            return { success = false, error = 'certifications are unavailable' }
        end

        if not exports['som-police']:hasCert(player.citizenid, def.cert) then
            return { success = false, error = 'you are not certified for that' }
        end
    end

    -- Claimed BEFORE the entity exists, and conditionally on it still being
    -- garaged, so two people taking the last cruiser at once cannot both win.
    if not Vehicles.MarkOut(row.id, player.citizenid) then
        return { success = false, error = 'somebody just took that one' }
    end

    local props = row.props and json.decode(row.props) or nil

    -- Pool cars come out stock. Otherwise one officer's tuning would follow the
    -- car through every subsequent shift.
    if Config.ResetPoolProps and not row.citizenid then props = nil end

    local netId, spawnError = Vehicles.Spawn(row, garage.spawn)

    if not netId then
        -- Put it back. A failed spawn must not leave a car permanently out.
        Vehicles.Store(row.id, garage.business and row.garage or data.garage, nil)
        return { success = false, error = spawnError or 'could not bring it round' }
    end

    outByNet[netId] = { id = row.id, garage = data.garage }

    return {
        success = true,
        netId = netId,
        plate = row.plate,
        props = props,
        fuel = row.fuel,
    }
end)

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:store', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local garage, err = resolve(source, data.garage)
    if not garage then return { success = false, error = err } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return { success = false, error = 'no such vehicle' }
    end

    -- The row id comes from the entity's own statebag, which the server set
    -- when it spawned it. Taking it from the request would let a client store
    -- somebody else's car by pointing at their own.
    local id = Entity(entity).state['som:vehicleId'] or (outByNet[data.netId] and outByNet[data.netId].id)
    if not id then return { success = false, error = 'that is not a stored vehicle' } end

    local row = Vehicles.Get(id)
    if not row then return { success = false, error = 'no such vehicle' } end

    local ownedByGroup = row.owner_group and garage.shared and row.owner_group == garage.business
    if row.citizenid ~= player.citizenid and not ownedByGroup then
        return { success = false, error = 'that is not yours to put away' }
    end

    if #(GetEntityCoords(entity) - garage.coords) > 20.0 then
        return { success = false, error = 'bring it closer to the garage' }
    end

    local stored = Vehicles.Store(id, data.garage, {
        props = type(data.props) == 'table' and data.props or nil,
        fuel = tonumber(data.fuel),
        body = GetVehicleBodyHealth(entity),
        engine = GetVehicleEngineHealth(entity),
    })

    if not stored then
        return { success = false, error = 'that vehicle cannot be stored here' }
    end

    outByNet[data.netId] = nil
    DeleteEntity(entity)

    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Helpers shared with fleet.lua
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Radial
--
-- One entry for every garage. It resolves the garage from where the player is
-- standing rather than taking an id, so the radial never has to know which
-- garages exist and a new one needs no menu change.
--
-- No job filter: personal garages are for everyone, and the PD motor pool is
-- gated by the access check on the list rather than by hiding the button.
-- ---------------------------------------------------------------------------

local function registerRadial()
    if GetResourceState('som-radial') ~= 'started' then return end

    exports['som-radial']:register({
        id = 'garage.open',
        section = 'self',
        label = 'Garage',
        icon = 'garage',
        order = 20,
        export = 'som-garage.openNearest',
    })
end

CreateThread(function()
    Wait(1000)
    registerRadial()
end)

-- Re-registered when som-radial restarts, because it wipes its registry and
-- entries added once at boot would otherwise be gone until this resource is
-- restarted too.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'som-radial' then return end
    Wait(500)
    registerRadial()
end)

---The fleet definition for a model at a garage, if it has one.
---@param garage table
---@param model string
---@return table|nil
function Garage.FleetEntry(garage, model)
    if not garage.fleet then return nil end

    local fleet = Config.Fleets[garage.fleet]
    if not fleet then return nil end

    for _, entry in ipairs(fleet.vehicles) do
        if entry.model == model then return entry end
    end

    return nil
end
