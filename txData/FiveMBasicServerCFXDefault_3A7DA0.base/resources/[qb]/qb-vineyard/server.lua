local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('qb-vineyard:server:getGrapes', function()
    local src = source
    local amount = math.random(Config.GrapeAmount.min, Config.GrapeAmount.max)
    exports.ox_inventory:AddItem(src, "grape", amount)
end)

QBCore.Functions.CreateCallback('qb-vineyard:server:loadIngredients', function(source, cb)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
    local grape = exports.ox_inventory:GetItem(src, 'grapejuice', nil, false)
	if Player.PlayerData.items ~= nil then
        if grape ~= nil then
            if grape.count >= 23 then
                exports.ox_inventory:RemoveItem(src, "grapejuice", 23)
                cb(true)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
                cb(false)
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
            cb(false)
        end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.no_items"), "error")
        cb(false)
	end
end)

QBCore.Functions.CreateCallback('qb-vineyard:server:grapeJuice', function(source, cb)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
    local grape = exports.ox_inventory:GetItem(src, 'grape', nil, false)
	if Player.PlayerData.items ~= nil then
        if grape ~= nil then
            if grape.count >= 16 then
                exports.ox_inventory:RemoveItem(src, "grape", 16)
                cb(true)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
                cb(false)
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
            cb(false)
        end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.no_items"), "error")
        cb(false)
	end
end)

RegisterNetEvent('qb-vineyard:server:receiveWine', function()
	local src = source
    local amount = math.random(Config.WineAmount.min, Config.WineAmount.max)
	exports.ox_inventory:AddItem(src, "wine", amount)
end)

RegisterNetEvent('qb-vineyard:server:receiveGrapeJuice', function()
	local src = source
    local amount = math.random(Config.GrapeJuiceAmount.min, Config.GrapeJuiceAmount.max)
	exports.ox_inventory:AddItem(src, "grapejuice", amount)
end)