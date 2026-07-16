
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback("insidetrack:server:getbalance", function(source, cb)
    local src = source 
    local Player = QBCore.Functions.GetPlayer(src)
    local Chips = exports.ox_inventory:GetItem(src, "casino_goldchip", nil, false)
    local minAmount = 100
    if Chips ~= nil then
        if Chips.count >= minAmount then
            Chips = Chips 
        else
            return TriggerClientEvent('QBCore:client:closeBetsNotEnough', src)
        end
    else
        return TriggerClientEvent('QBCore:client:closeBetsZeroChips', src)
    end
end)

RegisterServerEvent("insidetrack:server:placebet", function(bet)
    local src = source 
    local Player = QBCore.Functions.GetPlayer(src)
    local Chips = exports.ox_inventory:GetItem(src, "casino_goldchip", nil, false)
    if Chips ~= nil then
        if Chips.count >= bet then
            exports.ox_inventory:RemoveItem(src, "casino_goldchip", bet)
            TriggerClientEvent('QBCore:Notify', src, "You placed a "..bet.." casino chips bet")
        else
            return TriggerClientEvent('QBCore:client:closeBetsNotEnough', src)
        end
    else
        return TriggerClientEvent('QBCore:client:closeBetsZeroChips', src)
    end
end) 

RegisterServerEvent("insidetrack:server:winnings", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player ~= nil then
        if exports.ox_inventory:AddItem(src, 'casino_goldchip', amount, {["quality"] = 100}) then
            TriggerClientEvent('QBCore:Notify', src, "You Won "..amount.." casino chips!")
        else
            TriggerClientEvent('QBCore:Notify', src, 'You have to much in your pockets', 'error')
        end
    end
end) 

