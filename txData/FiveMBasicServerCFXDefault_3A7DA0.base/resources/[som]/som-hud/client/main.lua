-- The HUD, data layer.
--
-- READ ONLY, and that property is worth defending. This file watches natives
-- and som-core's client mirror and describes what it sees. It has no server
-- half and takes no value from the page, so there is nothing here for a client
-- to lie to.
--
-- The ONE inbound surface is the layout editor in client/editor.lua, and it
-- accepts LAYOUT ONLY: positions, scales and which panels are on. Never a
-- value. A player who edits their own HUD layout has changed where their own
-- numbers are drawn and nothing else.
--
-- FOUR LOOPS, at four different rates, because these things change at wildly
-- different speeds and one loop fast enough for the speedometer would be
-- wasteful for the clock. Every one of them sends ONLY ON CHANGE: a HUD posting
-- an identical payload ten times a second is the easiest way to make a NUI feel
-- heavy, and it is invisible in profiling because each message is tiny.
--
-- THE PAYLOAD CONTRACT is documented in ui/apps/som-hud/src/contract.ts. Both
-- sides of every action name must agree; this is ours, so unlike ox_inventory's
-- there is nobody else to break it but us.

local core = exports['som-core']

local shown = false
local last = { status = nil, vehicle = nil, world = nil, player = nil }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---GTA player health runs 100 (dead) to 200 (full), not 0 to 100, so the raw
---value shows a corpse at 50%. This has been copied into ox_inventory's
---som_bridge.lua as well; if it ever changes, both need it.
---@param ped number
---@return number percent
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
---@return number percent
local function need(key)
    local value = tonumber(core:getMetadata(key))
    if not value then return 100 end
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return math.floor(value + 0.5)
end

---Whether two flat tables differ. Nested values are compared by identity, which
---is why every payload below is kept flat.
local function changed(a, b)
    if not a then return true end
    for key, value in pairs(b) do
        if a[key] ~= value then return true end
    end
    return false
end

local function hidden()
    if not core:isPlayerLoaded() then return true end
    if Config.Hide.inPauseMenu and IsPauseMenuActive() then return true end

    if Config.Hide.whenDowned and GetResourceState('som-medical') == 'started' then
        -- pcall, because a som-medical mid restart would otherwise take the HUD
        -- down with it every time that resource is reloaded.
        local ok, down = pcall(function() return exports['som-medical']:isDowned() end)
        if ok and down then return true end
    end

    return false
end

---pma-voice publishes its range as a statebag rather than an export, as
---{ index, distance, mode } where mode is the human name. Reading the bag means
---this keeps working if the ranges are reconfigured.
---@return string mode, boolean talking, number|false radio
local function voice()
    local state = LocalPlayer.state
    local proximity = state and state.proximity

    local mode = type(proximity) == 'table' and proximity.mode or 'Normal'
    local talking = state and state['som:talking'] or MumbleIsPlayerTalking(PlayerId())
    local radio = state and state.radioChannel or false

    return mode, talking == true, radio or false
end

-- ---------------------------------------------------------------------------
-- Condition. Slow: needs move on a timer, health in a firefight.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.Interval.status)

        local visible = not hidden()
        if visible ~= shown then
            shown = visible
            SendNUIMessage({ action = 'hud:visible', value = shown })
        end

        if shown then
            local ped = PlayerPedId()

            -- Oxygen only means anything underwater. Above water the native
            -- reports a full bar forever, which is a gauge that never moves.
            local underwater = IsPedSwimmingUnderWater(ped)
            local oxygen = underwater
                and math.floor(GetPlayerUnderwaterTimeRemaining(PlayerId()) / 10 * 100 + 0.5)
                or 100

            local payload = {
                health = healthPercent(ped),
                armour = math.floor(GetPedArmour(ped) + 0.5),
                hunger = need('hunger'),
                thirst = need('thirst'),
                -- Stress counts UP from zero, unlike the others.
                stress = math.floor((tonumber(core:getMetadata('stress')) or 0) + 0.5),
                oxygen = oxygen > 100 and 100 or (oxygen < 0 and 0 or oxygen),
                underwater = underwater,
            }

            if changed(last.status, payload) then
                last.status = payload
                payload.action = 'hud:status'
                SendNUIMessage(payload)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Vehicle. Fast: the speedometer is the one thing that must not stutter.
-- ---------------------------------------------------------------------------

local MPH = 2.236936
local KMH = 3.6

---Air vehicles get the aviation panel instead of the speedometer. Classes 15
---and 16 are helicopter and plane.
local function isAir(class) return class == 15 or class == 16 end

