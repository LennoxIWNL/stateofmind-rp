local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('burgershot_bagsmall', function(source)
	TriggerClientEvent('rz-burgershot:CraftSmallBagItem', source)
    TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.success"), "primary", 1500)
end)

RegisterNetEvent('rz-burgershot:SmallBagItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.SmallBag) do
        exports.ox_inventory:AddItem(src, v, 1)
    end
    exports.ox_inventory:RemoveItem(src, Config.SmallBagItem, 1)
end)

QBCore.Functions.CreateUseableItem('burgershot_bagbig', function(source)
	TriggerClientEvent('rz-burgershot:CraftBigBagItem', source)
    TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.success"), "primary", 1500)
end)

RegisterNetEvent('rz-burgershot:BigBagItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.BigBag) do
        exports.ox_inventory:AddItem(src, v, 1)
    end
    exports.ox_inventory:RemoveItem(src, Config.BigBagItem, 1)

end)

QBCore.Functions.CreateUseableItem('burgershot_baggoat', function(source)
	TriggerClientEvent('rz-burgershot:CraftGoatMenuItem', source)
    TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.success"), "primary", 1500)
end)

RegisterNetEvent('rz-burgershot:GoatMenuItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.GoatBag) do
        exports.ox_inventory:AddItem(src, v, 1)
    end
    exports.ox_inventory:RemoveItem(src, Config.GoatBagItem, 1)

end)

QBCore.Functions.CreateUseableItem('burgershot_bagcoffe', function(source)
	TriggerClientEvent('rz-burgershot:CraftCoffeeMenuItem', source)
    TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.success"), "primary", 1500)
end)

RegisterNetEvent('rz-burgershot:CoffeeMenuItem', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.CoffeeBag) do
        exports.ox_inventory:AddItem(src, v, 1)
    end
    exports.ox_inventory:RemoveItem(src, Config.CoffeeBagItem, 1)

end)

RegisterServerEvent('rz-burgershot:givetoyburgershot')
AddEventHandler('rz-burgershot:givetoyburgershot', function(key)
    local src = source
    local items = {"burgershot_toy1", "burgershot_toy2", "burgershot_toy3", "burgershot_toy4", "burgershot_toy5", "burgershot_toy6"}
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local item = items[math.random(1, #items)]
    local amount = 1
    if exports.ox_inventory:AddItem(src, item, amount) then
        TriggerClientEvent("QBCore:Notify", src, Lang:t("notify.toy"), "primary")
    else
        TriggerClientEvent("QBCore:Notify", src, Lang:t("notify.heavy"), "error")
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:smallpacket', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.BleederBurger, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.SmallColaItem, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.SmallPotato, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('rz-burgershot:add:smallpacket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.SmallBag) do
        exports.ox_inventory:RemoveItem(src, v, 1)
    end
    exports.ox_inventory:AddItem(src, Config.SmallBagItem, 1)
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:bigpacket', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.BigKingBurger, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.BigColaItem, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.BigPotato, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('rz-burgershot:add:bigpacket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.BigBag) do
        exports.ox_inventory:RemoveItem(src, v, 1)
    end
    exports.ox_inventory:AddItem(src, Config.BigBagItem, 1)
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:goatpacket', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.Wrap, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.Nuggets, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.Rings, nil, false)
    local item4 = exports.ox_inventory:GetItem(src, Config.BigColaItem, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil and item4 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('rz-burgershot:add:goatpacket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.GoatBag) do
        exports.ox_inventory:RemoveItem(src, v, 1)
    end
    exports.ox_inventory:AddItem(src, Config.GoatBagItem, 1)
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:coffeepacket', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.CoffeeItem, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.Macaroon, nil, false)
    if item1 ~= nil and item2 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('rz-burgershot:add:coffeepacket', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    for k, v in pairs (Config.CoffeeBag) do
        exports.ox_inventory:RemoveItem(src, v, 1)
    end
    exports.ox_inventory:AddItem(src, Config.CoffeeBagItem, 1)
end)

QBCore.Functions.CreateCallback('rz-burgershot:itemcheck', function(source, cb, item)
	local xPlayer = QBCore.Functions.GetPlayer(source)
    local itemcount = exports.ox_inventory:GetItem(source, item, nil, false)
	if itemcount ~= nil then
		cb(true)
	else
        cb(false)
	end
end)

---------Burger Shot Job---------

RegisterNetEvent('rz-burgershot:server:bigcola', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.BigEmptyGlass, 1)
    exports.ox_inventory:AddItem(src, Config.BigColaItem, 1)
end)

RegisterNetEvent('rz-burgershot:server:smallcola', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.SmallEmptyGlass, 1)
    exports.ox_inventory:AddItem(src, Config.SmallColaItem, 1)
end)

RegisterNetEvent('rz-burgershot:server:coffee', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.CoffeeEmptyGlass, 1)
    exports.ox_inventory:AddItem(src, Config.CoffeeItem, 1)
end)

