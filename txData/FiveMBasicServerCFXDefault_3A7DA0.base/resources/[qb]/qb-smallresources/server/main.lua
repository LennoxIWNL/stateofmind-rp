local QBCore = exports['qb-core']:GetCoreObject()
local vehNitrous = {}

RegisterNetEvent('tackle:server:TacklePlayer', function(playerId)
    TriggerClientEvent('tackle:client:GetTackled', playerId)
end)

QBCore.Functions.CreateCallback('nos:GetNosLoadedVehs', function(_, cb)
    cb(vehNitrous)
end)

QBCore.Commands.Add('id', 'Check Your ID #', {}, false, function(source)
    TriggerClientEvent('QBCore:Notify', source,  'ID: '..source)
end)

QBCore.Functions.CreateUseableItem('harness', function(source, item)
    TriggerClientEvent('seatbelt:client:UseHarness', source, item)
end)

RegisterNetEvent('equip:harness', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local slotData = exports.ox_inventory:GetSlot(src, item.slot)

    if not slotData.metadata.uses then
        slotData.metadata.uses = Config.HarnessUses - 1
        exports.ox_inventory:SetMetadata(src, item.slot, slotData.metadata)
    elseif slotData.metadata.uses == 1 then
        exports.ox_inventory:RemoveItem(src, 'harness', 1)
    else
        slotData.metadata.uses -= 1
        exports.ox_inventory:SetMetadata(src, item.slot, slotData.metadata)
    end
end)

RegisterNetEvent('seatbelt:DoHarnessDamage', function(hp, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    if hp == 0 then
        exports.ox_inventory:RemoveItem(src, 'harness', 1, nil, data.slot)
    else
        local slotData = exports.ox_inventory:GetSlot(src, data.slot)
        slotData.metadata.uses -= 1
        exports.ox_inventory:SetMetadata(src, data.slot, slotData.metadata)
    end
end)

RegisterNetEvent('qb-carwash:server:washCar', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    if Player.Functions.RemoveMoney('cash', Config.CarWash.defaultPrice, 'car-washed') then
        TriggerClientEvent('qb-carwash:client:washCar', src)
    elseif Player.Functions.RemoveMoney('bank', Config.CarWash.defaultPrice, 'car-washed') then
        TriggerClientEvent('qb-carwash:client:washCar', src)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.dont_have_enough_money'), 'error')
    end
end)

QBCore.Functions.CreateCallback('smallresources:server:GetCurrentPlayers', function(_, cb)
    cb(#GetPlayers())
end)