CreateThread(function()
    while true do
        Wait(Config.Interval.vehicle)

        if not shown then
            if last.vehicle ~= false then
                last.vehicle = false
                SendNUIMessage({ action = 'hud:vehicle', inVehicle = false })
            end
        else
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            -- Passengers get the panel too. Watching the speed of the car you
            -- are being driven in is exactly as useful as watching your own.
            if vehicle and vehicle ~= 0 then
                local class = GetVehicleClass(vehicle)
                local unit = Config.SpeedUnit == 'kmh' and KMH or MPH
                local air = isAir(class)

                local payload = {
                    inVehicle = true,
                    class = class,
                    air = air,
                    -- Bikes get their own speedometer preset, so the page needs
                    -- to know without re-deriving the class list.
                    bike = class == 8 or class == 13,
                    speed = math.floor(GetEntitySpeed(vehicle) * unit + 0.5),
                    unit = Config.SpeedUnit == 'kmh' and 'KMH' or 'MPH',
                    gear = GetVehicleCurrentGear(vehicle),
                    rpm = math.floor(GetVehicleCurrentRpm(vehicle) * 100 + 0.5),
                    engine = math.floor(GetVehicleEngineHealth(vehicle) / 10 + 0.5),
                    warn = GetVehicleEngineHealth(vehicle) < Config.EngineWarnBelow,
                    odometer = math.floor(GetEntitySpeed(vehicle)),
                    seatbelt = Seatbelt and Seatbelt.IsOn() or false,
                    lights = false,
                    -- FUEL IS NOT WIRED. No fuel resource runs on this server:
                    -- cdn-fuel fails at load and ox_fuel is not installed. The
                    -- gauge is built and reads nil, so the page renders it
                    -- inert rather than pinned at a number that never moves,
                    -- which is what teaches players to ignore a HUD.
                    fuel = Config.FuelResource and GetVehicleFuelLevel(vehicle) or nil,
                    electric = IsThisModelACar(GetEntityModel(vehicle))
                        and GetVehicleHasKers(vehicle) or false,
                }

                if air then
                    local pitch = GetEntityPitch(vehicle)
                    local roll = GetEntityRoll(vehicle)
                    payload.pitch = math.floor(pitch + 0.5)
                    payload.roll = math.floor(roll + 0.5)
                    payload.altitude = math.floor(GetEntityHeightAboveGround(vehicle) + 0.5)
                end

                if changed(last.vehicle, payload) then
                    last.vehicle = payload
                    payload.action = 'hud:vehicle'
                    SendNUIMessage(payload)
                end
            elseif last.vehicle ~= false then
                last.vehicle = false
                SendNUIMessage({ action = 'hud:vehicle', inVehicle = false })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- World. Heading and street, at a rate a human can read.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.Interval.world)

        if shown then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            -- GetStreetNameAtCoord returns TWO hashes: the street and the
            -- crossing street. The second is zero when there is no junction,
            -- which is what makes "PALOMINO AVENUE / PROSPERITY STREET" collapse
            -- to one name mid block rather than showing a stale crossing.
            local street, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)

            local payload = {
                heading = math.floor(GetEntityHeading(ped) + 0.5),
                street = GetStreetNameFromHashKey(street),
                crossing = crossing ~= 0 and GetStreetNameFromHashKey(crossing) or '',
                zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
            }

            if changed(last.world, payload) then
                last.world = payload
                payload.action = 'hud:world'
                SendNUIMessage(payload)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Player. Slowest: money, job, time and voice.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.Interval.player)

        if shown then
            local data = core:getPlayerData() or {}
            local money = data.money or {}
            local job = core:getJob() or {}
            local gang = core:getGang() or {}
            local mode, talking, radio = voice()

            local payload = {
                cash = math.floor(tonumber(money.cash) or 0),
                bank = math.floor(tonumber(money.bank) or 0),
                job = job.label or job.name or '',
                jobGrade = job.gradeLabel or '',
                gang = gang.label or gang.name or '',
                onduty = job.onduty == true,
                hour = GetClockHours(),
                minute = GetClockMinutes(),
                players = GetNumberOfPlayers(),
                voiceMode = mode,
                talking = talking,
                radio = radio,
            }

            if changed(last.player, payload) then
                last.player = payload
                payload.action = 'hud:player'
                SendNUIMessage(payload)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The minimap
--
-- IN A VEHICLE ONLY. Owner's call, and it is the same reasoning the street name
-- follows: on foot you can see where you are, and a radar permanently in the
-- corner is GTA's habit rather than a roleplay server's. Driving is the one
-- case where you genuinely cannot see far enough ahead.
--
-- DisplayRadar is the whole mechanism. Nothing else touches the radar, so there
-- is no other owner of this state to fight with.
-- ---------------------------------------------------------------------------

CreateThread(function()
    local shownRadar = nil

    while true do
        Wait(300)

        local want = false

        if core:isPlayerLoaded() and not IsPauseMenuActive() then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            want = vehicle ~= nil and vehicle ~= 0
        end

        -- Only when it CHANGES. DisplayRadar every tick is a native call three
        -- times a second for nothing.
        if want ~= shownRadar then
            shownRadar = want
            DisplayRadar(want)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Invalidation
--
-- Forces the next tick of every loop to send whatever it finds.
--
-- Without this, a change that happens WHILE THE HUD IS HIDDEN is compared
-- against the value from before it was hidden and suppressed as identical, so
-- the HUD comes back showing the old number until something else moves. Subtle,
-- and it will not show up in casual testing.
-- ---------------------------------------------------------------------------

function InvalidateHud()
    last.status, last.vehicle, last.world, last.player = nil, nil, nil, nil
end

AddEventHandler('som:client:onPlayerLoaded', InvalidateHud)
AddEventHandler('som:client:onMetadataChanged', InvalidateHud)
AddEventHandler('som:client:onMoneyChanged', InvalidateHud)
AddEventHandler('som:client:onJobChanged', InvalidateHud)
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then InvalidateHud() end
end)
