print "qb-limeysjob made by PenguScripts using the Limeys MLO"
print "version 1.1"

local QBCore = exports['qb-core']:GetCoreObject()


RegisterServerEvent("qb-limeysjob:bill:player")
AddEventHandler("qb-limeysjob:bill:player", function(playerId, amount)
        local biller = QBCore.Functions.GetPlayer(source)
        local billed = QBCore.Functions.GetPlayer(tonumber(playerId))
        local amount = tonumber(amount)
        if biller.PlayerData.job.name == Config.JobName then
            if billed ~= nil then
                if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                    if amount and amount > 0 then
                        MySQL.Async.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender) VALUES (:citizenid, :amount, :society, :sender)', {
                            ['citizenid'] = billed.PlayerData.citizenid,
                            ['amount'] = amount,
                            ['society'] = biller.PlayerData.job.name,
                            ['sender'] = biller.PlayerData.charinfo.firstname
                        })
                        TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
                        TriggerClientEvent('QBCore:Notify', source, 'Invoice Successfully Sent', 'success')
                        TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'New Invoice Received')
                    else
                        TriggerClientEvent('QBCore:Notify', source, 'Must Be A Valid Amount Above 0', 'error')
                    end
                else
                    TriggerClientEvent('QBCore:Notify', source, 'You Cannot Bill Yourself', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'Player Not Online', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'No Access', 'error')
        end
end)

----DRINKS------------------------------------------------


QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientcherrydrink', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local cherry = exports.ox_inventory:GetItem(src, "cherry", nil, false)
    local glass = exports.ox_inventory:GetItem(src, "drink-glass", nil, false)
    if cherry ~= nil and glass ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientlemondrink', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local lemon = exports.ox_inventory:GetItem(src, "lemon", nil, false)
    local glass = exports.ox_inventory:GetItem(src, "drink-glass", nil, false)
    if lemon ~= nil and glass ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientlimedrink', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local lime = exports.ox_inventory:GetItem(src, "lime", nil, false)
    local glass = exports.ox_inventory:GetItem(src, "drink-glass", nil, false)
    if lime ~= nil and glass ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientorangedrink', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local watermelon = exports.ox_inventory:GetItem(src, "orange", nil, false)
    local glass = exports.ox_inventory:GetItem(src, "drink-glass", nil, false)
    if watermelon ~= nil and glass ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientwatermelondrink', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local watermelon = exports.ox_inventory:GetItem(src, "watermelon", nil, false)
    local glass = exports.ox_inventory:GetItem(src, "drink-glass", nil, false)
    if watermelon ~= nil and glass ~= nil then
        cb(true)
    else
        cb(false)
    end
end)



-----COCKTAIL----------------------------------------------------

QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientapplecocktail', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local glass = exports.ox_inventory:GetItem(src, "cocktailglass", nil, false)
    local apple = exports.ox_inventory:GetItem(src, "apple", nil, false)
    local whiskey = exports.ox_inventory:GetItem(src, "whiskey", nil, false)
    if glass ~= nil and apple ~= nil and whiskey ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientbananacocktail', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local glass = exports.ox_inventory:GetItem(src, "cocktailglass", nil, false)
    local banana = exports.ox_inventory:GetItem(src, "banana", nil, false)
    local whiskey = exports.ox_inventory:GetItem(src, "whiskey", nil, false)
    if glass ~= nil and banana ~= nil and whiskey ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientcherrycocktail', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local glass = exports.ox_inventory:GetItem(src, "cocktailglass", nil, false)
    local cherry = exports.ox_inventory:GetItem(src, "cherry", nil, false)
    local whiskey = exports.ox_inventory:GetItem(src, "whiskey", nil, false)
    if glass ~= nil and cherry ~= nil and whiskey ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientkiwicocktail', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local glass = exports.ox_inventory:GetItem(src, "cocktailglass", nil, false)
    local kiwi = exports.ox_inventory:GetItem(src, "kiwi", nil, false)
    local whiskey = exports.ox_inventory:GetItem(src, "whiskey", nil, false)
    if glass ~= nil and kiwi ~= nil and whiskey ~= nil then
        cb(true)
    else
        cb(false)
    end
