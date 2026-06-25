local disableShuffle = true

RegisterNetEvent('QBCore:Client:EnteredVehicle', function(data)
    local ped = PlayerPedId()
    while IsPedInAnyVehicle(ped, false) do
        if disableShuffle and GetPedInVehicleSeat(data.vehicle, 0) == ped and GetIsTaskActive(ped, 165) then
            SetPedIntoVehicle(ped, data.vehicle, 0)
            SetPedConfigFlag(ped, 184, true)
            Wait(0)
        else
            Wait(500) -- Only check frequently when shuffle task is active
        end
    end
end)

RegisterNetEvent('SeatShuffle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        disableShuffle = false
        SetPedConfigFlag(ped, 184, false)
        Wait(3000)
        disableShuffle = true
    else
        CancelEvent()
    end
end)

RegisterCommand('shuff', function()
    TriggerEvent('SeatShuffle')
end, false)
