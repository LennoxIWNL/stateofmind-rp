-- Seatbelt, and the ejection it exists to prevent.
--
-- AUDIT 21.5 recorded seatbelt as deliberately absent from the old HUD, for a
-- reason worth repeating: it is an ejection-physics feature with an indicator
-- attached, and building only the indicator would have been the wrong half.
-- This is the other half.
--
-- The rule: without a belt, a hard enough stop throws you through the
-- windscreen. With one, it does not. The threshold is per vehicle CLASS,
-- because being flung off a motorcycle is normal and being flung out of a bus
-- is not.

Seatbelt = {}

local belted = false
local wasInVehicle = false
local lastSpeed = 0.0

---Classes that cannot have a belt at all, so the indicator does not appear and
---the key does nothing. Motorcycles, bicycles, and anything not a car.
local NO_BELT = {
    [8] = true,   -- motorcycles
    [13] = true,  -- bicycles
    [14] = true,  -- boats
    [15] = true,  -- helicopters
    [16] = true,  -- planes
    [21] = true,  -- trains
}

---@return boolean
function Seatbelt.IsOn() return belted end

local function canBelt(vehicle)
    if not vehicle or vehicle == 0 then return false end
    return not NO_BELT[GetVehicleClass(vehicle)]
end

local function setBelt(state)
    if belted == state then return end
    belted = state

    -- The ped is only prevented from flying through the glass while belted.
    -- Everything else about the crash is left alone: this is a seatbelt, not
    -- invulnerability.
    SetPedConfigFlag(PlayerPedId(), 32, not belted)

    SendNUIMessage({ action = 'hud:seatbelt', on = belted })
    if InvalidateHud then InvalidateHud() end

    if GetResourceState('som-ui') == 'started' then
        exports['som-ui']:notify(belted and 'Seatbelt on' or 'Seatbelt off', 'inform', 1500, true)
    end
end

RegisterCommand('+somSeatbelt', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not canBelt(vehicle) then return end
    setBelt(not belted)
end, false)

RegisterCommand('-somSeatbelt', function() end, false)
RegisterKeyMapping('+somSeatbelt', 'Toggle seatbelt', 'keyboard', Config.SeatbeltKey)

-- ---------------------------------------------------------------------------
-- Ejection
--
-- Runs per frame ONLY while in a vehicle that could have a belt and is unbelted
-- and moving. Every other case sleeps, because a per-frame loop that runs on
-- foot is the exact thing AUDIT's conventions warn against.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle and vehicle ~= 0 and canBelt(vehicle) then
            wasInVehicle = true
            local speed = GetEntitySpeed(vehicle)

            if not belted and speed > Config.Seatbelt.minSpeed then
                sleep = 0

                -- The DELTA is what matters, not the speed. Braking hard from
                -- 40 is not a crash; going from 40 to 5 in one frame is.
                local drop = lastSpeed - speed

                if drop > Config.Seatbelt.ejectDelta then
                    local coords = GetEntityCoords(ped)
                    local forward = GetEntityForwardVector(vehicle)

                    SetEntityCoords(ped,
                        coords.x + forward.x * 0.8,
                        coords.y + forward.y * 0.8,
                        coords.z + 0.5,
                        true, true, true, false)

                    SetEntityVelocity(ped,
                        forward.x * (lastSpeed * Config.Seatbelt.launch),
                        forward.y * (lastSpeed * Config.Seatbelt.launch),
                        (lastSpeed * Config.Seatbelt.launch) / 3)

                    SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
                    ApplyDamageToPed(ped, Config.Seatbelt.damage, false)
                end
            end

            lastSpeed = speed
        elseif wasInVehicle then
            -- Leaving the vehicle drops the belt, so it is never carried into
            -- the next car as a state the player did not set.
            wasInVehicle = false
            lastSpeed = 0.0
            if belted then setBelt(false) end
        end

        Wait(sleep)
    end
end)
