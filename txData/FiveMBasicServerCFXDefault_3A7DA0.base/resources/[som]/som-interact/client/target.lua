-- Interaction wrapper.
--
-- Every som-* resource calls this instead of qb-target directly. qb-target is
-- escrow protected and unversioned (see AUDIT.md section 7.1), so it can never
-- be forked or patched. Isolating it behind one file means swapping it for
-- ox_target later is a change to this file and nothing else.
--
-- We target the ox_target-shaped compat exports rather than qb-target's own
-- PascalCase natives, because that surface is smaller and is what a real
-- ox_target would already understand.
--
-- SECURITY: qb-target's `groups` filtering is a CLIENT SIDE UI FILTER ONLY.
-- It decides what a player can see, not what they may do. Any action reached
-- through an interaction MUST re-check job, gang, grade, and distance on the
-- server. Treat every onSelect as an untrusted request.

local backend = exports.ox_target

local registered = {}

---Normalises a som option table into what the compat layer expects.
---@param options table[]
---@return table[]
local function buildOptions(options)
    if type(options) ~= 'table' then return {} end

    local out = {}
    for i = 1, #options do
        local opt = options[i]
        out[i] = {
            label = opt.label,
            name = opt.name or opt.label,
            icon = opt.icon or 'fa-solid fa-hand',
            distance = opt.distance or 2.5,
            item = opt.item,
            groups = opt.groups,
            onSelect = opt.onSelect,
            canInteract = opt.canInteract,
        }
    end
    return out
end

local Interact = {}

---@param data table { name, coords, size, rotation, options }
---@return any zone id
function Interact.addBoxZone(data)
    if type(data) ~= 'table' or not data.coords then return end

    local size = data.size or vec3(2.0, 2.0, 2.0)
    local id = backend:addBoxZone(
        data.name,
        data.coords,
        size.x,
        size.y,
        {
            name = data.name,
            heading = data.rotation or 0.0,
            debugPoly = data.debug or false,
            minZ = data.minZ or (data.coords.z - (size.z / 2)),
            maxZ = data.maxZ or (data.coords.z + (size.z / 2)),
            useZ = true,
        },
        buildOptions(data.options)
    )

    registered[id] = data.name
    return id
end

---@param data table { name, coords, radius, options }
function Interact.addSphereZone(data)
    if type(data) ~= 'table' or not data.coords then return end

    local id = backend:addSphereZone(
        data.name,
        data.coords,
        data.radius or 2.0,
        { name = data.name, useZ = true, debugPoly = data.debug or false },
        buildOptions(data.options)
    )

    registered[id] = data.name
    return id
end

---@param data table { name, points, thickness, options }
function Interact.addPolyZone(data)
    if type(data) ~= 'table' or type(data.points) ~= 'table' then return end

    local id = backend:addPolyZone(
        data.name,
        data.points,
        {
            name = data.name,
            minZ = data.minZ,
            maxZ = data.maxZ,
            debugPoly = data.debug or false,
        },
        buildOptions(data.options)
    )

    registered[id] = data.name
    return id
end

---@param id any
function Interact.removeZone(id)
    if id == nil then return end
    registered[id] = nil
    return backend:removeZone(id)
end

---@param entities number|number[]
---@param options table[]
function Interact.addLocalEntity(entities, options)
    if not entities then return end
    return backend:addLocalEntity(entities, buildOptions(options))
end

---@param entities number|number[]
---@param labels string[]
function Interact.removeLocalEntity(entities, labels)
    if not entities then return end
    return backend:removeLocalEntity(entities, labels)
end

---@param models string|string[]|number|number[]
---@param options table[]
function Interact.addModel(models, options)
    if not models then return end
    return backend:addModel(models, buildOptions(options))
end

function Interact.removeModel(models, labels)
    if not models then return end
    return backend:removeModel(models, labels)
end

-- Global targets. These attach to every entity of a kind, so they are the
-- mechanism behind Phase 5 police verbs (cuff, search, escort) and Phase 8's
-- removal of /cuff and friends: the option appears on the player you look at.

function Interact.addGlobalPlayer(options)
    return backend:addGlobalPlayer(buildOptions(options))
end

function Interact.removeGlobalPlayer(labels)
    return backend:removeGlobalPlayer(labels)
end

function Interact.addGlobalVehicle(options)
    return backend:addGlobalVehicle(buildOptions(options))
end

function Interact.removeGlobalVehicle(labels)
    return backend:removeGlobalVehicle(labels)
end

function Interact.addGlobalPed(options)
    return backend:addGlobalPed(buildOptions(options))
end

function Interact.removeGlobalPed(labels)
    return backend:removeGlobalPed(labels)
end

function Interact.addGlobalObject(options)
    return backend:addGlobalObject(buildOptions(options))
end

function Interact.removeGlobalObject(labels)
    return backend:removeGlobalObject(labels)
end

for name, fn in pairs(Interact) do
    exports(name, fn)
end
