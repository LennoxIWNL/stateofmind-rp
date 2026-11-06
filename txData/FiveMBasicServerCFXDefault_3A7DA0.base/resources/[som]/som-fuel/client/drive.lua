--- Burns fuel while the driver's engine runs, warns when low, cuts the engine at
--- zero, and applies fuel the server wrote to a vehicle's state bag. Once a
--- second for the one vehicle being driven, never per frame.

local warned = {}

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

AddStateBagChangeHandler('fuel', nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not IsEntityAVehicle(entity) then return end
    SetVehicleFuelLevel(entity, value + 0.0)
end)

CreateThread(function()
    local d = Config.drain
    local ticks = 0

    while true do
        Wait(1000)
        local ped = cache.ped
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and GetVehicleClass(vehicle) ~= 13 then
            local state = Entity(vehicle).state
            local fuel = GetVehicleFuelLevel(vehicle)

            if type(state.fuel) == 'number' and math.abs(state.fuel - fuel) > 1.0 then
                fuel = state.fuel
            end

            if GetIsVehicleEngineRunning(vehicle) then
                fuel = math.max(0.0, fuel - (d.base + d.perSpeed * GetEntitySpeed(vehicle)))
            end
            SetVehicleFuelLevel(vehicle, fuel + 0.0)

            ticks = ticks + 1
            if ticks >= d.publishEvery then
                ticks = 0
                state:set('fuel', math.floor(fuel * 10) / 10, true)
            end

            if fuel <= 0.0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            elseif fuel < d.warnBelow and not warned[vehicle] then
                warned[vehicle] = true
                say('Fuel is low', 'error')
            elseif fuel >= d.warnBelow then
                warned[vehicle] = nil
            end
        end
    end
end)
