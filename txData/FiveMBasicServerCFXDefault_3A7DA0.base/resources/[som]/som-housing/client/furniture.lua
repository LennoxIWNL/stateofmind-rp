--- Placing furniture, and drawing what is already placed.
---
--- Everything here is local and cosmetic. The ghost is not networked, the
--- placed objects are not networked, and the server decides whether a placement
--- is allowed after the fact. Two people decorating the same room at once would
--- each see their own until one of them leaves and comes back, which is a price
--- worth paying to keep sixty objects per property off the network entirely.

Furniture = {}

local spawned = {}
local ghost = nil

---@param model string
---@return number|nil hash
local function loadModel(model)
    local hash = joaat(model)

    -- Both, for the reason som_bridge records: IsModelValid answers whether the
    -- hash is well formed, not whether the game ships the model, and requesting
    -- one it does not ship raises inside the thread and reads as nothing
    -- happening at all.
    if not IsModelValid(hash) or not IsModelInCdimage(hash) then return nil end
    if not lib.requestModel(hash, 8000) then return nil end

    return hash
end

---Draws everything a property already holds.
---@param origin table the shell's world position
---@param rows table
function Furniture.Draw(origin, rows)
    Furniture.Clear()

    for _, row in ipairs(rows) do
        local hash = loadModel(row.model)

        if hash then
            local obj = CreateObject(hash,
                origin.x + row.off_x, origin.y + row.off_y, origin.z + row.off_z,
                false, false, false)

            SetEntityHeading(obj, row.rot_z or 0.0)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)

            spawned[#spawned + 1] = { entity = obj, id = row.id }
        end
    end
end

---Removes every drawn piece. Called on leaving and on resource stop.
function Furniture.Clear()
    for _, piece in ipairs(spawned) do
        if DoesEntityExist(piece.entity) then DeleteEntity(piece.entity) end
    end

    spawned = {}
end

---The furniture id nearest the player, for removing one.
---@return number|nil id, number|nil entity
local function nearest()
    local ped = PlayerPedId()
    local here = GetEntityCoords(ped)
    local bestId, bestEntity, bestDist = nil, nil, 3.0

    for _, piece in ipairs(spawned) do
        if DoesEntityExist(piece.entity) then
            local d = #(here - GetEntityCoords(piece.entity))
            if d < bestDist then bestId, bestEntity, bestDist = piece.id, piece.entity, d end
        end
    end

    return bestId, bestEntity
end

-- ---------------------------------------------------------------------------
-- Placing
-- ---------------------------------------------------------------------------

--- The placement loop.
---
--- Per-frame, and that is what input demands: the ghost follows the camera and
--- reads three keys. It runs ONLY while something is being placed, so the cost
--- is paid by the person decorating and by nobody else.
---@param model string
local function place(model)
    local inside = Interior.Current()
    if not inside then return end

    local hash = loadModel(model)
    if not hash then
        return TriggerEvent('som:client:notify', 'That model failed to load', 'error')
    end

    local ped = PlayerPedId()
    ghost = CreateObject(hash, GetEntityCoords(ped), false, false, false)

    SetEntityAlpha(ghost, 160, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetModelAsNoLongerNeeded(hash)

    local heading = GetEntityHeading(ped)
    local distance = 2.0
    local placed, cancelled = false, false

    exports['som-interact']:showTextUI('[E] Place  [Q/R] Turn  [Scroll] Distance  [X] Cancel')

    while not placed and not cancelled do
        Wait(0)

        local cam = GetGameplayCamRot(2)
        local pitch, yaw = math.rad(cam.x), math.rad(cam.z)
        local cosPitch = math.cos(pitch)

        local from = GetEntityCoords(ped)
        local dir = vec3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
        local at = from + (dir * distance)

        SetEntityCoords(ghost, at.x, at.y, at.z, false, false, false, false)
        SetEntityHeading(ghost, heading)

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        if IsControlPressed(0, 44) then heading = (heading + 2.0) % 360.0 end   -- Q
        if IsControlPressed(0, 45) then heading = (heading - 2.0) % 360.0 end   -- R

        if IsControlJustPressed(0, 241) then distance = math.min(distance + 0.2, 8.0) end
        if IsControlJustPressed(0, 242) then distance = math.max(distance - 0.2, 0.5) end

        if IsControlJustReleased(0, 38) then placed = true end
        if IsControlJustReleased(0, 73) then cancelled = true end
    end

    exports['som-interact']:hideTextUI()

    local at = GetEntityCoords(ghost)
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil

    if cancelled then return end

    -- RELATIVE to the shell origin, because that is what the row stores and
    -- what makes the same layout correct in every bucket.
    local origin = inside.void

    local res = lib.callback.await('som-housing:server:placeFurniture', false, {
        model = model,
        x = at.x - origin.x,
        y = at.y - origin.y,
        z = at.z - origin.z,
        heading = heading,
    })

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Could not place that', 'error')
    end

    -- Drawn from the server's answer rather than by keeping the ghost, so what
    -- is on screen is what was actually recorded.
    local drawn = loadModel(model)
    if drawn then
        local obj = CreateObject(drawn, at.x, at.y, at.z, false, false, false)
        SetEntityHeading(obj, heading)
        FreezeEntityPosition(obj, true)
        SetModelAsNoLongerNeeded(drawn)
        spawned[#spawned + 1] = { entity = obj, id = res.id }
    end
end

-- ---------------------------------------------------------------------------
-- The menu
-- ---------------------------------------------------------------------------

---Opens the catalogue, or offers to pick up whatever is underfoot.
function Furniture.Menu()
    local res = lib.callback.await('som-housing:server:furniture', false)

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Nothing here', 'error')
    end

    if not res.canDecorate then
        return TriggerEvent('som:client:notify', 'You cannot rearrange this place', 'error')
    end

    local options = {}

    local nearId = nearest()
    if nearId then
        options[#options + 1] = {
            title = 'Pick this up',
            description = 'Remove the piece you are standing next to',
            icon = 'hand',
            onSelect = function()
                local removed = lib.callback.await('som-housing:server:removeFurniture', false, { id = nearId })

                if not removed or not removed.success then
                    return TriggerEvent('som:client:notify',
                        removed and removed.error or 'Could not remove that', 'error')
                end

                for i, piece in ipairs(spawned) do
                    if piece.id == nearId then
                        if DoesEntityExist(piece.entity) then DeleteEntity(piece.entity) end
                        table.remove(spawned, i)
                        break
                    end
                end
            end,
        }
    end

    for _, entry in ipairs(res.catalogue) do
        options[#options + 1] = {
            title = entry.label,
            description = entry.category,
            icon = 'couch',
            onSelect = function() place(entry.model) end,
        }
    end

    lib.registerContext({ id = 'som_housing_furniture', title = 'Furnish', options = options })
    lib.showContext('som_housing_furniture')
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    Furniture.Clear()
end)