RegisterNetEvent('rz-burgershot:server:bigpotato', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.BigFrozenPotato, 1)
    exports.ox_inventory:RemoveItem(src, Config.BigEmptyCardboard, 1)
    exports.ox_inventory:AddItem(src, Config.BigPotato, 1)
end)

RegisterNetEvent('rz-burgershot:server:smallpotato', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.SmallFrozenPotato, 1)
    exports.ox_inventory:RemoveItem(src, Config.SmallEmptyCardboard, 1)
    exports.ox_inventory:AddItem(src, Config.SmallPotato, 1)
end)

RegisterNetEvent('rz-burgershot:server:rings', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.FrozenRings, 1)
    exports.ox_inventory:RemoveItem(src, Config.SmallEmptyCardboard, 1)
    exports.ox_inventory:AddItem(src, Config.Rings, 1)
end)

RegisterNetEvent('rz-burgershot:server:nuggets', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.FrozenNuggets, 1)
    exports.ox_inventory:RemoveItem(src, Config.BigEmptyCardboard, 1)
    exports.ox_inventory:AddItem(src, Config.Nuggets, 1)
end)

RegisterNetEvent('rz-burgershot:server:meat', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.FrozenMeat, 1)
    exports.ox_inventory:AddItem(src, Config.Meat, 1)
end)

RegisterNetEvent('rz-burgershot:server:bleederburger', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Bread, 1)
    exports.ox_inventory:RemoveItem(src, Config.Meat, 1)
    exports.ox_inventory:RemoveItem(src, Config.Sauce, 1)
    exports.ox_inventory:RemoveItem(src, Config.VegetableCurly, 1)
    exports.ox_inventory:AddItem(src, Config.BleederBurger, 1)
end)

RegisterNetEvent('rz-burgershot:server:bigkingburger', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Bread, 1)
    exports.ox_inventory:RemoveItem(src, Config.Meat, 1)
    exports.ox_inventory:RemoveItem(src, Config.Sauce, 1)
    exports.ox_inventory:RemoveItem(src, Config.VegetableCurly, 1)
    exports.ox_inventory:RemoveItem(src, Config.Cheddar, 1)
    exports.ox_inventory:RemoveItem(src, Config.Tomato, 1)
    exports.ox_inventory:AddItem(src, Config.BigKingBurger, 1)
end)

RegisterNetEvent('rz-burgershot:server:wrap', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Lavash, 1)
    exports.ox_inventory:RemoveItem(src, Config.Meat, 1)
    exports.ox_inventory:RemoveItem(src, Config.Sauce, 1)
    exports.ox_inventory:RemoveItem(src, Config.VegetableCurly, 1)
    exports.ox_inventory:RemoveItem(src, Config.Cheddar, 1)
    exports.ox_inventory:RemoveItem(src, Config.Tomato, 1)
    exports.ox_inventory:AddItem(src, Config.Wrap, 1)
end)
---
RegisterNetEvent('rz-burgershot:server:chocolateicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.ChocolateIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:vanillaicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.VanillaIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:thesmurfsicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.ThesmurfsIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:strawberryicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.StrawberryIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:matchaicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.MatchaIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:ubeicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.UbeIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:smurfetteicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.SmurfetteIceCream, 1)
end)

RegisterNetEvent('rz-burgershot:server:unicornicecream', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Cone, 1)
    exports.ox_inventory:AddItem(src, Config.UnicornIceCream, 1)
