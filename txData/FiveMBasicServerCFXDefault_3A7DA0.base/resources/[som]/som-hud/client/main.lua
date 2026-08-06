-- The HUD.
--
-- Read only, in the strongest sense: nothing in this resource changes anything.
-- It watches natives and som-core's client mirror and describes what it sees.
-- There is no NUI callback, no net event in, and no server half, so there is
-- nothing here for a client to lie to.
--
-- Two loops, because the two halves change at very different rates. Both send
-- only on CHANGE. A HUD that posts an identical payload ten times a second is
-- the single easiest way to make a NUI feel heavy, and it is invisible in
-- profiling because each individual message is tiny.

local core = exports['som-core']

local shown = false
local lastStatus = nil
local lastVehicle = nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---GTA player health runs from 100 (dead) to 200 (full), not 0 to 100, so the
---raw value shows a corpse at 50% and full health at 100%.
---@param ped number
---@return number percent 0-100
local function healthPercent(ped)
    local max = GetEntityMaxHealth(ped)
    local floor = 100

    if max <= floor then return 0 end

    local value = (GetEntityHealth(ped) - floor) / (max - floor) * 100

    if value < 0 then return 0 end
    if value > 100 then return 100 end

    return math.floor(value + 0.5)
end

---@param key string
---@return number percent 0-100
local function need(key)
    local value = tonumber(core:getMetadata(key))
    if not value then return 100 end

    if value < 0 then return 0 end
    if value > 100 then return 100 end

    return math.floor(value + 0.5)
end

---Voice, from pma-voice's own replicated state rather than a guess.
---
---`proximity` is set by pma-voice as { index, distance, mode }, where mode is
---the human name of the range: Whisper, Normal, Shouting. Reading the statebag
---means this keeps working if the ranges are reconfigured, which reading a
---local copy of the range table would not.
---@return string mode, boolean talking, boolean radio
local function voice()
    local state = LocalPlayer.state
    local proximity = state and state.proximity

    local mode = type(proximity) == 'table' and proximity.mode or nil

    return type(mode) == 'string' and mode or 'Normal',
        NetworkIsPlayerTalking(PlayerId()) == true,
        state and state.radioActive == true
end

---@return boolean
local function hidden()
    if not core:isPlayerLoaded() then return true end

    if Config.Hide.inPauseMenu and IsPauseMenuActive() then return true end

    if Config.Hide.whenDowned and GetResourceState('som-medical') == 'started' then
        -- pcall, because a som-medical mid restart would otherwise take the HUD
        -- down with it every time it is reloaded.
        local ok, down = pcall(function() return exports['som-medical']:isDowned() end)
        if ok and down then return true end
    end

    return false
end

---Whether two flat tables differ. Used to suppress identical payloads.
---@param a table|nil
---@param b table
---@return boolean
local function changed(a, b)
    if not a then return true end

    for key, value in pairs(b) do
        if a[key] ~= value then return true end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Condition
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.StatusInterval)

        local visible = not hidden()

        if visible ~= shown then
            shown = visible
            SendNUIMessage({ action = 'hud:visible', value = shown })
        end

        if shown then
            local ped = PlayerPedId()
            local mode, talking, radio = voice()

            local payload = {
                health = healthPercent(ped),
                armour = math.floor(GetPedArmour(ped) + 0.5),
                hunger = need('hunger'),
                thirst = need('thirst'),
                voiceMode = mode,
                talking = talking,
                radio = radio,
            }

            if changed(lastStatus, payload) then
                lastStatus = payload
                payload.action = 'hud:status'
                SendNUIMessage(payload)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The vehicle panel
-- ---------------------------------------------------------------------------

local MPH = 2.236936
local KMH = 3.6

CreateThread(function()
    while true do
        Wait(Config.VehicleInterval)

        if not shown then
            if lastVehicle ~= false then
                lastVehicle = false
                SendNUIMessage({ action = 'hud:vehicle', inVehicle = false })
            end
        else
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            -- Passengers get the panel too. Watching the speed of the car you
            -- are being driven in is exactly as useful as watching your own.
            if vehicle and vehicle ~= 0 then
                local unit = Config.SpeedUnit == 'kmh' and KMH or MPH

                local payload = {
                    inVehicle = true,
                    speed = math.floor(GetEntitySpeed(vehicle) * unit + 0.5),
                    unit = Config.SpeedUnit == 'kmh' and 'km/h' or 'mph',
                    gear = GetVehicleCurrentGear(vehicle),
                    engine = math.floor(GetVehicleEngineHealth(vehicle) / 10 + 0.5),
                    warn = GetVehicleEngineHealth(vehicle) < Config.EngineWarnBelow,
                }

                if changed(lastVehicle, payload) then
                    lastVehicle = payload
                    payload.action = 'hud:vehicle'
                    SendNUIMessage(payload)
                end
            elseif lastVehicle ~= false then
                lastVehicle = false
                SendNUIMessage({ action = 'hud:vehicle', inVehicle = false })
            end
        end
    end
end)

-- Forces the next tick of each loop to send, whatever it finds.
--
-- Without this, a change that happens while the HUD is hidden is compared
-- against the value from before it was hidden and suppressed as identical, so
-- the HUD comes back showing the old number until something else moves.
local function invalidate()
    lastStatus = nil
    lastVehicle = nil
end

AddEventHandler('som:client:onPlayerLoaded', invalidate)
AddEventHandler('som:client:onMetadataChanged', invalidate)
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then invalidate() end
end)
