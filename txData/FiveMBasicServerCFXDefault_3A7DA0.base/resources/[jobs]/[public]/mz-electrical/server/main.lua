local QBCore = exports['qb-core']:GetCoreObject()

-----------
--PAYMENT--
-----------

RegisterNetEvent('mz-electrical:server:GetPaymentPrep', function(AntiExploitPrep)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Payment = math.random(Config.JobCompletePrepLow, Config.JobCompletePrepHigh)
    if not AntiExploitPrep then 
        Player.Functions.AddMoney(Config.PaymentType, Payment)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were paid $"..Payment.." into your bank account.", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "PAYMENT RECEIVED", "You were paid $"..Payment.." into your bank account.", 3500, 'success')
        end
    else 
        print("Player attempting to exploit 'mz-electrical:server:GetPaymentPrep' function")
    end  
end)

RegisterNetEvent('mz-electrical:server:GetPayment', function(AntiExploitT1)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Payment = math.random(Config.JobCompleteLow, Config.JobCompleteHigh)
    if not AntiExploitT1 then 
        Player.Functions.AddMoney(Config.PaymentType, Payment)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were paid $"..Payment.." into your bank account.", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "PAYMENT RECEIVED", "You were paid $"..Payment.." into your bank account.", 3500, 'success')
        end
    else 
        print("Player attempting to exploit 'mz-electrical:server:GetPayment' function")
    end 
end)

RegisterNetEvent('mz-electrical:server:GetPaymentTier2', function(AntiExploitT2)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Payment = math.random(Config.JobCompleteTier2Low, Config.JobCompleteTier2High)
    if not AntiExploitT2 then 
        Player.Functions.AddMoney(Config.PaymentType, Payment)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were paid $"..Payment.." into your bank account.", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "PAYMENT RECEIVED", "You were paid $"..Payment.." into your bank account.", 3500, 'success')
        end
    else 
        print("Player attempting to exploit 'mz-electrical:server:GetPaymentTier2' function")
    end 
end)

RegisterNetEvent('mz-electrical:server:GetPaymentTier3', function(AntiExploitT3)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Payment = math.random(Config.JobCompleteTier3Low, Config.JobCompleteTier3High)
    if not AntiExploitT3 then 
        Player.Functions.AddMoney(Config.PaymentType, Payment)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were paid $"..Payment.." into your bank account.", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "PAYMENT RECEIVED", "You were paid $"..Payment.." into your bank account.", 3500, 'success')
        end
    else 
        print("Player attempting to exploit 'mz-electrical:server:GetPaymentTier3' function")
    end 
end)

---------
--ITEMS--
---------

RegisterNetEvent('mz-electrical:server:GetPaymentItems', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local chance = math.random(1, 100)
    local Item1Amount = math.random(Config.Item1AmountLow, Config.Item1AmountHigh)
    local Item2Amount = math.random(Config.Item2AmountLow, Config.Item2AmountHigh)
    local Item3Amount = math.random(Config.Item3AmountLow, Config.Item3AmountHigh)
    local Item4Amount = math.random(Config.Item4AmountLow, Config.Item4AmountHigh)
    local Item5Amount = math.random(Config.Item5AmountLow, Config.Item5AmountHigh)
    local Item6Amount = math.random(Config.Item6AmountLow, Config.Item6AmountHigh)
    if chance <= Config.Item1chance then 
        exports.ox_inventory:AddItem(src, Config.Item1, Item1Amount)
    elseif chance > Config.Item1chance and chance <= (Config.Item1chance + Config.Item2chance) then 
        exports.ox_inventory:AddItem(src, Config.Item2, Item2Amount)
    elseif chance > (Config.Item1chance + Config.Item2chance) and chance <= (Config.Item1chance + Config.Item2chance + Config.Item3chance) then 
        exports.ox_inventory:AddItem(src, Config.Item3, Item3Amount)
    elseif chance > (Config.Item1chance + Config.Item2chance + Config.Item3chance) and chance <= (Config.Item1chance + Config.Item2chance + Config.Item3chance + Config.Item4chance) then
        exports.ox_inventory:AddItem(src, Config.Item4, Item4Amount)
    elseif chance > (Config.Item1chance + Config.Item2chance + Config.Item3chance + Config.Item4chance) and chance <= (Config.Item1chance + Config.Item2chance + Config.Item3chance + Config.Item4chance + Config.Item5chance) then
        exports.ox_inventory:AddItem(src, Config.Item5, Item5Amount)
    elseif chance > (Config.Item1chance + Config.Item2chance + Config.Item3chance + Config.Item4chance + Config.Item5chance) and chance <= (Config.Item1chance + Config.Item2chance + Config.Item3chance + Config.Item4chance + Config.Item5chance + Config.Item6chance) then
        exports.ox_inventory:AddItem(src, Config.Item6, Item6Amount)
    end 
end)

RegisterNetEvent('mz-electrical:server:GetPaymentItemsRare', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local rarechance = math.random(1, 100)
    local Item1RareAmount = math.random(Config.ItemRareAmountLow, Config.ItemRareAmountHigh)
    local Item2RareAmount = math.random(Config.ItemRare2AmountLow, Config.ItemRare2AmountLow)
    if rarechance <= Config.ItemRareChance then 
        exports.ox_inventory:AddItem(src, Config.ItemRare, Item1RareAmount)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were given something else! Nice!", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "RARE ITEM", "You were given something else! Nice!", 3500, 'success')
        end
    elseif rarechance > (Config.ItemRareChance) and rarechance <= (Config.ItemRareChance + Config.ItemRare2Chance) then 
        exports.ox_inventory:AddItem(src, Config.ItemRare2, Item2RareAmount)
        if Config.NotifyType == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, "You were given something else! Nice!", "success", 3500)
        elseif Config.NotifyType == "okok" then
            TriggerClientEvent('okokNotify:Alert', source, "RARE ITEM", "You were given something else! Nice!", 3500, 'success')
        end
    end
end)