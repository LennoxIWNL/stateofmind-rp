--- The cell: arriving, the bail prompt, leaving. Bolingbroke is shared vanilla
--- geometry, so there is no bucket or void, only a teleport and a key prompt.

local serving = false

local function teleportTo(spawn)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.w)

    local waited = 0
    while not HasCollisionLoadedAroundEntity(ped) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end

    DoScreenFadeIn(600)
end

RegisterNetEvent('som-jail:client:booked', function(spawn)
    serving = true
    teleportTo(spawn)
end)

RegisterNetEvent('som-jail:client:released', function(freedom)
    serving = false
    teleportTo(freedom)
end)

--- Asked on spawn so a relog mid-sentence still shows the bail prompt.
RegisterNetEvent('som:client:playerLoaded', function()
    local res = lib.callback.await('som-jail:server:myStatus', false)
    serving = res and res.serving == true
end)

local function requestBail()
    local quote = lib.callback.await('som-jail:server:bailQuote', false)
    if not quote or not quote.success then
        TriggerEvent('som:client:notify', quote and quote.error or 'not eligible for bail', 'error')
        return
    end

    local confirmed = lib.alertDialog({
        header = 'Request Bail',
        content = ('Bail is $%d. Pay now?'):format(quote.amount),
        cancel = true,
    })
    if confirmed ~= 'confirm' then return end

    local res = lib.callback.await('som-jail:server:requestBail', false)
    if res and res.success then
        TriggerEvent('som:client:notify', ('Bail posted: $%d'):format(res.amount), 'success')
    else
        TriggerEvent('som:client:notify', res and res.error or 'could not post bail', 'error')
    end
end

--- No fixed anchor in a shared yard, so a key prompt rather than a som-interact
--- zone, as with som-housing's shell exit.
CreateThread(function()
    while true do
        local wait = 500

        if serving then
            wait = 0
            exports['som-interact']:showTextUI('Request Bail', { key = 'E' })

            if IsControlJustReleased(0, 38) then
                exports['som-interact']:hideTextUI()
                requestBail()
            end
        elseif exports['som-interact']:isTextUIOpen() then
            exports['som-interact']:hideTextUI()
        end

        Wait(wait)
    end
end)
