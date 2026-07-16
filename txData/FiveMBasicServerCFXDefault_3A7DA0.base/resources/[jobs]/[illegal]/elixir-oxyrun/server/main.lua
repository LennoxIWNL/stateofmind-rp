-- ElixirFW

local QBCore = exports['qb-core']:GetCoreObject()
local oxyStarted = false
local Cooldown = false
players = {}
entities = {}

RegisterServerEvent('elixir-oxyrun:server:SetOccupied', function(route)
	Config.Routes[route].info.occupied = true
	TriggerClientEvent('elixir-oxyrun:client:SetOccupied', -1, route)
end)

-- Starting Conditions

RegisterServerEvent('elixir-oxyrun:server:startr', function()
    local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if Player.PlayerData.money['cash'] >= Config.RunCost then
		TriggerClientEvent("elixir-oxyrun:client:sendToOxy", src)
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.you_dont_have_enough_money"), 'error')
	end
end)

RegisterServerEvent('elixir-oxyrun:server:TakeMoney', function()
    local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	Player.Functions.RemoveMoney('cash', Config.RunCost)

	if Config.EnableCooldown then
        TriggerEvent('elixir-oxyrun:server:coolout')
	end
end)

-- Cooldown

RegisterServerEvent('elixir-oxyrun:server:coolout', function()
    Cooldown = true
    local timer = Config.Cooldown * 1000
    while timer > 0 do
        Wait(1000)
        timer = timer - 1000
        if timer == 0 then
            Cooldown = false
        end
    end
end)

QBCore.Functions.CreateCallback("elixir-oxyrun:server:coolc",function(source, cb)
    if Cooldown then
        cb(true)
    else
        cb(false) 
    end
end)

-- Minimum Cop Callback

QBCore.Functions.CreateCallback('elixir-oxyrun:server:getCops', function(source, cb)
    local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)


RegisterNetEvent("elixir-oxyrun:server:sendCar")
AddEventHandler("elixir-oxyrun:server:sendCar", function(Routes)
	if oxyStarted == false then
		TriggerClientEvent("elixir-oxyrun:createOxyVehicle", source, Routes)
		
	end
end)

RegisterNetEvent("elixir-oxyrun:server:deliver")
AddEventHandler("elixir-oxyrun:server:deliver", function()
	local Player = QBCore.Functions.GetPlayer(source)
	local hasPackage = exports.ox_inventory:GetItem(source, "package", nil, false)
	local hasBags = exports.ox_inventory:GetItem(source, "markedbills", nil, false)
	local hasBands = exports.ox_inventory:GetItem(source, "bands", nil, false)
	local hasRolls = exports.ox_inventory:GetItem(source, "rolls", nil, false)

	local chance = math.random(0,100)

	if hasPackage then
		if Config.PrintChance then
		print(chance)
	    end
		if Config.GiveItem then
			local chance = math.random(1, 100)
			local itemCount = math.random(Config.MinItemReward, Config.MaxItemReward)
			local itemCount2 = math.random(Config.MinSpecialReward, Config.MaxSpecialReward)

            exports.ox_inventory:AddItem(source, Config.ItemReward, itemCount)
			
			if chance <= Config.SpecialRewardChance then
				exports.ox_inventory:AddItem(source, Config.SpecialItem, itemCount2)
			end
		end

		if Config.CleanMoney then

			if chance < Config.BagChance then
				if hasBags then
					worth = exports.ox_inventory:GetItem(source, 'markedbills', nil, false).metadata.worth
					bagAmount = math.random(exports.ox_inventory:GetItem(source, "markedbills", nil, false).count)
					Player.Functions.AddMoney('cash', bagAmount*worth)

					exports.ox_inventory:RemoveItem(source, "markedbills", bagAmount)
				end
			end

			if chance < Config.BandChance then
				if hasBands then
					bandAmount = math.random(exports.ox_inventory:GetItem(source, "bands", nil, false).count)
					Player.Functions.AddMoney('cash', bandAmount*math.random(Config.BandMinPayout, Config.BandMaxPayout))

					exports.ox_inventory:RemoveItem(source, "bands", bandAmount)
				end
			end

			if chance < Config.RollChance then
				if hasRolls then
					rollAmount = math.random(exports.ox_inventory:GetItem(source, "rolls", nil, false).count)
					Player.Functions.AddMoney('cash', rollAmount*math.random(Config.RollMinPayout, Config.RollMaxPayout))

					exports.ox_inventory:RemoveItem(source, "rolls", rollAmount)
				end
			end
		end
	
		exports.ox_inventory:RemoveItem(source, "package", 1)
	end
end)

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	for i=1, 1000 do
		if GetPlayerPed(i) ~= 0 then
			players[i] = {}
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	CleanUp()
end)

function CleanUp()
	for _, entity in ipairs(entities) do
		if DoesEntityExist(entity) then
			DeleteEntity(entity)
		end
	end
	for k,v in pairs(players) do
	end
	players = {}
	entities = {}
	oxyStarted = false
end

QBCore.Functions.CreateUseableItem('package', function(source) 
	TriggerClientEvent('elixir-oxyrun:client:hasPackage', source) 
end) 


QBCore.Functions.CreateCallback('elixir-oxyrun:server:hasPackage', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local hasPackage = exports.ox_inventory:GetItem(src, "package", nil, false)
 
	if hasPackage ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('elixir-oxyrun:server:canCarry', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
 
	if exports.ox_inventory:AddItem(src, "package", 1) then
		cb(true)
	else
		cb(false)
	end
end)
-- ElixirFW
