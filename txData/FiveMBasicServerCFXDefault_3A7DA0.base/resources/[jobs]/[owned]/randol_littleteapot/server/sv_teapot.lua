local QBCore = exports['qb-core']:GetCoreObject() -- Core

RegisterNetEvent('QBCore:Server:UpdateObject', function()
	if source ~= '' then return false end
	QBCore = exports['qb-core']:GetCoreObject()
end)


-- USEABLE ITEMS --          

QBCore.Functions.CreateUseableItem("pancakesbb", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("pancakesmaple", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("baconegg", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("teapotorange", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("teapotcoffee", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("teapottea", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("smoothieor", function(source, item) -- orange
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("smoothiera", function(source, item) -- raspberry
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("smoothiest", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name) -- strawberry
    end
end)

QBCore.Functions.CreateUseableItem("smoothiema", function(source, item) -- mango
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Drink", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("bltsandwich", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("ltbox", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:unpack", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("ltdonut", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("ltcroissant", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)

QBCore.Functions.CreateUseableItem("ltcookies", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot) then
        TriggerClientEvent("randol_littleteapot:client:Eat", src, item.name)
    end
end)


-- BILLING --          

RegisterServerEvent("randol_littleteapot:bill:player")
AddEventHandler("randol_littleteapot:bill:player", function(playerId, amount)
    local biller = QBCore.Functions.GetPlayer(source)
    local billed = QBCore.Functions.GetPlayer(tonumber(playerId))
    local amount = tonumber(amount)
    if biller.PlayerData.job.name == 'teapot' then
        if billed ~= nil then
            if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                if amount and amount > 0 then
                billed.Functions.RemoveMoney('bank', amount)
                TriggerClientEvent('QBCore:Notify', source, 'You charged a customer.', 'success')
                TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'You have been charged $'..amount..' for your order at Little Teapot.')
                exports['qb-management']:AddMoney('teapot', amount)
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Must be a valid amount above 0', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'You cannot bill yourself', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'Player not online', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'No access', 'error')
    end
end)


-- ADD/REMOVE EVENTS --          

RegisterNetEvent('randol_littleteapot:server:makebbpancakes', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'pancakemix', 1)
    exports.ox_inventory:RemoveItem(source, 'blueberries', 1)
    exports.ox_inventory:AddItem(source, 'pancakesbb', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makesyruppancakes', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'pancakemix', 1)
    exports.ox_inventory:RemoveItem(source, 'maplesyrup', 1)
    exports.ox_inventory:AddItem(source, 'pancakesmaple', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makebaconegg', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltmuffin', 1)
    exports.ox_inventory:RemoveItem(source, 'ltbacon', 1)
    exports.ox_inventory:RemoveItem(source, 'ltcheese', 1)
    exports.ox_inventory:RemoveItem(source, 'lteggs', 1)
    exports.ox_inventory:AddItem(source, 'baconegg', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makeBLT', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltbacon', 1)
    exports.ox_inventory:RemoveItem(source, 'ltlettuce', 1)
    exports.ox_inventory:RemoveItem(source, 'lttomato', 1)
    exports.ox_inventory:RemoveItem(source, 'ltbuns', 1)
    exports.ox_inventory:AddItem(source, 'bltsandwich', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makeOJ', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'oranges', 1)
    exports.ox_inventory:AddItem(source, 'teapotorange', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makeCoffee', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'coffeebeans', 1)
    exports.ox_inventory:AddItem(source, 'teapotcoffee', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makeTea', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltteabags', 1)
    exports.ox_inventory:AddItem(source, 'teapottea', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makesmoothieOrange', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'oranges', 1)
    exports.ox_inventory:AddItem(source, 'smoothieor', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makesmoothieRaspberry', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltraspberry', 1)
    exports.ox_inventory:AddItem(source, 'smoothiera', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makesmoothieStrawberry', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltstrawberry', 1)
    exports.ox_inventory:AddItem(source, 'smoothiest', 1)
end)

RegisterNetEvent('randol_littleteapot:server:makesmoothieMango', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:RemoveItem(source, 'ltmango', 1)
    exports.ox_inventory:AddItem(source, 'smoothiema', 1)
end)

RegisterNetEvent('randol_littleteapot:server:giveBox', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports.ox_inventory:AddItem(source, 'ltbox', 1)
    TriggerClientEvent('QBCore:Notify', source, 'You have your ingredients now.', 'success')
end)

RegisterNetEvent('randol_littleteapot:server:openBox', function() -- Open Ingredients Box.
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    for cum, penis in pairs(Config.BoxIngredients) do
        local amount = 30
        exports.ox_inventory:AddItem(source, penis, amount)
    end
    TriggerClientEvent('QBCore:Notify', source, 'You unpack all the ingredients.', 'success')
end)

RegisterNetEvent('randol_littleteapot:server:buyrandomsweet', function(args) 
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local args = tonumber(args)
    local bank = Player.PlayerData.money['bank']
    if args == 1 then
        if bank >= Config.SweetPrice then
            exports.ox_inventory:AddItem(src, "ltcookies", 1)
            Player.Functions.RemoveMoney('bank', Config.SweetPrice)
            TriggerClientEvent('QBCore:Notify', src, 'You paid $'..Config.SweetPrice..' for a Cookie.', 'success')
            exports['qb-management']:AddMoney('teapot', math.floor(Config.SweetPrice*0.5)) -- Business gets half the money.
            Wait(1000)
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'You can\'t afford this.', 'error')
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        end
    elseif args == 2 then
        if bank >= Config.SweetPrice then
            exports.ox_inventory:AddItem(src, "ltdonut", 1)
            Player.Functions.AddMoney('bank', Config.SweetPrice)
            TriggerClientEvent('QBCore:Notify', src, 'You paid $'..Config.SweetPrice..' for a Donut.', 'success')
            exports['qb-management']:AddMoney('teapot', math.floor(Config.SweetPrice*0.5)) -- Business gets half the money.
            Wait(1000)
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'You can\'t afford this.', 'error')
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        end
    elseif args == 3 then
        if bank >= Config.SweetPrice then
            exports.ox_inventory:AddItem(src, "ltcroissant", 1)
            Player.Functions.AddMoney('bank', Config.SweetPrice)
            TriggerClientEvent('QBCore:Notify', src, 'You paid $'..Config.SweetPrice..' for a Croissant.', 'success')
            exports['qb-management']:AddMoney('teapot', math.floor(Config.SweetPrice*0.5)) -- Business gets half the money.
            Wait(1000)
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'You can\'t afford this.', 'error')
            TriggerClientEvent('randol_littleteapot:client:buyrandomsweet', src)
        end
    end
end)

RegisterNetEvent('randol_littleteapot:purchaseingredients', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local funds = exports['qb-management']:GetAccount('teapot')
    if Player.PlayerData.job.name == "teapot" then
        if Player.PlayerData.job.onduty then
            if funds >= Config.IngredientsPrice then
                exports['qb-management']:RemoveMoney('teapot', Config.IngredientsPrice)
                TriggerClientEvent('QBCore:Notify', src, 'You paid $'..Config.IngredientsPrice..' from the business account.', 'success')
                TriggerClientEvent('randol_littleteapot:client:callforpackage', src)
            else
                TriggerClientEvent('QBCore:Notify', src, 'Funds are looking a little low buddy.', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'You must be clocked in to make orders.', 'error')
        end
    end
end)


