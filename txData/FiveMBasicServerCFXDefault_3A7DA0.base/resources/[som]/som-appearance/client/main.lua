-- The editor.
--
-- One editor serves creation, the barber and the clothing shop. What differs
-- is the SCOPE, which decides which sections are offered, and the server
-- enforces the same list again when the result is saved.
--
-- It always edits the PLAYER's own ped. Editing a separate preview ped means
-- keeping two peds in sync and reimplementing the model swap, and the player
-- ped is the thing whose appearance is actually being changed.

Editor = {}

local isOpen = false
local scope = 'creator'
local original             -- what to restore if the player cancels
local working              -- what is being edited
local cam
local heading = 0.0

-- ---------------------------------------------------------------------------
-- Camera
-- ---------------------------------------------------------------------------

---@param view string head, body or legs
local function setView(view)
    local def = Config.Camera.views[view] or Config.Camera.views.body
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)

    -- Offsets are relative to where the ped is FACING, so the camera stays in
    -- front of them however the player has rotated the model.
    local pos = vector3(
        coords.x + fwd.x * def.offset.x,
        coords.y + fwd.y * def.offset.y,
        coords.z + def.offset.z)

    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam,
        coords.x + def.point.x, coords.y + def.point.y, coords.z + def.point.z)
end

local function startCamera()
    if cam then return end

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, Config.Camera.fov)
    setView('head')
    RenderScriptCams(true, false, 0, true, true)
end

local function stopCamera()
    if not cam then return end

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

-- ---------------------------------------------------------------------------
-- Open and close
-- ---------------------------------------------------------------------------

local function applyWorking()
    -- Apply returns a possibly NEW ped handle, because changing the model
    -- replaces the entity. Ignoring the return leaves every later call
    -- operating on a dead handle.
    local ped = Appearance.Apply(cache.ped, working)
    SetEntityHeading(ped, heading)
end

---@param requested string scope name
function Editor.Open(requested)
    if isOpen then return end
    if not Config.Scopes[requested] then return end

    local data = lib.callback.await('som-appearance:server:get', false)
    if not data then return end

    scope = requested
    isOpen = true

    -- A character with nothing stored is being created, so it starts from the
    -- default for their gender rather than from whatever the ped happens to
    -- be wearing.
    original = data.appearance or Appearance.Default(data.gender)
    working = json.decode(json.encode(original))

    heading = GetEntityHeading(cache.ped)
    applyWorking()

    FreezeEntityPosition(cache.ped, true)
    SetEntityInvincible(cache.ped, true)
    startCamera()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            scope = scope,
            sections = Config.Scopes[scope],
            appearance = working,
            limits = Appearance.Limits(cache.ped),
            definitions = {
                faceFeatures = Config.FaceFeatures,
                headOverlays = Config.HeadOverlays,
                components = Config.Components,
                props = Config.Props,
            },
            pricing = Config.Pricing,
            payment = data.payment,
            -- Creation cannot be cancelled: there is nothing to go back to.
            canCancel = scope ~= 'creator',
        },
    })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    stopCamera()
    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)
end

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------

RegisterNUICallback('update', function(data, cb)
    cb({})
    if not isOpen or type(data) ~= 'table' or type(data.path) ~= 'table' then return end

    -- Walk the path and set the leaf, so the NUI can address anything in the
    -- appearance table without this file knowing its shape.
    local node = working
    for i = 1, #data.path - 1 do
        local key = data.path[i]
        if type(node[key]) ~= 'table' then return end
        node = node[key]
    end

    node[data.path[#data.path]] = data.value
    applyWorking()
end)

RegisterNUICallback('view', function(data, cb)
    cb({})
    if not isOpen then return end

    local section = type(data) == 'table' and data.section
    setView(Config.Camera.sectionView[section] or 'body')
end)

RegisterNUICallback('rotate', function(data, cb)
    cb({})
    if not isOpen then return end

    local dir = tonumber(data and data.dir) or 1
    heading = (heading + Config.RotateSpeed * 8 * dir) % 360.0
    SetEntityHeading(cache.ped, heading)
end)

RegisterNUICallback('confirm', function(data, cb)
    local res = lib.callback.await('som-appearance:server:save', false, {
        scope = scope,
        appearance = working,
        -- Chosen at the counter. som-core validates it; this only relays.
        account = type(data) == 'table' and data.account or nil,
    })

    cb(res or { success = false })

    if res and res.success then
        close()

        if res.price and res.price > 0 then
            TriggerEvent('som:client:notify', ('Charged $%d'):format(res.price), 'info')
        end

        TriggerEvent('som-appearance:client:finished', scope)
    end
end)

RegisterNUICallback('cancel', function(_, cb)
    cb({})
    if scope == 'creator' then return end

    working = json.decode(json.encode(original))
    applyWorking()
    close()
end)

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

exports('openEditor', function(requested) Editor.Open(requested or 'barber') end)

---Re-applies the stored appearance to the player, after a spawn or a respawn.
exports('refresh', function()
    local data = lib.callback.await('som-appearance:server:get', false)
    if data and data.appearance then Appearance.Apply(cache.ped, data.appearance) end
end)

-- Every new character customises before they play.
--
-- Opened on load rather than inside som-multichar's scene: the creator edits
-- the player's own ped, and during character selection that ped is not yet in
-- the world. Waiting until the character is live means one code path serves
-- creation and the barber instead of two.
RegisterNetEvent('som:client:playerLoaded', function()
    CreateThread(function()
        Wait(2500)

        local data = lib.callback.await('som-appearance:server:get', false)
        if not data then return end

        if data.appearance then
            Appearance.Apply(cache.ped, data.appearance)
            return
        end

        Editor.Open('creator')
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not isOpen then return end

    SetNuiFocus(false, false)
    stopCamera()
    FreezeEntityPosition(cache.ped, false)
end)