end)
QBCore.Functions.CreateCallback('qb-limeysjob:server:get:ingredientparadisecocktail', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local glass = exports.ox_inventory:GetItem(src, "cocktailglass", nil, false)
    local apple = exports.ox_inventory:GetItem(src, "apple", nil, false)
    local cherry = exports.ox_inventory:GetItem(src, "cherry", nil, false)
    local kiwi = exports.ox_inventory:GetItem(src, "kiwi", nil, false)
    local banana = exports.ox_inventory:GetItem(src, "banana", nil, false)
    local watermelon = exports.ox_inventory:GetItem(src, "watermelon", nil, false)
    local orange = exports.ox_inventory:GetItem(src, "orange", nil, false)
    local lemon = exports.ox_inventory:GetItem(src, "lemon", nil, false)
    local lime = exports.ox_inventory:GetItem(src, "lime", nil, false)
    local whiskey = exports.ox_inventory:GetItem(src, "whiskey", nil, false)
    if glass ~= nil and cherry ~= nil and apple ~= nil and kiwi ~= nil and banana ~= nil and watermelon ~= nil and orange  ~= nil and lemon ~= nil and lime ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

-- ITEM ADD/REMOVE FUNCTIONS

RegisterNetEvent('qb-limeysjob:server:CherryCocktail', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'cocktailglass', 1)
    exports.ox_inventory:RemoveItem(src, 'whiskey', 1)
    exports.ox_inventory:RemoveItem(src, 'cherry', 1)
    exports.ox_inventory:AddItem(src, 'cherrycocktail', 1)
end)
RegisterNetEvent('qb-limeysjob:server:AppleCocktail', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'cocktailglass', 1)
    exports.ox_inventory:RemoveItem(src, 'whiskey', 1)
    exports.ox_inventory:RemoveItem(src, 'apple', 1)
    exports.ox_inventory:AddItem(src, 'applecocktail', 1)
end)
RegisterNetEvent('qb-limeysjob:server:BananaCocktail', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'cocktailglass', 1)
    exports.ox_inventory:RemoveItem(src, 'whiskey', 1)
    exports.ox_inventory:RemoveItem(src, 'banana', 1)
    exports.ox_inventory:AddItem(src, 'bananacocktail', 1)
end)
RegisterNetEvent('qb-limeysjob:server:KiwiCocktail', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'cocktailglass', 1)
    exports.ox_inventory:RemoveItem(src, 'whiskey', 1)
    exports.ox_inventory:RemoveItem(src, 'kiwi', 1)
    exports.ox_inventory:AddItem(src, 'kiwicocktail', 1)
end)
RegisterNetEvent('qb-limeysjob:server:ParadiseCocktail', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'cocktailglass', 1)
    exports.ox_inventory:RemoveItem(src, 'apple', 1)
    exports.ox_inventory:RemoveItem(src, 'cherry', 1)
    exports.ox_inventory:RemoveItem(src, 'kiwi', 1)
    exports.ox_inventory:RemoveItem(src, 'banana', 1)
    exports.ox_inventory:RemoveItem(src, 'watermelonslice', 1)
    exports.ox_inventory:RemoveItem(src, 'orange', 1)
    exports.ox_inventory:RemoveItem(src, 'lemon', 1)
    exports.ox_inventory:RemoveItem(src, 'lime', 1)
    exports.ox_inventory:RemoveItem(src, 'whiskey', 1)
    exports.ox_inventory:AddItem(src, 'paradisecocktail', 1)
end)
RegisterNetEvent('qb-limeysjob:server:CherryDrink', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'drink-glass', 1)
    exports.ox_inventory:RemoveItem(src, 'cherry', 1)
    exports.ox_inventory:AddItem(src, 'cherrydrink', 1)
end)
RegisterNetEvent('qb-limeysjob:server:LemonDrink', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'drink-glass', 1)
    exports.ox_inventory:RemoveItem(src, 'lemon', 1)
    exports.ox_inventory:AddItem(src, 'lemondrink', 1)
end)
RegisterNetEvent('qb-limeysjob:server:LimeDrink', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'drink-glass', 1)
    exports.ox_inventory:RemoveItem(src, 'lime', 1)
    exports.ox_inventory:AddItem(src, 'limedrink', 1)
end)
RegisterNetEvent('qb-limeysjob:server:OrangeDrink', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'drink-glass', 1)
    exports.ox_inventory:RemoveItem(src, 'orange', 1)
    exports.ox_inventory:AddItem(src, 'orangedrink', 1)
end)
RegisterNetEvent('qb-limeysjob:server:CherryDrink', function()
    local src = source
    local plr = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, 'drink-glass', 1)
    exports.ox_inventory:RemoveItem(src, 'watermelonslice', 1)
    exports.ox_inventory:AddItem(src, 'watermelondrink', 1)
end)
QBCore.Functions.CreateUseableItem('watermelon', function(source)
    exports.ox_inventory:RemoveItem(source, 'watermelon', 1)
    exports.ox_inventory:AddItem(source, 'watermelonslice', math.random(10,16))
    TriggerEvent('qb-limeysjob:WatermelonSlice')
end)
