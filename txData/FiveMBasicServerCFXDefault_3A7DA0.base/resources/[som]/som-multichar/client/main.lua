-- Character selection and creation.
--
-- Replaces qb-multicharacter, which was removed with the QBox layer. All
-- validation lives server side in som-core/server/characters.lua: this file
-- only presents choices and relays the player's pick.

local cam = nil
local previewPed = nil
local inSelection = false

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------

local function destroyPreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

---Spawns the ped shown in the preview scene.
---@param gender number 0 male, 1 female
local function setPreviewPed(gender)
    destroyPreviewPed()

    local modelName = Config.PedModels[gender] or Config.PedModels[0]
    local model = joaat(modelName)

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasModelLoaded(model) then return end

    previewPed = CreatePed(2, model, Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 0.98,
        Config.PedCoords.w, false, true)

    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedDefaultComponentVariation(previewPed)
    SetModelAsNoLongerNeeded(model)
end

local function startScene()
    local ped = PlayerPedId()

    SetEntityCoordsNoOffset(ped, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z, false, false, false)
    SetEntityHeading(ped, Config.HiddenCoords.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    DisplayRadar(false)

    if cam then DestroyCam(cam, true) end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, Config.CamCoords.x, Config.CamCoords.y, Config.CamCoords.z)
    SetCamRot(cam, 0.0, 0.0, Config.CamCoords.w, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- The interior needs a moment to stream in before the fade back up, or the
    -- player sees an empty world for a frame.
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(10)
    end
end

local function endScene()
    RenderScriptCams(false, false, 0, true, true)
    if cam then
        DestroyCam(cam, true)
        cam = nil
    end

    destroyPreviewPed()
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
