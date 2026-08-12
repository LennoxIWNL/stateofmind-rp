-- Emergency lights and siren.
--
-- Q toggles the lightbar, Left Alt toggles the siren. Left Alt is also the eye's
-- key, and that is deliberate rather than an oversight: the eye cannot be used
-- from a driver's seat, so the two never contend for the same press.
--
-- Purely a CLIENT concern. Nothing here is a permission or a reward, it is the
-- switches on a dashboard, so there is no server round trip: the natives below
-- already replicate the vehicle's state to everyone who can see it.
--
-- The one rule that matters: the binds do nothing unless you are DRIVING an
-- emergency vehicle. A civilian pressing Q must not silently flip something.

local binds = {}

-- Both states are TRACKED rather than read back from the game.
--
-- There is no dependable native for "is the siren audible": the obvious
-- candidate is not present in every build, and a control that silently does
-- nothing on some clients is worse than one extra table. Weak keys, so a
-- deleted vehicle does not pin an entry forever.
local lightState = setmetatable({}, { __mode = 'k' })
local sirenState = setmetatable({}, { __mode = 'k' })

---The vehicle this player is DRIVING, if it is an emergency vehicle.
---
---Driver seat only. A passenger reaching over to work the siren is a different
---feature, and one that mostly produces accidents.
---@return number|nil vehicle
--- Config.EmergencyModels keyed by model hash, built once at load.
local EMERGENCY_HASHES = {}

for name in pairs(Config.EmergencyModels) do
    EMERGENCY_HASHES[joaat(name)] = true
end

local function emergencyVehicle()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return nil end

    if GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then return nil end

    -- MATCHED BY HASH, not by display name.
    --
    -- GetDisplayNameFromVehicleModel returns the game LABEL, which a vehicle
    -- pack is free to change when it replaces a model. Keying an allow list on
    -- it means a pack update can silently switch the binds off, and the symptom
    -- is a key that does nothing with no error anywhere.
    --
    -- The hash of the spawn name cannot drift, so the set is built once from
    -- the config's own names.
    return EMERGENCY_HASHES[GetEntityModel(vehicle)] and vehicle or nil
end

-- ---------------------------------------------------------------------------
-- Lights
-- ---------------------------------------------------------------------------

local function toggleLights()
    local vehicle = emergencyVehicle()
    if not vehicle then return end

    local on = not lightState[vehicle]
    lightState[vehicle] = on

    -- The lightbar without the noise. SetVehicleSiren drives the light bar;
    -- the audio is muted separately, which is what makes a silent approach
    -- possible at all.
    SetVehicleSiren(vehicle, on)

    -- Lights alone are silent. Killing the lights also clears the siren, or a
    -- car switched off and on again would come back wailing.
    sirenState[vehicle] = false
    SetVehicleHasMutedSirens(vehicle, true)

    TriggerEvent('som:client:notify',
        on and 'Lights on' or 'Lights off', 'inform', 1500)
end

-- ---------------------------------------------------------------------------
-- Siren
-- ---------------------------------------------------------------------------

local function toggleSiren()
    local vehicle = emergencyVehicle()
    if not vehicle then return end

    -- The siren needs the lights on. A wailing car with no lightbar reads as a
    -- bug, and every police script treats the two as one escalation.
    if not lightState[vehicle] then
        lightState[vehicle] = true
        SetVehicleSiren(vehicle, true)
    end

    local on = not sirenState[vehicle]
    sirenState[vehicle] = on

    -- Muted is the inverse of audible: the lightbar is already running, this
    -- only decides whether it makes noise.
    SetVehicleHasMutedSirens(vehicle, not on)

    TriggerEvent('som:client:notify',
        on and 'Siren on' or 'Siren off', 'inform', 1500)
end

-- ---------------------------------------------------------------------------
-- Binds
--
-- Registered once and enabled only while driving an emergency vehicle, matching
-- how the custody binds are handled. lib.addKeybind cannot be unregistered, so
-- re-registering per vehicle would stack handlers.
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not Config.Keybinds.enabled then return end

    binds.lights = lib.addKeybind({
        name = 'som_police_lights',
        description = Config.Keybinds.lights.description,
        defaultKey = Config.Keybinds.lights.key,
        onPressed = toggleLights,
    })

    binds.siren = lib.addKeybind({
        name = 'som_police_siren',
        description = Config.Keybinds.siren.description,
        defaultKey = Config.Keybinds.siren.key,
        onPressed = toggleSiren,
    })

    for _, bind in pairs(binds) do bind:disable(true) end
end)

-- ox_lib's cache fires this whenever the player enters or leaves a vehicle,
-- which is exactly when these binds should come and go. Polling for it would be
-- a per-frame check for something the framework already reports.
lib.onCache('vehicle', function()
    local allowed = emergencyVehicle() ~= nil

    for _, bind in pairs(binds) do
        bind:disable(not allowed)
    end
end)
