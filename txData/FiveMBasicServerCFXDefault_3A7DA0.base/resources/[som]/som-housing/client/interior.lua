--- The shell itself.
---
--- Everything here is cosmetic and local. The server has already decided the
--- player may go in and has already moved their routing bucket; this only
--- builds the room they arrive in.
---
--- The shell is a plain object, frozen, spawned at coordinates the server sent.
--- Because the bucket is already set, nobody outside that property can see it,
--- which is what lets one model serve every property that uses it.

Interior = {}

local current = nil

---@param model string|number
---@return boolean
local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model

    -- Both checks, for the reason som_bridge records against thrown props:
    -- IsModelValid answers whether the hash is well formed, not whether the
    -- game ships the model, and requesting one it does not ship raises inside
    -- the thread and reads as the feature silently doing nothing.
    if not IsModelValid(hash) or not IsModelInCdimage(hash) then return false end
    if not lib.requestModel(hash, 10000) then return false end

    return true
end

---Builds the interior and puts the player in it.
---@param data table the server's enter payload
---@return boolean
function Interior.Build(data)
    if current then Interior.Tear() end

    if not loadModel(data.property.shell) then
        TriggerEvent('som:client:notify', 'That interior failed to load', 'error')
        return false
    end

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    local void = data.void
    local shell = CreateObject(joaat(data.property.shell), void.x, void.y, void.z, false, false, false)

    FreezeEntityPosition(shell, true)
    SetEntityInvincible(shell, true)

    current = {
        shell = shell,
        propertyId = data.property.id,
        slug = data.property.slug,
        label = data.property.label,
        stash = data.stash,
        void = void,
        offset = data.offset,
    }

    local ped = PlayerPedId()
    SetEntityCoords(ped, void.x + data.offset.x, void.y + data.offset.y, void.z + data.offset.z,
        false, false, false, false)
    SetEntityHeading(ped, data.offset.h)

    -- The shell has to actually stream in before the fade lifts, or the player
    -- sees themselves standing in an empty void for a moment and reasonably
    -- concludes the house is broken.
    local waited = 0
    while not HasCollisionLoadedAroundEntity(ped) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end

    DoScreenFadeIn(600)
    SetModelAsNoLongerNeeded(joaat(data.property.shell))

    return true
end

---Removes the interior. Safe to call when there is not one.
function Interior.Tear()
    if not current then return end

    if DoesEntityExist(current.shell) then
        DeleteEntity(current.shell)
    end

    current = nil
end

---What the player is standing in, or nil.
---@return table|nil
function Interior.Current()
    return current
end

--- The shell is a local object and dies with the resource anyway, but deleting
--- it deliberately means a restart while indoors does not leave one frozen
--- object behind in a bucket nobody will ever enter again.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Interior.Tear()
end)
