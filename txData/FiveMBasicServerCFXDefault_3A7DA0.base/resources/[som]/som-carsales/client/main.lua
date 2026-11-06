--- Menus only. The server finds the car, the buyer and the price rules.

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

CreateThread(function()
    exports['som-interact']:addGlobalVehicle({
        {
            name = 'carsales:sell',
            icon = 'fa-solid fa-handshake',
            label = 'Sell this vehicle',
            distance = 3.0,
            onSelect = function(data)
                local entity = data and data.entity
                if not entity or entity == 0 or not DoesEntityExist(entity) then return end

                local buyer = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
                if not buyer then return notify('There is nobody next to you') end

                local input = lib.inputDialog('Sell this vehicle', {
                    { type = 'number', label = ('Price ($%d to $%d)'):format(Config.minPrice, Config.maxPrice),
                      min = Config.minPrice, max = Config.maxPrice, required = true },
                })
                if not input then return end

                local r = lib.callback.await('som-carsales:server:offer', false, NetworkGetNetworkIdFromEntity(entity),
                    GetPlayerServerId(buyer), math.floor(tonumber(input[1]) or 0))
                if not r or not r.success then return notify(r and r.error or 'Not available') end
                notify('Offer sent, waiting for them', 'success')
            end,
        },
    })
end)

RegisterNetEvent('som-carsales:client:offer', function(offer)
    if type(offer) ~= 'table' or type(offer.price) ~= 'number' or type(offer.tax) ~= 'number' then return end

    local accepted = lib.alertDialog({
        header = 'Buy a vehicle',
        content = ('%s offers you a %s (plate %s) for $%d from your bank. The city takes $%d of that from the seller.'):format(
            tostring(offer.seller), tostring(offer.model), tostring(offer.plate), offer.price, offer.tax),
        cancel = true,
    }) == 'confirm'

    local r = lib.callback.await('som-carsales:server:answer', false, accepted)
    if accepted and r and not r.success then notify(r.error) elseif accepted then notify('The vehicle is yours', 'success') end
end)
