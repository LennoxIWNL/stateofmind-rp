-- Character selection and creation.
--
-- Replaces qb-multicharacter, which was removed with the QBox layer. All
-- validation lives server side in som-core/server/characters.lua: this file
-- only presents choices and relays the player's pick.

local cam = nil
local previewPed = nil
local shellObject = nil
local inSelection = false

-- Current framing, kept at file level rather than captured by the orbit
-- thread. The orbit rewrites the camera every frame, so if it held its own
-- copy of these it would immediately overwrite anything that moved the camera
-- afterwards, and live tuning would appear to do nothing.
local sceneCam = nil
local sceneLookAt = nil
local orbitPaused = false

-- ---------------------------------------------------------------------------
-- NUI focus
--
-- The native is SetNuiFocus, not SetNUIFocus. The capitalised spelling is nil,
-- so calling it throws and the player is left with a UI and no cursor. Every
-- other resource in the tree uses the correct casing; check against one of
-- those before trusting a remembered native name.
--
-- The watchdog re-asserts focus because it is cheap insurance: other resources
-- and spawnmanager can clear NUI focus during the spawn sequence.
-- ---------------------------------------------------------------------------

local function startFocusWatchdog()
    CreateThread(function()
        while inSelection do
            if not IsNuiFocused() then
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(false)
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

---Shifts the aim point sideways so the subject sits off centre in frame.
---Aiming left of the character makes the character appear to the right.
---@param camPos vector3
---@param lookAt vector3
---@return vector3 adjusted aim point
local function applySubjectShift(camPos, lookAt)
    local ratio = Config.Camera.subjectShiftRatio
    if not ratio or ratio == 0.0 then return lookAt end

    local dx, dy = lookAt.x - camPos.x, lookAt.y - camPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return lookAt end

    -- Scaled by distance, so the framing holds however far away the camera is.
    local shift = len * ratio

    -- Perpendicular to the view direction, in the ground plane.
    return vec3(lookAt.x + (-dy / len) * shift, lookAt.y + (dx / len) * shift, lookAt.z)
end

---Camera position and aim point for whichever scene is active.
---@return vector3 camPos, vector3 lookAt
local function cameraFraming(usingShell)
    if usingShell then
        -- The camera always aims at the character. Only its position is
        -- tunable, which makes it impossible to frame a shot the subject is
        -- not in.
        local camPos = Config.Shell.coords + Config.Shell.camOffset
        local lookAt = pedPosition() + vec3(0.0, 0.0, Config.Shell.lookHeight or 0.9)
        return camPos, applySubjectShift(camPos, lookAt)
    end

    -- Offsets are relative to the ped and rotated by its heading, so the camera
    -- always ends up in front of the character rather than at a fixed compass
    -- position that only works for one heading.
    local ped = pedPosition()
    local rad = math.rad(pedHeading())
    local off = Config.Fallback.camOffset

    local camPos = vec3(
        ped.x + math.sin(-rad) * off.y,
        ped.y + math.cos(-rad) * off.y,
        ped.z + off.z
    )

    -- Same rule as the shell scene: always aim at the character.
    local lookAt = ped + vec3(0.0, 0.0, Config.Fallback.lookHeight or 0.9)
    return camPos, applySubjectShift(camPos, lookAt)
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
---@param gender number
---@param appearance table|string|nil the character's stored appearance
local function setPreviewPed(gender, appearance)
    destroyPreviewPed()

    local modelName = Config.PedModels[gender] or Config.PedModels[0]
    local model = joaat(modelName)
    if not requestModel(model) then return end

    local pos = pedPosition()
    previewPed = CreatePed(2, model, pos.x, pos.y, pos.z, pedHeading(), false, true)

    -- CreatePed applies an internal vertical offset, SetEntityCoordsNoOffset
    -- does not. Left alone, the ped spawns floating and then snaps to the
    -- right height the first time tuning moves it, so the tuned value never
    -- matches what appears on a fresh load. Re-apply the position through the
    -- same call the rebuild path uses, so both agree.
    SetEntityCoordsNoOffset(previewPed, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(previewPed, pedHeading())

    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetModelAsNoLongerNeeded(model)

    -- Dress the ped as the character actually looks.
    --
    -- This was SetPedDefaultComponentVariation, so every slot showed the same
    -- freemode default regardless of what the character was wearing. The stored
    -- blob arrives as JSON from the database, so it is decoded here rather than
    -- assumed to already be a table.
    if type(appearance) == 'string' then
        local ok, decoded = pcall(json.decode, appearance)
        appearance = ok and decoded or nil
    end

    local dressed = false

    if type(appearance) == 'table' and GetResourceState('som-appearance') == 'started' then
        -- applyToPed deliberately does NOT change the model. Appearance.Apply
        -- swaps it with SetPlayerModel, which acts on the PLAYER, so using it
        -- here would leave the preview untouched and change your own body.
        dressed = exports['som-appearance']:applyToPed(previewPed, appearance) == true
    end

    -- A character created before appearances were stored, or som-appearance
    -- being down, still gets a dressed ped rather than a bald naked one.
    if not dressed then SetPedDefaultComponentVariation(previewPed) end

    -- Idle animation, so the character reads as a person rather than a mannequin.
    -- Picked at random so the screen is not identical every single time.
    local anims = Config.IdleAnims
    if anims and #anims > 0 then
        local pick = anims[math.random(#anims)]
        if requestAnim(pick.dict) then
            TaskPlayAnim(previewPed, pick.dict, pick.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end
end

---Sets the focal range from the camera's distance to the CHARACTER.
---
---Focusing on the aim point instead looks correct until the aim point is moved
---away from the character, which tuning encourages: the focal plane then sits
---in empty space and the character blurs. The subject is always the ped.
---@param camPos vector3
local function applyDof(camPos)
    local dof = Config.Camera.dof
    if not (cam and dof and dof.enabled) then return end

    local distance = #(camPos - pedPosition())
    if distance < 0.5 then distance = 0.5 end

    SetCamNearDof(cam, distance * (dof.nearScale or 0.45))
    SetCamFarDof(cam, distance * (dof.farScale or 1.7))
end

---Slow horizontal drift around the subject, so the shot is not a dead frame.
---Reads sceneCam and sceneLookAt every iteration rather than capturing them,
---so moving the camera while it runs actually sticks.
local function startCameraOrbit()
    local orbit = Config.Camera.orbit
    if not (orbit and orbit.enabled) then return end

    CreateThread(function()
        local period = orbit.seconds * 1000.0
        local sweep = math.rad(orbit.degrees) * 0.5
        local started = GetGameTimer()

        while inSelection and cam do
            if orbitPaused or not sceneCam or not sceneLookAt then
                Wait(100)
            else
                local base, lookAt = sceneCam, sceneLookAt
                local radius = #(vec3(base.x, base.y, 0.0) - vec3(lookAt.x, lookAt.y, 0.0))
                local baseAngle = math.atan(base.y - lookAt.y, base.x - lookAt.x)

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

    -- Freeze the clock and weather so the shot is lit identically for every
    -- player, rather than depending on whatever hour the server is at.
    --
    -- Re-asserted on a loop: a single call is not enough, because the clock
    -- keeps advancing underneath and anything else that syncs time will win.
    -- Sitting on the character screen long enough otherwise drifts into night.
    if Config.Scene.freezeTimeAndWeather then
        CreateThread(function()
            while inSelection do
                NetworkOverrideClockTime(Config.Scene.hour, Config.Scene.minute, 0)
                SetWeatherTypeNowPersist(Config.Scene.weather)
                SetWeatherTypePersist(Config.Scene.weather)
                Wait(1000)
            end
        end)
    end

    local usingShell = createShell()

    local camPos, lookAt = cameraFraming(usingShell)
    sceneCam, sceneLookAt = camPos, lookAt

    if cam then DestroyCam(cam, true) end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(cam, Config.Camera.fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Shallow depth of field is what sells the shot: the character stays sharp
    -- while everything behind reduces to colour and shape. It matters most in
    -- the fallback scene, which is outdoors and would otherwise just look like
    -- a player stood in a street.
    local dof = Config.Camera.dof
    if dof and dof.enabled then
        SetCamUseShallowDofMode(cam, true)
        applyDof(camPos)
        SetCamDofStrength(cam, dof.strength)

        -- SetUseHiDof only applies for the frame it is called on, so it has to
        -- run every frame for the whole time the scene is up.
        CreateThread(function()
            while inSelection and cam do
                SetUseHiDof()
                Wait(0)
            end
        end)
    end

    startCameraOrbit()

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

    -- The radar is NOT turned back on here. som-hud owns it and shows it in a
    -- vehicle only; turning it on at spawn put it on screen on foot and left
    -- som-hud's cached view of the state wrong. Character selection turning it
    -- off is still this file's business, restoring it is not.

    -- Hand the clock and weather back to the server.
    if Config.Scene.freezeTimeAndWeather then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        NetworkClearClockTimeOverride()
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
end

-- Rebuilds the camera and preview ped in place, so live tuning can show the
-- result immediately without tearing the whole selection down.
-- Holds the shot still while framing. A drifting camera makes it impossible to
-- judge whether an offset is right.
AddEventHandler('som-multichar:client:setOrbit', function(enabled)
    orbitPaused = not enabled
end)

---Applies a screen-relative nudge to the scene.
---
---The conversion lives here rather than in tuning.lua because it reads the
---camera's REAL rotation. Deriving the axes from config values instead meant
---they described a camera orientation that was not the one being rendered, so
---the arrow keys did not match what the screen showed.
---@param what string 'cam' or 'ped'
---@param dx number screen right
---@param dy number screen forward, away from the camera
---@param dz number up
AddEventHandler('som-multichar:client:nudgeScene', function(what, dx, dy, dz)
    if not inSelection or not cam then return end

    local heading = math.rad(GetCamRot(cam, 2).z)

    -- GTA heading 0 faces +y and increases anticlockwise.
    local fx, fy = -math.sin(heading), math.cos(heading)
    local rx, ry = fy, -fx

    local delta = vec3(dx * rx + dy * fx, dx * ry + dy * fy, dz)

    if what == 'ped' then
        Config.Shell.pedOffset = Config.Shell.pedOffset + delta
    else
        Config.Shell.camOffset = Config.Shell.camOffset + delta

        -- A pedestal move, not a tilt. The camera always aims at the
        -- character, so raising or lowering it alone would only re-angle the
        -- shot around the same point. Moving the aim height by the same amount
        -- keeps the view level and slides the whole framing up or down, which
        -- is what actually brings more of the body into shot.
        if dz ~= 0 then
            Config.Shell.lookHeight = (Config.Shell.lookHeight or 0.9) + dz
        end
    end

    TriggerEvent('som-multichar:client:rebuildScene')
end)

AddEventHandler('som-multichar:client:rebuildScene', function()
    if not inSelection or not cam then return end

    local camPos, lookAt = cameraFraming(Config.Shell.enabled and shellObject ~= nil)

    -- Update the shared framing, not just the camera. The orbit thread reads
    -- these every frame and would otherwise put the camera straight back.
    sceneCam, sceneLookAt = camPos, lookAt

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)

    -- FOV is tunable, so it has to be re-applied here and not only at scene
    -- creation, or zooming would do nothing until the next reload.
    SetCamFov(cam, Config.Camera.fov)

    -- Keep the focal range matched while tuning, or the character drifts out
    -- of focus as the camera or the character is moved.
    applyDof(camPos)

    if previewPed and DoesEntityExist(previewPed) then
        local pos = pedPosition()
        SetEntityCoordsNoOffset(previewPed, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(previewPed, pedHeading())
    end
end)

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

    -- The slot cap is per player and comes from the server. Reading a local
    -- config value would show everyone the same number regardless of what they
    -- are actually entitled to.
    --
    -- Guarded: if som-core is restarting or is an older build without this
    -- callback, ox_lib raises rather than returning nil, which would otherwise
    -- take the whole character screen down. Falling back to the free tier is
    -- safe, since the server enforces the real cap on create regardless.
    local ok, entitlements = pcall(function()
        return lib.callback.await('som:server:getEntitlements', false)
    end)

    if not ok or type(entitlements) ~= 'table' then
        print('^3[som-multichar]^7 entitlements unavailable, defaulting to the free tier. Restart som-core.')
        entitlements = {}
    end

    -- Put somebody in the scene before the UI appears.
    --
    -- setPreviewPed used to be reachable only from the creation form's gender
    -- picker, so opening the selector with existing characters showed an empty
    -- room. Going into "create a character" and back spawned one, which is why
    -- it looked like the ped was there all along and had simply failed to
    -- render the first time.
    --
    -- Defaults to the first character's gender; the roster updates it when a
    -- different slot is highlighted.
    local first = characters[1]
    setPreviewPed(first and tonumber(first.gender) or 0, first and first.appearance)

    SendNUIMessage({
        action = 'open',
        characters = characters,
        maxSlots = entitlements.slots or 3,
        tier = entitlements.label,
        nationalities = Config.Nationalities,
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    startFocusWatchdog()

    DoScreenFadeIn(800)
end

local function closeSelection()
    if not inSelection then return end

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
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
        backstory = data.backstory,
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

---Re-dresses the preview ped for whichever slot is highlighted.
---
---Also serves the creation form's gender picker, which sends no appearance
---because a character being created has none yet. That case falls back to the
---freemode default, which is correct: it is what they will look like until they
---go through the creator.
---
---The appearance comes from the client, and that is fine. It is display data
---the roster was already sent, and dressing a preview ped decides nothing: the
---character's real appearance is loaded server side on spawn.
RegisterNUICallback('previewGender', function(data, cb)
    local gender = tonumber(data and data.gender) or 0
    setPreviewPed(gender, data and data.appearance)
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
-- Spawn
-- ---------------------------------------------------------------------------

---Flies the camera from high above the spawn point down into the player,
---rather than cutting straight to gameplay. Purely cosmetic: it runs after the
---ped is already positioned, so nothing depends on it completing.
---@param spawn table position with x, y, z
local function playSpawnCinematic(spawn)
    local cine = Config.SpawnCinematic
    if not (cine and cine.enabled) then return end

    local from = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(from, spawn.x + cine.distance, spawn.y - cine.distance, spawn.z + cine.height)
    PointCamAtCoord(from, spawn.x, spawn.y, spawn.z)
    SetCamActive(from, true)

    local to = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    SetCamCoord(to, spawn.x + 1.4, spawn.y - 2.2, spawn.z + 0.9)
    PointCamAtCoord(to, spawn.x, spawn.y, spawn.z + 0.2)

    RenderScriptCams(true, false, 0, true, true)
    -- Ease in and out at both ends so the descent settles rather than stopping.
    SetCamActiveWithInterp(to, from, cine.duration, 1, 1)

    CreateThread(function()
        Wait(cine.duration + 150)
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(from, true)
        DestroyCam(to, true)
    end)
end

---Runs the appearance creator IN THE SHELL, before the player ever reaches the
---world.
---
---The alternative was opening it after spawning at the airport, which worked
---but put character creation in a car park. The shell already has the
---interior, the lighting and a camera position that was tuned for exactly this,
---so the creator belongs in it.
---
---The PLAYER's ped is moved into the shell and the preview ped is removed, so
---the editor works on the real thing rather than a stand-in that would then
---have to be copied across.
---@param data table the playerLoaded payload
---@return boolean ran
local function runCreatorInShell(data)
    if GetResourceState('som-appearance') ~= 'started' then return false end

    local ok, needs = pcall(function()
        return exports['som-appearance']:needsCreation()
    end)

    if not ok or not needs then return false end

    -- The selection UI goes, the scene stays.
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)

    destroyPreviewPed()

    local gender = data.charinfo and data.charinfo.gender or 0
    local modelName = Config.PedModels[gender] or Config.PedModels[0]
    local model = joaat(modelName)

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end

    if HasModelLoaded(model) then
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
        SetPedDefaultComponentVariation(PlayerPedId())
    end

    local ped = PlayerPedId()
    local pos = pedPosition()

    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pedHeading())
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)

    DoScreenFadeIn(600)
    exports['som-appearance']:openEditor('creator')

    -- The spawn waits for the creator to be confirmed rather than racing it.
    local finished = false
    local handler = AddEventHandler('som-appearance:client:finished', function()
        finished = true
    end)

    while not finished do Wait(100) end
    RemoveEventHandler(handler)

    return true
end

RegisterNetEvent('som:client:playerLoaded', function(data)
    if type(data) ~= 'table' then return end

    -- New characters are built in the shell first. Only once that is confirmed
    -- does the fade to the world happen.
    runCreatorInShell(data)

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

    playSpawnCinematic(spawn)

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
        SetNuiFocus(false, false)
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