end)

RegisterServerEvent('rz-burgershot:server:smallpacketsell')
AddEventHandler('rz-burgershot:server:smallpacketsell', function()
    local xPlayer = QBCore.Functions.GetPlayer(source)

    local smallbag = exports.ox_inventory:GetItem(source, Config.SmallBagItem, nil, false)

    if smallbag ~= nil then
        exports.ox_inventory:RemoveItem(source, Config.SmallBagItem, 1)
        xPlayer.Functions.AddMoney('cash', Config.SmallBagSellPrice)
		TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.deliverynotify") ..Config.SmallBagSellPrice, "primary", 5000)
	end
end)

RegisterServerEvent('rz-burgershot:server:bigpacketsell')
AddEventHandler('rz-burgershot:server:bigpacketsell', function()
    local xPlayer = QBCore.Functions.GetPlayer(source)

    local bigbag = exports.ox_inventory:GetItem(source, Config.BigBagItem, nil, false)

    if bigbag ~= nil then
        exports.ox_inventory:RemoveItem(source, Config.BigBagItem, 1)
        xPlayer.Functions.AddMoney('cash', Config.BigBagSellPrice)
		TriggerClientEvent('QBCore:Notify', source, Lang:t("notify.deliverynotify") ..Config.BigBagSellPrice, "primary", 5000)
	end
end)

RegisterNetEvent('rz-burgershot:server:macaroon', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:AddItem(src, Config.Macaroon, 1)
end)



----------

QBCore.Functions.CreateCallback('rz:eat:server:get:bigpotato', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.BigFrozenPotato, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.BigEmptyCardboard, nil, false)
    if item1 ~= nil and item2 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:smallpotato', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.SmallFrozenPotato, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.SmallEmptyCardboard, nil, false)
    if item1 ~= nil and item2 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:rings', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.FrozenRings, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.SmallEmptyCardboard, nil, false)
    if item1 ~= nil and item2 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:nuggets', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.FrozenNuggets, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.BigEmptyCardboard, nil, false)
    if item1 ~= nil and item2 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:bleederburger', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.Bread, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.Meat, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.Sauce, nil, false)
    local item4 = exports.ox_inventory:GetItem(src, Config.VegetableCurly, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil and item4 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:bigkingburger', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.Bread, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.Meat, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.Sauce, nil, false)
    local item4 = exports.ox_inventory:GetItem(src, Config.Cheddar, nil, false)
    local item5 = exports.ox_inventory:GetItem(src, Config.Tomato, nil, false)
    local item6 = exports.ox_inventory:GetItem(src, Config.VegetableCurly, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil and item4 ~= nil and item5 ~= nil and item6 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('rz:eat:server:get:wrap', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local item1 = exports.ox_inventory:GetItem(src, Config.Lavash, nil, false)
    local item2 = exports.ox_inventory:GetItem(src, Config.Meat, nil, false)
    local item3 = exports.ox_inventory:GetItem(src, Config.Sauce, nil, false)
    local item4 = exports.ox_inventory:GetItem(src, Config.Cheddar, nil, false)
    local item5 = exports.ox_inventory:GetItem(src, Config.Tomato, nil, false)
    local item6 = exports.ox_inventory:GetItem(src, Config.VegetableCurly, nil, false)
    if item1 ~= nil and item2 ~= nil and item3 ~= nil and item4 ~= nil and item5 ~= nil and item6 ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent("ex-burgershot:server:billPlayer", function(playerId, amount)
    local biller = QBCore.Functions.GetPlayer(source)
    local billed = QBCore.Functions.GetPlayer(tonumber(playerId))
    local amount = tonumber(amount)
    if biller.PlayerData.job.name == 'burgershot' then
        if billed ~= nil then
            if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                if amount and amount > 0 then
                billed.Functions.RemoveMoney('bank', amount)
                TriggerClientEvent('QBCore:Notify', source, 'You charged a customer.', 'success')
                TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'You have been charged $'..amount..' for your order at Burgershot.')
                exports['qb-management']:AddMoney('burgershot', amount)
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Must be a valid amount above 0.', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'You cannot bill yourself.', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Player not online', 'error')
        end
    end
end)
