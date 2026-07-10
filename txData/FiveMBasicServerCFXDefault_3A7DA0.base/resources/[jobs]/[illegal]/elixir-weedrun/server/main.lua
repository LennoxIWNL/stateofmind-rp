-- ElixirFW

local QBCore = exports['qb-core']:GetCoreObject()

local Cooldown = false
local checkpackage = true
local packagerecieved = false
players = {}
entities = {}

-- Starting Conditions

RegisterServerEvent('elixir-weedrun:server:startr', function()
    local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if Player.PlayerData.money['cash'] >= Config.RunCost then
		Player.Functions.RemoveMoney('cash', Config.RunCost)
		TriggerClientEvent('weed-generate-sell-loc', src)
		TriggerClientEvent('elixir-weedrun:client:signoff', src)
		-- TriggerClientEvent('elixir-weedrun:client:email', src)
		TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_refund"), 'error')
		if Config.EnableCooldown then
        TriggerEvent('elixir-weedrun:server:coolout')
		end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.you_dont_have_enough_money"), 'error')
	end
end)


-- Cooldown

RegisterServerEvent('elixir-weedrun:server:coolout', function()
    Cooldown = true
    local timer = Config.Cooldown * 1000
    while timer > 0 do
        Wait(1000)
        timer = timer - 1000
        if timer == 0 then
			TriggerClientEvent('elixir-weedrun:signin', -1)
            Cooldown = false

        end
    end
end)

RegisterServerEvent('elixir-weedrun:server:signoff', function()
	Cooldown = false
end)

QBCore.Functions.CreateCallback("elixir-weedrun:server:coolc",function(source, cb)
    if Cooldown then
        cb(true)
    else
        cb(false) 
    end
end)

-- Weed Run Packaging

QBCore.Functions.CreateCallback('elixir-weedrun:ItemCheck', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local hasItem = exports.ox_inventory:GetItem(src, item, nil, false)

	if hasItem ~= nil then
		if hasItem.count >= Config.ItemAmount then
		  cb(true)
		else
		  cb(false)
		end
	else
		cb(false)
	end
end)

RegisterServerEvent('weed:processWeed', function()
	local src = source
	local ply = QBCore.Functions.GetPlayer(source)

	exports.ox_inventory:RemoveItem(src, 'weedbud', Config.ItemAmount)

	Wait(15000) --15 sn
	TriggerClientEvent('now-can-collect-package', src)
end)


-- Packaging Reward

RegisterServerEvent("elixir-weedrun:server:packagereward", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not packagerecieved then
        packagerecieved = false

        exports.ox_inventory:AddItem(src, "weedpackage", 1)
		TriggerClientEvent('QBCore:Notify', src, Lang:t("success.there_u_go"), 'success')

		TriggerClientEvent('elixir-weedrun:client:removetarget', src)

    else
        TriggerClientEvent('QBCore:Notify', src, "Error!", "error", 2500)
    end
end)	

-- Weed Run Reward

RegisterServerEvent('package-delivered', function()
	local Player = QBCore.Functions.GetPlayer(source)
	local ply = QBCore.Functions.GetPlayer(source)
	local hasBags = exports.ox_inventory:GetItem(source, "markedbills", nil, false)
	local hasBands = exports.ox_inventory:GetItem(source, "bands", nil, false)
	local hasRolls = exports.ox_inventory:GetItem(source, "rolls", nil, false)
	local itemCount = math.random(Config.MinSpecialReward, Config.MaxSpecialReward)

	local chance = math.random(0,100)

	exports.ox_inventory:RemoveItem(source, 'weedpackage', 1)
	ply.Functions.AddMoney('cash', math.random(2500, 4000))

	if chance <= Config.SpecialRewardChance then
		exports.ox_inventory:AddItem(source, Config.SpecialItem, itemCount)
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

	TriggerClientEvent('elixir-weedrun:client:nextdelivery', source)

	end
end)


-- Minimum Cop Callback

QBCore.Functions.CreateCallback('elixir-weedrun:server:getCops', function(source, cb)
    local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
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

QBCore.Functions.CreateUseableItem('weedpackage', function(source) 
	TriggerClientEvent('elixir-weedrun:client:hasPackage', source) 
end) 


QBCore.Functions.CreateCallback('elixir-weedrun:server:hasPackage', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local hasPackage = exports.ox_inventory:GetItem(src, "weedpackage", nil, false)
 
	if hasPackage ~= nil then
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('elixir-weedrun:server:canCarry', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
 
	if exports.ox_inventory:AddItem(src, "package", 1) then
		cb(true)
	else
		cb(false)
	end
end)

-- ElixirFW