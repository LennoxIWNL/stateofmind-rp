-- Character selection and creation.
--
-- Replaces qb-multicharacter, which was removed with the QBox layer. All
-- validation lives server side in som-core/server/characters.lua: this file
-- only presents choices and relays the player's pick.

local cam = nil
local previewPed = nil
local shellObject = nil
local inSelection = false

-- ---------------------------------------------------------------------------
-- NUI focus
--
-- spawnmanager fires playerSpawned and then keeps working for a few frames,
-- and it can clear NUI focus out from under us. A single SetNUIFocus call
-- immediately after playerSpawned therefore gets silently dropped and the
-- player is left looking at a UI with no cursor.
--
-- Re-assert until it sticks rather than assuming the first call won.
-- ---------------------------------------------------------------------------

local function startFocusWatchdog()
    CreateThread(function()
        while inSelection do
            if not IsNuiFocused() then
                SetNUIFocus(true, true)
                SetNUIFocusKeepInput(false)
            end
            Wait(200)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------

local function destroyPreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

---Loads a model with a timeout so a bad model name cannot hang the client
---on the character screen forever.
---@param model number
---@return boolean loaded
local function requestModel(model)
    if HasModelLoaded(model) then return true end

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasModelLoaded(model)
end

---@param dict string
---@return boolean loaded
local function requestAnim(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    return HasAnimDictLoaded(dict)
end

---@return vector3 origin the scene is built around
local function sceneOrigin()
    return Config.Shell.enabled and Config.Shell.coords or Config.Fallback.interior
end

---@return vector3 where the preview ped stands
local function pedPosition()
    if not Config.Shell.enabled then
        return vec3(Config.Fallback.ped.x, Config.Fallback.ped.y, Config.Fallback.ped.z)
    end
    return sceneOrigin() + Config.Shell.pedOffset
end

---@return number heading
local function pedHeading()
    return Config.Shell.enabled and Config.Shell.pedHeading or Config.Fallback.ped.w
end

local function destroyShell()
    if shellObject and DoesEntityExist(shellObject) then
        DeleteEntity(shellObject)
    end
    shellObject = nil
end

---Spawns the interior shell the scene is staged inside.
---@return boolean success
local function createShell()
    if not Config.Shell.enabled then return false end

    destroyShell()

    local model = joaat(Config.Shell.model)
    if not requestModel(model) then
        print(('[som-multichar] shell model %s failed to load, falling back to the world scene')
            :format(Config.Shell.model))
        return false
    end

    local coords = Config.Shell.coords
    shellObject = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCoordsNoOffset(shellObject, coords.x, coords.y, coords.z, false, false, false)
    FreezeEntityPosition(shellObject, true)
    SetEntityCollision(shellObject, true, true)
    SetModelAsNoLongerNeeded(model)

    return true
end

---Spawns the ped shown in the preview scene.
---@param gender number 0 male, 1 female
local function setPreviewPed(gender)
    destroyPreviewPed()

    local modelName = Config.PedModels[gender] or Config.PedModels[0]
    local model = joaat(modelName)
    if not requestModel(model) then return end

    local pos = pedPosition()
    previewPed = CreatePed(2, model, pos.x, pos.y, pos.z, pedHeading(), false, true)

    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedDefaultComponentVariation(previewPed)
    SetModelAsNoLongerNeeded(model)

    -- Idle animation, so the character reads as a person rather than a mannequin.
    if requestAnim('anim@heists@heist_corona@team_idles@male_a') then
        TaskPlayAnim(previewPed, 'anim@heists@heist_corona@team_idles@male_a', 'idle', 8.0, -8.0, -1, 1, 0, false, false, false)
    end
end

---Slow horizontal drift around the subject, so the shot is not a dead frame.
local function startCameraOrbit(origin, lookAt)
    local orbit = Config.Shell.orbit
    if not (Config.Shell.enabled and orbit and orbit.enabled) then return end

    CreateThread(function()
        local base = origin
        local radius = #(vec3(base.x, base.y, 0.0) - vec3(lookAt.x, lookAt.y, 0.0))
        local baseAngle = math.atan(base.y - lookAt.y, base.x - lookAt.x)
        local sweep = math.rad(orbit.degrees) * 0.5
        local period = orbit.seconds * 1000.0
        local started = GetGameTimer()

        while inSelection and cam do
            local elapsed = (GetGameTimer() - started) % period
            -- Sine gives an ease at each end of the sweep for free, so the
            -- camera never snaps direction.
            local angle = baseAngle + math.sin((elapsed / period) * math.pi * 2.0) * sweep

            SetCamCoord(cam,
                lookAt.x + math.cos(angle) * radius,
                lookAt.y + math.sin(angle) * radius,
                base.z)
            PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)

            Wait(0)
        end
    end)
end

local function startScene()
    local ped = PlayerPedId()

    -- The hidden player ped is parked next to the scene, not somewhere else on
    -- the map. Streaming follows the player, so leaving it behind would mean
    -- the shell and preview ped never render at all.
    local hidden = Config.Shell.enabled
        and (Config.Shell.coords + vec3(0.0, -6.0, 0.0))
        or vec3(Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z)

    SetEntityCoordsNoOffset(ped, hidden.x, hidden.y, hidden.z, false, false, false)
    SetEntityHeading(ped, Config.HiddenCoords.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    DisplayRadar(false)

    local usingShell = createShell()

    local camPos, lookAt
    if usingShell then
        local origin = Config.Shell.coords
        camPos = origin + Config.Shell.camOffset
        lookAt = origin + Config.Shell.pedOffset + Config.Shell.camLookAtOffset
    else
        -- Shell disabled or its model failed to load: use the flat world scene.
        camPos = vec3(Config.Fallback.cam.x, Config.Fallback.cam.y, Config.Fallback.cam.z)
        lookAt = vec3(Config.Fallback.ped.x, Config.Fallback.ped.y, Config.Fallback.ped.z + 0.2)
    end

    if cam then DestroyCam(cam, true) end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Depth of field keeps attention on the character and softens the shell
    -- behind it, which is what makes the shot read as deliberate.
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.6)
    SetCamFarDof(cam, 3.2)
    SetCamDofStrength(cam, 0.8)

    -- SetUseHiDof only applies for the frame it is called on, so it has to run
    -- every frame for the whole time the scene is up.
    CreateThread(function()
        while inSelection and cam do
            SetUseHiDof()
            Wait(0)
        end
    end)

    startCameraOrbit(camPos, lookAt)

    -- The scene needs a moment to stream in before the fade back up, or the
    -- player sees an empty void for a frame.
    local target = usingShell and Config.Shell.coords or camPos
    NewLoadSceneStart(target.x, target.y, target.z, 0.0, 0.0, 0.0, 50.0, 0)

    local timeout = GetGameTimer() + 10000
    while IsNetworkLoadingScene() and GetGameTimer() < timeout do
        Wait(10)
    end
    NewLoadSceneStop()
end

local function endScene()
    RenderScriptCams(false, false, 0, true, true)
    if cam then
        DestroyCam(cam, true)
        cam = nil
    end

    destroyPreviewPed()
    destroyShell()
    DisplayRadar(true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
end

-- ---------------------------------------------------------------------------
-- Selection flow
-- ---------------------------------------------------------------------------

local function openSelection()
    if inSelection then return end
    inSelection = true

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    if Config.UseRoutingBuckets then
        TriggerServerEvent('som-multichar:server:enterSelection')
        -- Give the bucket change a moment to apply before the scene is built.
        Wait(250)
    end

    startScene()

    local characters = lib.callback.await('som:server:getCharacters', false) or {}

    SendNUIMessage({
        action = 'open',
        characters = characters,
        maxSlots = exports['som-core']:getMaxCharacterSlots(),
        nationalities = Config.Nationalities,
    })
    SetNUIFocus(true, true)
    SetNUIFocusKeepInput(false)
    startFocusWatchdog()

    DoScreenFadeIn(800)
end

local function closeSelection()
    if not inSelection then return end

    SendNUIMessage({ action = 'close' })
    SetNUIFocus(false, false)
    endScene()

    inSelection = false
end

-- ---------------------------------------------------------------------------
-- NUI callbacks
--
-- Each one relays to som-core, which re-derives identity from source and
-- validates every field. Nothing here is trusted.
-- ---------------------------------------------------------------------------

RegisterNUICallback('selectCharacter', function(data, cb)
    if type(data) ~= 'table' or type(data.citizenid) ~= 'string' then
        cb({ success = false, error = 'Invalid character' })
        return
    end

    local result = lib.callback.await('som:server:selectCharacter', false, data.citizenid)
    cb(result or { success = false, error = 'No response from server' })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    if type(data) ~= 'table' then
        cb({ success = false, error = 'Invalid payload' })
        return
    end

    local result = lib.callback.await('som:server:createCharacter', false, {
        slot = data.slot,
        firstname = data.firstname,
        lastname = data.lastname,
        dob = data.dob,
        gender = data.gender,
        nationality = data.nationality,
    })

    if result and result.success then
        -- Creating does not select. Refresh the grid so the new character shows.
        local characters = lib.callback.await('som:server:getCharacters', false) or {}
        SendNUIMessage({ action = 'refresh', characters = characters })
    end

    cb(result or { success = false, error = 'No response from server' })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if type(data) ~= 'table' or type(data.citizenid) ~= 'string' then
        cb({ success = false, error = 'Invalid character' })
        return
    end

    local result = lib.callback.await('som:server:deleteCharacter', false, data.citizenid)

    if result and result.success then
        local characters = lib.callback.await('som:server:getCharacters', false) or {}
        SendNUIMessage({ action = 'refresh', characters = characters })
    end

    cb(result or { success = false, error = 'No response from server' })
end)

RegisterNUICallback('previewGender', function(data, cb)
    local gender = tonumber(data and data.gender) or 0
    setPreviewPed(gender)
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
-- Spawn
-- ---------------------------------------------------------------------------

RegisterNetEvent('som:client:playerLoaded', function(data)
    if type(data) ~= 'table' then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    closeSelection()

    local spawn = data.position or Config.DefaultSpawn
    local ped = PlayerPedId()

    local modelName = Config.PedModels[data.charinfo and data.charinfo.gender or 0] or Config.PedModels[0]
    local model = joaat(modelName)

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    if HasModelLoaded(model) then
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end

    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w or 0.0)

    -- Wait for ground collision so the player does not fall through the map.
    local collisionTimeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do
        Wait(10)
    end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)

    if Config.UseRoutingBuckets then
        TriggerServerEvent('som-multichar:server:leaveSelection')
    end

    DoScreenFadeIn(1000)
    TriggerEvent('som:client:spawned', data)
end)

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

AddEventHandler('playerSpawned', function()
    if exports['som-core']:isPlayerLoaded() then return end
    openSelection()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if inSelection then
        SetNUIFocus(false, false)
        endScene()
    end
end)

CreateThread(function()
    -- Cover a resource restart while a player is already in the world without
    -- a loaded character, which playerSpawned alone would not catch.
    Wait(2000)
    if not exports['som-core']:isPlayerLoaded() and not inSelection then
        openSelection()
    end
end)
