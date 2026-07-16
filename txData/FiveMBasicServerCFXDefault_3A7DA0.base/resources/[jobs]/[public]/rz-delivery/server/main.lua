local QBCore = exports['qb-core']:GetCoreObject()


RegisterNetEvent('rz-delivery:server:sell', function()
    local src = source
    local price = Config.delivery_payment
    local xplayer = QBCore.Functions.GetPlayer(src)
    local Item = exports.ox_inventory:GetItem(src, Config.delivery_item, nil, false)
    if Item == nil then return end
    exports.ox_inventory:RemoveItem(src, Config.delivery_item, 1)
    xplayer.Functions.AddMoney(Config.money_type, price)
end)

QBCore.Functions.CreateCallback('rz:delivery:server:GetItem', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player ~= nil then
        local item = exports.ox_inventory:GetItem(src, item, nil, false)
        if item ~= nil and not Player.PlayerData.metadata["isdead"] and not Player.PlayerData.metadata["inlaststand"] then
            cb(true)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

