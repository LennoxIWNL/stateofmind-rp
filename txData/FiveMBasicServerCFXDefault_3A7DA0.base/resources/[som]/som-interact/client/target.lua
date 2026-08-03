-- Interaction wrapper.
--
-- Every som-* resource calls this instead of the interaction engine directly.
-- The engine has already been swapped once (qb-target, which was escrowed and
-- unversioned, so it could never be read or fixed) and this file is the reason
-- that cost one afternoon instead of a rewrite.
--
-- Backend: sleepless_interact. Its native API is wrapped rather than its
-- ox_target compat shim, because the native one exposes holdTime, cooldown and
-- the active callbacks, and one less translation layer means one less place for
-- a signature to drift.
--
-- SECURITY: `groups` here is a CLIENT SIDE UI FILTER ONLY. It decides what a
-- player sees, not what they may do. Any action reached through an interaction
-- MUST re-check job, gang, grade and distance on the server. Treat every
-- onSelect as an untrusted request.

local backend = exports.sleepless_interact

-- ---------------------------------------------------------------------------
-- ZONES ARE POINTS.
--
-- The engine draws a circle at a coordinate; there is nowhere to put a circle
-- for a 20m polygon. addBoxZone, addSphereZone and addPolyZone therefore all
-- resolve to a single point with a per-option `distance`, and a poly resolves
-- to its centroid.
--
-- For a door, a till or a stash this is what you wanted anyway. For a large
-- area it is not: use several points, or a PolyZone in som-zones if the thing
-- you need is genuinely "am I inside this region".
-- ---------------------------------------------------------------------------

local registered = {}

---@param points vector3[]|table[]
---@param z number|nil
---@return vector3
local function centroid(points, z)
    local x, y, sumZ = 0.0, 0.0, 0.0

    for i = 1, #points do
        local p = points[i]
        x = x + p.x
        y = y + p.y
        sumZ = sumZ + (p.z or 0.0)
    end

    local count = #points
    return vec3(x / count, y / count, z or (sumZ / count))
end

---Normalises a som option into what sleepless_interact expects.
---
---Deliberately does NOT pass through `event`, `serverEvent` or `command`, all
---of which the engine supports. A config value naming a server event lets the
---client choose both the event and its payload, which is the same hole the
---radial refuses to open. Callers use onSelect and go through a validated
---export or a request the server re-checks.
---@param options table[]
---@return table[]
local function buildOptions(options)
    if type(options) ~= 'table' then return {} end

    -- A single option table, rather than an array of them, is a common enough
    -- slip to just handle.
    if options.label then options = { options } end

    local out = {}

    for i = 1, #options do
        local opt = options[i]
        local groups = opt.groups
        local canInteract = opt.canInteract

        -- sleepless has no `groups` field, so job and gang filtering folds into
        -- canInteract. Same visibility behaviour, same non-guarantee.
        if groups then
            if type(groups) == 'string' then groups = { groups } end

            canInteract = function(entity, distance, coords, name)
                local core = exports['som-core']
                local job = core:getJob()
                local gang = core:getGang()

                local match = false
                for g = 1, #groups do
                    local want = groups[g]
                    if (job and job.name == want) or (gang and gang.name == want) then
                        match = true
                        break
                    end
                end

                if not match then return false end
                if opt.canInteract then return opt.canInteract(entity, distance, coords, name) end
                return true
            end
        end

        out[i] = {
            name = opt.name or opt.label,
            label = opt.label,
            icon = opt.icon or 'fa-solid fa-hand',
            iconColor = opt.iconColor,
            distance = opt.distance or 2.5,
            holdTime = opt.holdTime,
            cooldown = opt.cooldown,
            offset = opt.offset,
            offsetAbsolute = opt.offsetAbsolute,
            bones = opt.bones,
            color = opt.color,
            allowInVehicle = opt.allowInVehicle,
            canInteract = canInteract,
            onSelect = opt.onSelect,
            onActive = opt.onActive,
            onInactive = opt.onInactive,
            whileActive = opt.whileActive,
        }
    end

    return out
end

local Interact = {}

---@param data table { name, coords, options }
---@return any id
function Interact.addCoords(data)
    if type(data) ~= 'table' or not data.coords then return end

    local id = backend:addCoords(data.coords, buildOptions(data.options))
    registered[id] = data.name
    return id
end

---Kept for API compatibility. Resolves to a point; `size` is ignored, use a
---per-option `distance` instead.
---@param data table { name, coords, options }
function Interact.addBoxZone(data)
    return Interact.addCoords(data)
end

---As above. `radius` is ignored, use a per-option `distance`.
function Interact.addSphereZone(data)
    return Interact.addCoords(data)
end

---Resolves to the centroid of the supplied points.
---@param data table { name, points, z, options }
function Interact.addPolyZone(data)
    if type(data) ~= 'table' or type(data.points) ~= 'table' or #data.points == 0 then return end

    return Interact.addCoords({
        name = data.name,
        coords = centroid(data.points, data.z),
        options = data.options,
    })
end

---@param id any
function Interact.removeZone(id)
    if id == nil then return end
    registered[id] = nil
    return backend:removeCoords(id)
end

Interact.removeCoords = Interact.removeZone

---@param entities number|number[]
---@param options table[]
function Interact.addLocalEntity(entities, options)
    if not entities then return end
    return backend:addLocalEntity(entities, buildOptions(options))
end

function Interact.removeLocalEntity(entities, labels)
    if not entities then return end
    return backend:removeLocalEntity(entities, labels)
end

---Networked entities, by net id.
function Interact.addEntity(netIds, options)
    if not netIds then return end
    return backend:addEntity(netIds, buildOptions(options))
end

function Interact.removeEntity(netIds, labels)
    if not netIds then return end
    return backend:removeEntity(netIds, labels)
end

---@param models string|string[]|number|number[]
function Interact.addModel(models, options)
    if not models then return end
    return backend:addModel(models, buildOptions(options))
end

function Interact.removeModel(models, labels)
    if not models then return end
    return backend:removeModel(models, labels)
end

-- Global targets attach to every entity of a kind, so they are the mechanism
-- behind the police verbs (cuff, search, escort) and behind removing /cuff and
-- friends: the option appears on the player you are looking at.

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

---Suppresses interaction entirely, for cutscenes, death and the like.
---@param state boolean
function Interact.disableInteract(state)
    return backend:disableInteract(state == true)
end

for name, fn in pairs(Interact) do
    exports(name, fn)
end
