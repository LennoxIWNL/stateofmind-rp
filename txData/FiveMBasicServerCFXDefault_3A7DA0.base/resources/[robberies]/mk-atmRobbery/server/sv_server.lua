-- QBCore Exports --
local QBCore = exports['qb-core']:GetCoreObject()

-- Add Money to Player's Balance Once Hack is Successful / Un-Successful --
RegisterNetEvent('mk-atmRobbery:server:AddMoney', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    local Possibility = Config.LuckyItemPossibility
    local Variation = Config.LuckyItemVariation

    --if Possibility == Variation then
        exports.ox_inventory:AddItem(src, Config.LuckyItem, 1)
        Player.Functions.AddMoney('cash', Config.RewardMoney, 'ATM withdrawl')
    --else
        --Player.Functions.AddMoney('cash', Config.RewardMoney, 'ATM withdrawl')
    --end
end)

-- Remove RFID Disruptor on-third eye of an ATM --
QBCore.Functions.CreateCallback('mk-atmRobbery:server:RemoveDisruptor', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local DisruptorScan = exports.ox_inventory:GetItem(src, item, nil, false)
    if DisruptorScan then
        cb(true)
        exports.ox_inventory:RemoveItem(src, Config.ATMRequiredItem, 1)
    else
        cb(false)
    end
end)

-- Police Amount On-Duty --
QBCore.Functions.CreateCallback('mk-atmRobbery:server:PoliceInteger', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayers()
    local PoliceInteger = 0

    for i = 1, #Player do
        local xPlayer = QBCore.Functions.GetPlayer(Player[i])
        if (xPlayer.PlayerData.job.name == 'police' and xPlayer.PlayerData.job.onduty) then
            PoliceInteger = PoliceInteger + 1
        end
    end

    if PoliceInteger >= Config.RequiredPolice then
        cb(true)
    else
        cb(false)
        TriggerClientEvent('QBCore:Notify', src, ('Not enough police'), 'error')
    end
end)