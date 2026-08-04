-- The som_vehicles authority.
--
-- This is the ONLY place a vehicle row is created. Everything that wants to
-- give somebody a car (the dealership, the police fleet, an admin command)
-- comes through createVehicle, so plate uniqueness, the statebag wiring and the
-- ownership shape are decided once instead of in every caller.
--
-- Nothing here spawns an entity. Creating a row and putting a car on the road
-- are separate acts: a vehicle exists whether or not it is currently out.

local core = exports['som-core']

Vehicles = {}

-- ---------------------------------------------------------------------------
-- Plates
-- ---------------------------------------------------------------------------

---@param prefix string
---@return string|nil an unused plate, or nil if one could not be found
function Vehicles.GeneratePlate(prefix)
    prefix = prefix or Config.PlatePrefix

    for _ = 1, 40 do
        -- GTA plates cap at 8 characters, so the prefix plus the digits IS the
        -- whole plate. A longer prefix silently truncates the number.
        local digits = 8 - #prefix
        local max = math.floor(10 ^ digits) - 1
        local plate = ('%s%0' .. digits .. 'd'):format(prefix, math.random(0, max))

        local taken = MySQL.scalar.await(
            'SELECT 1 FROM som_vehicles WHERE plate = ?', { plate })

        if not taken then return plate end
    end

    -- Returning a duplicate would hand somebody else's car over, so fail.
    return nil
end

-- ---------------------------------------------------------------------------
-- Creation
-- ---------------------------------------------------------------------------

---Creates a vehicle row. The one path that mints a vehicle.
---@param data table {
---   citizenid?      personal owner
---   ownerGroup?     business or gang that owns it
---   groupRestricted? only retrievable at that group's garage
---   model           spawn name
---   garage          where it is parked
---   props?          ox_lib vehicle properties
---   price?          what was paid, for later refunds
---   platePrefix?
--- }
---@return table|nil row, string|nil error
function Vehicles.Create(data)
    if type(data) ~= 'table' then return nil, 'invalid request' end
    if type(data.model) ~= 'string' or data.model == '' then return nil, 'no model' end

    -- A vehicle nobody owns is a vehicle nothing can ever retrieve, so refuse
    -- rather than create an orphan row.
    if not data.citizenid and not data.ownerGroup then
        return nil, 'a vehicle needs an owner'
    end

    local plate = data.plate or Vehicles.GeneratePlate(data.platePrefix)
    if not plate then return nil, 'could not issue a plate' end

    local id = MySQL.insert.await([[
        INSERT INTO som_vehicles
            (citizenid, owner_group, group_restricted, plate, model, props,
             garage, state, purchase_price)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'garaged', ?)
    ]], {
        data.citizenid,
        data.ownerGroup,
        data.groupRestricted and 1 or 0,
        plate,
        data.model:lower(),
        data.props and json.encode(data.props) or nil,
        data.garage or 'impound',
        math.floor(tonumber(data.price) or 0),
    })

    if not id then return nil, 'could not store the vehicle' end

    return { id = id, plate = plate, model = data.model:lower() }
end

exports('createVehicle', Vehicles.Create)
exports('generatePlate', Vehicles.GeneratePlate)

-- ---------------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------------

---@param id number
---@return table|nil
function Vehicles.Get(id)
    return MySQL.single.await('SELECT * FROM som_vehicles WHERE id = ?', { tonumber(id) or 0 })
end

---@param plate string
---@return table|nil
function Vehicles.GetByPlate(plate)
    if type(plate) ~= 'string' then return nil end
    return MySQL.single.await('SELECT * FROM som_vehicles WHERE plate = ?', { plate })
end

exports('getVehicle', Vehicles.Get)
exports('getVehicleByPlate', Vehicles.GetByPlate)

-- ---------------------------------------------------------------------------
-- State transitions
-- ---------------------------------------------------------------------------

---Marks a vehicle as out, and records who took it.
---
---`assigned_to` matters for pool cars: it is how a department knows which
---officer has which cruiser, and what a force-return would read.
---@param id number
---@param citizenid string
---@return boolean
function Vehicles.MarkOut(id, citizenid)
    -- The state check is part of the UPDATE rather than a read followed by a
    -- write, so two officers clicking the last cruiser at the same moment
    -- cannot both succeed. Whichever query lands second matches no rows.
    local affected = MySQL.update.await([[
        UPDATE som_vehicles
        SET state = 'out', assigned_to = ?, taken_at = CURRENT_TIMESTAMP
        WHERE id = ? AND state = 'garaged'
    ]], { citizenid, id })

    return affected == 1
end

---Puts a vehicle away, storing its condition.
---@param id number
---@param garage string
---@param condition table|nil { props, fuel, body, engine }
---@return boolean
function Vehicles.Store(id, garage, condition)
    condition = type(condition) == 'table' and condition or {}

    -- An impounded vehicle is som-police's business. Storing one here would
    -- quietly release it without the fee being paid, so the state guard is the
    -- boundary between the two resources.
    local affected = MySQL.update.await([[
        UPDATE som_vehicles
        SET state = 'garaged', garage = ?, assigned_to = NULL, taken_at = NULL,
            props  = COALESCE(?, props),
            fuel   = COALESCE(?, fuel),
            body   = COALESCE(?, body),
            engine = COALESCE(?, engine)
        WHERE id = ? AND state <> 'impounded'
    ]], {
        garage,
        condition.props and json.encode(condition.props) or nil,
        condition.fuel and math.floor(condition.fuel) or nil,
        condition.body and math.floor(condition.body) or nil,
        condition.engine and math.floor(condition.engine) or nil,
        id,
    })

    return affected == 1
end

exports('markVehicleOut', Vehicles.MarkOut)
exports('storeVehicle', Vehicles.Store)

-- ---------------------------------------------------------------------------
-- Spawning
--
-- Server side, matching the pattern som-rentals and som-police already use, so
-- there is one way a vehicle reaches the world.
-- ---------------------------------------------------------------------------

---@param row table a som_vehicles row
---@param spawn vector4
---@return number|nil netId, string|nil error
function Vehicles.Spawn(row, spawn)
    local entity = CreateVehicle(joaat(row.model), spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    -- The entity is not addressable the instant it is created.
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end

    if not DoesEntityExist(entity) then return nil, 'the vehicle could not be brought round' end

    SetVehicleNumberPlateText(entity, row.plate)

    local state = Entity(entity).state

    -- ox_inventory keys glovebox and trunk stashes on som_vehicles.id and looks
    -- for exactly this statebag first (ox_inventory/modules/bridge/som/
    -- server.lua). Without it every retrieved car falls back to a plate lookup,
    -- and a pool car with no row gets no storage at all.
    state:set('vehicleid', row.id, true)
    state:set('som:vehicleId', row.id, true)
    state:set('som:owned', true, true)

    return NetworkGetNetworkIdFromEntity(entity)
end

exports('spawnVehicle', Vehicles.Spawn)
