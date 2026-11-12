--- Buttons and a fare readout. The server measures the ride and decides the fare.

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function act(action)
    local r = lib.callback.await('som-taxi:server:act', false, action)
    if not r then return end
    if not r.success then return notify(r.error) end
    if action == 'charge' then notify('Fare sent to the passenger', 'success') end
end

exports('meter', function()
    lib.registerContext({
        id = 'som_taxi_meter',
        title = 'Cab meter',
        options = {
            { title = 'Start the meter', onSelect = function() act('start') end },
            { title = 'Charge the passenger', onSelect = function() act('charge') end },
            { title = 'Stop the meter', onSelect = function() act('stop') end },
        },
    })
    lib.showContext('som_taxi_meter')
end)

RegisterNetEvent('som-taxi:client:meter', function(text)
    if type(text) == 'string' then
        exports['som-interact']:showTextUI(text)
    else
        exports['som-interact']:hideTextUI()
    end
end)

RegisterNetEvent('som-taxi:client:fare', function(fare, meters)
    if type(fare) ~= 'number' or type(meters) ~= 'number' then return end
    local accepted = lib.alertDialog({
        header = 'Cab fare',
        content = ('%d m driven. The fare is $%d, paid from your bank.'):format(meters, fare),
        cancel = true,
    }) == 'confirm'
    local r = lib.callback.await('som-taxi:server:answer', false, accepted)
    if r and not r.success and accepted then notify(r.error) end
end)
