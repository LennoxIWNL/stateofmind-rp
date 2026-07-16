local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('kevin-sellped:sellitem', function(item, price, itemAmount, payMethod)
    local PlayerId = source
    local Player = QBCore.Functions.GetPlayer(PlayerId)
    if not item then return end
    if exports.ox_inventory:RemoveItem(PlayerId, item, math.abs(itemAmount)) then
        local pay = itemAmount * price
        Player.Functions.AddMoney(payMethod, pay, 'Items Sold')
    end
end)