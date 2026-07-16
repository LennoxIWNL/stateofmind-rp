local QBCore = exports['qb-core']:GetCoreObject()

for _, s in pairs(Config.Seeds) do
    QBCore.Functions.CreateUseableItem(s.item, function(source, item)
        TriggerClientEvent('jc-drugs:client:plantweed', source, s.item, s.name, s.reward, s.time, s.stageInterval, s.lowQualityReward, s.midQualityReward, s.highQualityReward, nil)
    end)
end

RegisterServerEvent('jc-drugs:server:removeSeed')
AddEventHandler('jc-drugs:server:removeSeed', function(seed)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:RemoveItem(src, seed, 1)
end)

RegisterServerEvent('jc-drugs:server:removeitem')
AddEventHandler('jc-drugs:server:removeitem', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:RemoveItem(src, item, 1)
end)

RegisterServerEvent('jc-drugs:server:giveWeed')
AddEventHandler('jc-drugs:server:giveWeed', function(reward, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local baggy = exports.ox_inventory:GetItem(src, Config.Weedbag, nil, false)

    if baggy and baggy.count >= amount then
        exports.ox_inventory:AddItem(src, reward, amount)
        exports.ox_inventory:RemoveItem(src, Config.Weedbag, amount)
    else
        QBCore.Functions.Notify(src, 'You don\'t have enough bags!', 'error', 3000)
    end
end)

RegisterServerEvent('jc-drugs:server:giveCokeLeafs')
AddEventHandler('jc-drugs:server:giveCokeLeafs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:AddItem(src, Config.LeafItem, Config.LeafAmount)
end)

RegisterServerEvent('jc-drugs:server:givecoke')
AddEventHandler('jc-drugs:server:givecoke', function(ingredients)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    for _, i in pairs(ingredients) do
        exports.ox_inventory:RemoveItem(src, i.item, i.amount)
    end

    exports.ox_inventory:AddItem(src, Config.CokeItem, Config.CokeAmount)

    exports.ox_inventory:RemoveItem(src, Config.Weedbag, Config.CokeAmount)
end)

RegisterServerEvent('jc-drugs:server:removecokeitems')
AddEventHandler('jc-drugs:server:removecokeitems', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    for _, i in pairs(ingredients) do
        exports.ox_inventory:RemoveItem(src, i.item, i.amount)
    end
end)

RegisterServerEvent('jc-drugs:server:givebrick')
AddEventHandler('jc-drugs:server:givebrick', function(item, reward, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:RemoveItem(src, item, amount)
    exports.ox_inventory:AddItem(src, reward, 1)
end)

RegisterServerEvent('jc-drugs:server:removedrugs')
AddEventHandler('jc-drugs:server:removedrugs', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:RemoveItem(src, item, amount)
end)

RegisterServerEvent('jc-drugs:server:giveacid')
AddEventHandler('jc-drugs:server:giveacid', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local jerrycan = exports.ox_inventory:GetItem(src, Config.ExtractItem, nil, false)

    if jerrycan and jerrycan.count >= amount then
        exports.ox_inventory:AddItem(src, Config.AcidItem, amount)
        exports.ox_inventory:RemoveItem(src, Config.ExtractItem, amount)
    else
        QBCore.Functions.Notify('You need atleast ' .. amount .. ' Empty jerry cans!', 'error', 3000)
    end
end)

RegisterServerEvent('jc-drugs:server:givemethylamine')
AddEventHandler('jc-drugs:server:givemethylamine', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local jerrycan = exports.ox_inventory:GetItem(src, Config.ExtractItem, nil, false)

    if jerrycan and jerrycan.count >= amount then
        exports.ox_inventory:AddItem(src, Config.MethylamineItem, amount)
        exports.ox_inventory:RemoveItem(src, Config.ExtractItem, amount)
    else
        QBCore.Functions.Notify('You need atleast ' .. amount .. ' Empty jerry cans!', 'error', 3000)
    end
end)

RegisterServerEvent('jc-drugs:server:givegasoline')
AddEventHandler('jc-drugs:server:givegasoline', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local jerrycan = exports.ox_inventory:GetItem(src, Config.ExtractItem, nil, false)

    if jerrycan and jerrycan.count >= amount then
        exports.ox_inventory:AddItem(src, Config.GasolineItem, amount)
        exports.ox_inventory:RemoveItem(src, Config.GasolineExtractItem, amount)
    else
        QBCore.Functions.Notify('You need atleast ' .. amount .. ' Empty jerry cans!', 'error', 3000)
    end
end)

RegisterServerEvent('jc-drugs:server:givecement')
AddEventHandler('jc-drugs:server:givecement', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    exports.ox_inventory:AddItem(src, Config.CementItem, amount)
end)

RegisterServerEvent('jc-drugs:server:givelithium')
AddEventHandler('jc-drugs:server:givelithium', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local chance = math.random(1, 100)

    local item1 = Config.LithiumItems[math.random(1, #Config.LithiumItems)]
    local item2 = Config.LithiumItems[math.random(1, #Config.LithiumItems)]
    
    if chance <= 50 then
        exports.ox_inventory:AddItem(src, item1, math.random(1, 3))
        exports.ox_inventory:AddItem(src, item2, math.random(1, 3))
    else
        exports.ox_inventory:AddItem(src, item1, math.random(1, 2))
    end
end)

RegisterServerEvent('jc-drugs:server:methprocession')
AddEventHandler('jc-drugs:server:methprocession', function(action)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if action == "processed" then
        local hasIngredients = false

        for _, i in pairs(Config.Ingredients) do
            local hasItem = exports.ox_inventory:GetItem(src, i.item, nil, false)

            if not hasItem or hasItem.count < i.amount then
                hasIngredients = false
                break
            else
                hasIngredients = true
                exports.ox_inventory:RemoveItem(src, i.item, i.amount)
            end
        end

        if hasIngredients then
            exports.ox_inventory:AddItem(src, Config.ProcessedMethItem, Config.ProcessedCokeAmount)
        else
            QBCore.Functions.Notify(src, 'You are missing some ingredients!')
        end
    elseif action == "cook" then
        local hasItem = exports.ox_inventory:GetItem(src, Config.ProcessedMethItem, nil, false)

        exports.ox_inventory:RemoveItem(src, Config.ProcessedMethItem, 1)

        exports.ox_inventory:AddItem(src, Config.MethTrayItem, 1)
    elseif action == "cracking" then
        local hasItem = exports.ox_inventory:GetItem(src, Config.ProcessedMethItem, nil, false)

        exports.ox_inventory:RemoveItem(src, Config.MethTrayItem, 1)

        exports.ox_inventory:AddItem(src, Config.MethItem, Config.MethAmount)
    elseif acton == "failedprocession" then
        local hasIngredients = false

        for _, i in pairs(Config.Ingredients) do
            local hasItem = exports.ox_inventory:GetItem(src, i.item, nil, false)

            if not hasItem or hasItem.count < i.amount then
                hasIngredients = false
                QBCore.Functions.Notify(src, 'You don\'t have enough ingredients!', 'error', 3000)
                break
            else
                hasIngredients = true
                exports.ox_inventory:RemoveItem(src, i.item, i.amount)
            end
        end
    elseif acton == "failedcooking" then
        local hasItem = exports.ox_inventory:GetItem(src, Config.ProcessedMethItem, nil, false)

        if not hasItem or hasItem.count < 1 then
            hasIngredients = false
            QBCore.Functions.Notify(src, 'You don\'t have enough ingredients!', 'error', 3000)
        else
            hasIngredients = true
            exports.ox_inventory:RemoveItem(src, Config.ProcessedMethItem, 1)
        end
    elseif acton == "failedcracking" then
        local hasItem = exports.ox_inventory:GetItem(src, Config.MethTrayItem, nil, false)

        if not hasItem or hasItem.count < 1 then
            hasIngredients = false
            QBCore.Functions.Notify(src, 'You don\'t have enough ingredients!', 'error', 3000)
        else
            hasIngredients = true
            exports.ox_inventory:RemoveItem(src, Config.MethTrayItem, 1)
        end
    end
end)

RegisterServerEvent('jc-drugs:server:givecardboarditem')
AddEventHandler('jc-drugs:server:givecardboarditem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local chance = math.random(1, 100)

    local item1 = Config.AcetoneItems[math.random(1, #Config.AcetoneItems)]
    local item2 = Config.AcetoneItems[math.random(1, #Config.AcetoneItems)]
    
    if chance <= 50 then
        exports.ox_inventory:AddItem(src, item1, math.random(1, 3))
        exports.ox_inventory:AddItem(src, item2, math.random(1, 3))
    else
        exports.ox_inventory:AddItem(src, item1, math.random(1, 2))
    end
end)

RegisterServerEvent('jc-drugs:server:givebenzo')
AddEventHandler('jc-drugs:server:givebenzo', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local chance = math.random(1, 100)

    local item1 = Config.BenzocaineItems[math.random(1, #Config.BenzocaineItems)]
    local item2 = Config.BenzocaineItems[math.random(1, #Config.BenzocaineItems)]
    
    if chance <= 50 then
        exports.ox_inventory:AddItem(src, item1, math.random(1, 3))
        exports.ox_inventory:AddItem(src, item2, math.random(1, 3))
    else
        exports.ox_inventory:AddItem(src, item1, math.random(1, 2))
    end
end)
