-- The preview: a translucent vehicle on a scripted camera.
--
-- Exported, because som-dealership needs exactly the same thing and two copies
-- of a camera rig drift the moment either is touched.
--
-- Three decisions worth knowing:
--
-- 1. The preview vehicle is NOT NETWORKED. CreateVehicle(..., false, false)
--    makes it local to this client, so nobody else sees a ghost car sitting in
--    the garage, it costs nothing on the network, and SetEntityAlpha behaves
--    predictably (alpha does not replicate reliably).
--
-- 2. The camera ORBITS; the car does not spin. Rotating a frozen entity jitters
--    and swings the lighting across the bodywork. Moving the camera around a
--    still vehicle keeps the shadows where they belong.
--
-- 3. The saved properties are applied, so the preview shows the player's actual
--    livery, wheels and dirt rather than a stock render. That is the single
--    biggest reason this reads as expensive rather than as a spawn.

Preview = {}

local vehicle = nil
local cam = nil
local anchor = nil        -- vec4 the preview sits on
local angle = 0.0
local dragging = false
local spinning = true
local active = false

-- ---------------------------------------------------------------------------
-- Camera
-- ---------------------------------------------------------------------------

local function updateCamera()
    if not cam or not anchor then return end

    local rad = math.rad(angle)
    local dist = Config.Preview.distance

    SetCamCoord(cam,
        anchor.x + math.cos(rad) * dist,
        anchor.y + math.sin(rad) * dist,
        anchor.z + Config.Preview.height)

    -- Aimed slightly above the ground so the car sits in the lower two thirds
    -- of frame rather than dead centre, which leaves room for the panel.
    PointCamAtCoord(cam, anchor.x, anchor.y, anchor.z + 0.35)
end

-- ---------------------------------------------------------------------------
-- The vehicle
-- ---------------------------------------------------------------------------

local function destroyVehicle()
    if vehicle and DoesEntityExist(vehicle) then
        local model = GetEntityModel(vehicle)
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(model)
    end
    vehicle = nil
end

---Shows a model on the podium, replacing whatever was there.
---@param model string spawn name
---@param props table|nil ox_lib vehicle properties
function Preview.Show(model, props)
    if not active or not anchor then return end

    destroyVehicle()

    local hash = joaat(model)
    if not lib.requestModel(hash, 8000) then return end

    -- isNetwork = false, netMissionEntity = false. Local only.
    vehicle = CreateVehicle(hash, anchor.x, anchor.y, anchor.z, anchor.w, false, false)
    if not vehicle or vehicle == 0 then return end

    if type(props) == 'table' then
        -- The real modifications. pcall because a saved props blob from an
        -- older format should degrade to a stock preview rather than break it.
        pcall(lib.setVehicleProperties, vehicle, props)
    end

    SetEntityInvincible(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 10)
    SetVehicleUndriveable(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)

    -- Walk-through, so the podium is scenery rather than an obstacle.
    SetEntityCollision(vehicle, false, false)

    -- The ghost. Only multiples of 51 do anything, so 153 is the real value
    -- nearest "slightly transparent"; anything from 153 to 203 looks the same.
    -- The third argument is a ped-only flag and must be false here.
    SetEntityAlpha(vehicle, Config.Preview.alpha, false)

    SetModelAsNoLongerNeeded(hash)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

---@param at vector4 where the preview vehicle stands
function Preview.Start(at)
    if active then return end

    active = true
    anchor = at
    angle = (at.w or 0.0) + 130.0
    spinning = true

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, Config.Preview.fov)
    updateCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, true)

    -- The player is hidden rather than moved. Teleporting them to the podium
    -- and back is a whole class of "stuck in a wall" bug for no visual gain.
    SetEntityVisible(cache.ped, false, false)
    FreezeEntityPosition(cache.ped, true)

    CreateThread(function()
        local last = GetGameTimer()

        while active do
            local now = GetGameTimer()
            local dt = (now - last) / 1000
            last = now

            if spinning and not dragging then
                angle = (angle + Config.Preview.idleSpin * dt) % 360.0
            end

            updateCamera()
            Wait(0)
        end
    end)
end

function Preview.Stop()
    if not active then return end

    active = false
    destroyVehicle()

    RenderScriptCams(false, false, 400, true, true)
    if cam then
        DestroyCam(cam, true)
        cam = nil
    end

    SetEntityVisible(cache.ped, true, false)
    FreezeEntityPosition(cache.ped, false)

    anchor = nil
    dragging = false
end

---Rotates the view. Called from the NUI as the mouse is dragged.
---@param delta number pixels moved horizontally
function Preview.Drag(delta)
    if not active then return end

    dragging = true
    spinning = false
    angle = (angle + (tonumber(delta) or 0) * Config.Preview.dragSpeed) % 360.0
    updateCamera()
end

function Preview.EndDrag()
    dragging = false
end

exports('previewStart', Preview.Start)
exports('previewShow', Preview.Show)
exports('previewStop', Preview.Stop)
exports('previewDrag', Preview.Drag)

-- Orphaned ghost cars are the classic failure of a home-made preview, so the
-- teardown is unconditional rather than dependent on the UI closing cleanly.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Preview.Stop()
end)
