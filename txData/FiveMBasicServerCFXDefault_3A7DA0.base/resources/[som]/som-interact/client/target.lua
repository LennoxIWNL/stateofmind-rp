-- Interaction wrapper.
--
-- Every som-* resource calls this instead of the engine directly. The engine
-- has now been swapped twice and this file is why each swap cost an afternoon
-- rather than a rewrite.
--
-- Backend: ox_target. MIT, maintained, and an AIMING eye: hold the key, look
-- at something, the eye changes to show it is interactable, options appear
-- beside it and a click picks one.
--
-- It briefly ran on sleepless_interact, which draws indicator circles at
-- nearby points and has no raycast at all. That is a different interaction
-- model, not a skin: there is nothing to aim, so "look at the ped and pick an
-- option" cannot be expressed in it. Zones also had to collapse to points
-- there, which is undone by this.
--
-- SECURITY: `groups` is a CLIENT SIDE UI FILTER ONLY. It decides what a player
-- sees, not what they may do. Any action reached through an interaction MUST
-- re-check job, gang, grade and distance on the server. Treat every onSelect as
-- an untrusted request.

local backend = exports.ox_target

local registered = {}

---Normalises a som option into what ox_target expects.
---
---Deliberately does NOT pass through `event`, `serverEvent` or `command`, all
---of which ox_target supports. A config value naming a server event lets the
---client choose both the event and its payload, which is the same hole
---som-radial refuses to open. Callers use onSelect and go through a validated
---export, or a request the server re-checks.
---@param options table[]
---@return table[]
local function buildOptions(options)
    if type(options) ~= 'table' then return {} end

    -- A single option table rather than an array of them is a common enough
    -- slip to just handle.
    if options.label then options = { options } end

    local out = {}

    for i = 1, #options do
        local opt = options[i]

        out[i] = {
            name = opt.name or opt.label,
            label = opt.label,
            icon = opt.icon or 'fa-solid fa-hand',
            iconColor = opt.iconColor,
            distance = opt.distance or 2.5,
            groups = opt.groups,
            items = opt.items or opt.item,
            bones = opt.bones,
            offset = opt.offset,
            offsetAbsolute = opt.offsetAbsolute,
            canInteract = opt.canInteract,
            onSelect = opt.onSelect,
        }
    end

    return out
end

local Interact = {}

---@param data table { name, coords, size, rotation, options, debug }
---@return any id
function Interact.addBoxZone(data)
    if type(data) ~= 'table' or not data.coords then return end

    local id = backend:addBoxZone({
        coords = data.coords,
        size = data.size or vec3(2.0, 2.0, 2.0),
        rotation = data.rotation or 0.0,
        debug = data.debug or false,
        drawSprite = data.drawSprite ~= false,
        options = buildOptions(data.options),
    })

    registered[id] = data.name
    return id
end

---@param data table { name, coords, radius, options, debug }
function Interact.addSphereZone(data)
    if type(data) ~= 'table' or not data.coords then return end

    local id = backend:addSphereZone({
        coords = data.coords,
        radius = data.radius or 2.0,
        debug = data.debug or false,
        drawSprite = data.drawSprite ~= false,
        options = buildOptions(data.options),
    })

    registered[id] = data.name
    return id
end

---@param data table { name, points, thickness, options, debug }
function Interact.addPolyZone(data)
    if type(data) ~= 'table' or type(data.points) ~= 'table' then return end

    local id = backend:addPolyZone({
        points = data.points,
        thickness = data.thickness or 4.0,
        debug = data.debug or false,
        options = buildOptions(data.options),
    })

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

---Suppresses the eye entirely, for cutscenes, death and the like.
---@param state boolean
function Interact.disableInteract(state)
    return backend:disableTargeting(state == true)
end

for name, fn in pairs(Interact) do
    exports(name, fn)
end
