local QBCore = exports['qb-core']:GetCoreObject()
--============================================================================ Items

QBCore.Functions.CreateUseableItem("anchor", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
		TriggerClientEvent('fishing:client:anchor', source)
    end
end)

QBCore.Functions.CreateUseableItem("fishingrod", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
 		TriggerClientEvent('fishing:fishstart', source)
    end
end)

QBCore.Functions.CreateUseableItem("fishicebox", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
		TriggerClientEvent('fishing:client:useFishingBox', source, item.info.boxid)  
    end
end)

QBCore.Functions.CreateUseableItem("fishinglootbig", function(source, item)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
		TriggerClientEvent("fishing:client:attemptTreasureChest", src)
    end
end)

QBCore.Functions.CreateUseableItem("fishingloot", function(source, item)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
		exports.ox_inventory:RemoveItem(src, "fishingloot", 1)
		TriggerClientEvent('QBCore:Notify', src, "Opening Box", "primary")
		SetTimeout(1000, function()
			exports.ox_inventory:AddItem(src, 'fishingkey', 1, {["quality"] = 100})

			exports.ox_inventory:AddItem(src, Config.smallLootboxReward, 1, {["quality"] = 100})

			Player.Functions.AddMoney('cash', Config.smallLootboxCash, "fishingloot")
			TriggerClientEvent('QBCore:Notify', src, "You found a couple items and $"..Config.smallLootboxCash, "success")
		end)
    end
end)

QBCore.Functions.CreateUseableItem("fishtacklebox", function(source, item)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then

		TriggerClientEvent('QBCore:Notify', src, "Opening Tackel Box", "success")
		exports.ox_inventory:RemoveItem(src, "fishtacklebox", 1)

		SetTimeout(1250, function()
			exports.ox_inventory:AddItem(src, 'pearlscard', 1, {["quality"] = 100})
		end)
    end
end)

--============================================================================ Events

RegisterNetEvent('fishing:server:removeFishingBait', function()
	local src = source
    exports.ox_inventory:RemoveItem(src, 'fishbait', 1)
end)

RegisterNetEvent("fishing:server:addTackleBox", function()
	local src = source
	TriggerClientEvent('QBCore:Notify', src, "There seems to tackle box left over from another fisherman", "primary")
	SetTimeout(1000, function()
		exports.ox_inventory:AddItem(src, 'fishtacklebox', 1, {["quality"] = 100})
	end)
end)

RegisterNetEvent("fishing:server:returnDeposit", function()
	local src = source
    local pData = QBCore.Functions.GetPlayer(src)
	local price = math.floor(Config.BoatPrice/2)
	pData.Functions.AddMoney('bank', price , "boat-rental")
	TriggerClientEvent('QBCore:Notify', src, "Boat has been returned for $"..price, "success")
end) 

RegisterNetEvent('fishing:server:catch', function() 
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local luck = math.random(1, 100)
    local itemFound = true
    local itemCount = 1

    if itemFound then
        for i = 1, itemCount, 1 do
            if luck == 100 then
				local weight = math.random(850,1000)
				local info = {species = "Orca",lbs = weight,type = "Exotic"}
				TriggerClientEvent('fishing:client:spawnFish', src, 1)
				exports.ox_inventory:AddItem(src, 'killerwhale', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a killer whale!\nThese are endangered species and are illegal to possess", "primary")
			elseif luck >= 95 and luck <= 100 then
				exports.ox_inventory:AddItem(src, 'fishinglootbig', 1, {["quality"] = 100})
				TriggerClientEvent('QBCore:Notify', src, "You found a Treasure Chest!", "success")
			elseif luck >= 90 and luck <= 95 then
				local weight = math.random(10,28)
				local info = {species = "Bottlenose",lbs = weight, type = "Exotic"}
				TriggerClientEvent('fishing:client:spawnFish', src, 2)
				exports.ox_inventory:AddItem(src, 'dolphin', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a dolphin!\nThese are endangered species and are illegal to possess", "primary")
			elseif luck >= 85 and luck <= 90 then
				local weight = math.random(20,30)
				local info = {species = "Hammerhead Shark", lbs = weight, type = "Exotic"}
				TriggerClientEvent('fishing:client:spawnFish', src, 3)
				exports.ox_inventory:AddItem(src, 'sharkhammer', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a hammerhead shark!\nThese are endangered species and are illegal to possess", "primary")
			elseif luck >= 80 and luck <= 85 then
				local weight = math.random(1,6)
				local info = {species = "Tiger Shark", lbs = weight, type = "Exotic"}
				TriggerClientEvent('fishing:client:spawnFish', src, 4)
				exports.ox_inventory:AddItem(src, 'sharktiger', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a tiger shark!\nThese are endangered species and are illegal to possess", "primary")
			elseif luck >= 75 and luck <= 80 then
				local weight = math.random(4,9)
				local info = {species = "Manta ray", lbs = weight, type = "Normal"}
				TriggerClientEvent('fishing:client:spawnFish', src, 5)
				exports.ox_inventory:AddItem(src, 'stingray', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a "..weight.."lbs Stingray!", "success")
			elseif luck >= 70 and luck <= 75 then
				local weight = math.random(10,15)
				local info = {species = "Flounder", lbs = weight, type = "Normal"}
				TriggerClientEvent('fishing:client:spawnFish', src, 6)
				exports.ox_inventory:AddItem(src, 'flounder', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a " .. weight .. "lbs Flounder", "success")
			elseif luck >= 65 and luck <= 70 then
				exports.ox_inventory:AddItem(src, 'fishingboot', 1, {["quality"] = 100})
				TriggerClientEvent('QBCore:Notify', src, "You caught a fishing boot!", "primary")
			elseif luck >= 60 and luck <= 65 then
				local weight = math.random(1,6)
				local info = {species = "Bass", lbs = weight, type = "Normal"}
				TriggerClientEvent('fishing:client:spawnFish', src, 6)
				exports.ox_inventory:AddItem(src, 'bass', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a " .. weight .. "lbs Bass", "success")
			elseif luck >= 55 and luck <= 60 then
				exports.ox_inventory:AddItem(src, 'fishingloot', 1, {["quality"] = 100})
				TriggerClientEvent('QBCore:Notify', src, "You found a small box!", "success")
			elseif luck >= 50 and luck <= 55 then
				local weight = math.random(5,7)
				local info = {species = "Cod", lbs = weight, type = "Normal"}
				TriggerClientEvent('fishing:client:spawnFish', src, 6)
				exports.ox_inventory:AddItem(src, 'codfish', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a " .. weight .. "lbs  Cod", "success")
			elseif luck >= 45 and luck <= 50 then
				exports.ox_inventory:AddItem(src, 'fishingtin', 1, {["quality"] = 100})
				TriggerClientEvent('QBCore:Notify', src, "You caught a fishing tin!", "primary")
			elseif luck >= 0 and luck <= 45 then
				local weight = math.random(1,5)
				local info = {species = "Mackerel", lbs = weight, type = "Normal"}
				TriggerClientEvent('fishing:client:spawnFish', src, 6)
				exports.ox_inventory:AddItem(src, 'mackerel', 1, info)
				TriggerClientEvent('QBCore:Notify', src, "You caught a " .. weight .. "lbs Mackerel", "success")
            end
            Citizen.Wait(500)
        end
    end
end)

RegisterNetEvent('fishing:server:SellillegalFish', function(args)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local args = tonumber(args)
	if args == 1 then 
		local dolphin = exports.ox_inventory:GetItem(src, "dolphin", nil, false)
		if dolphin ~= nil then
			local payment = Config.dolphinPrice
			exports.ox_inventory:RemoveItem(src, "dolphin", 1)
			Player.Functions.AddMoney('bank', payment , "dolphin-sell")
			TriggerClientEvent('QBCore:Notify', src, "Dolphin Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellillegalFish", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have any Dolphin to sell", 'error')
		end
	elseif args == 2 then 
		local sharktiger = exports.ox_inventory:GetItem(src, "sharktiger", nil, false)
		if sharktiger ~= nil then
			local payment = Config.sharktigerPrice
			exports.ox_inventory:RemoveItem(src, "sharktiger", 1)
			Player.Functions.AddMoney('bank', payment , "sharktiger-sell")
			TriggerClientEvent('QBCore:Notify', src, "Tiger Shark Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellillegalFish", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have any Tiger Shark to sell", 'error')
		end
	elseif args == 3 then 
		local sharkhammer = exports.ox_inventory:GetItem(src, "sharkhammer", nil, false)
		if sharkhammer ~= nil then
			local payment = Config.sharkhammerPrice
			exports.ox_inventory:RemoveItem(src, "sharkhammer", 1)
			Player.Functions.AddMoney('bank', payment , "sharkhammer-sell")
			TriggerClientEvent('QBCore:Notify', src, "Hammerhead Shark Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellillegalFish", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have any Hammerhead Shark to sell", 'error')
		end
	else
		local killerwhale = exports.ox_inventory:GetItem(src, "killerwhale", nil, false)
		if killerwhale ~= nil then
			local payment = Config.killerwhalePrice
			exports.ox_inventory:RemoveItem(src, "killerwhale", 1)
			Player.Functions.AddMoney('bank', payment , "killerwhale-sell")
			TriggerClientEvent('QBCore:Notify', src, "Killer Whale Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellillegalFish", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have any Killer Whale to sell", "error")
		end
	end
end)

RegisterNetEvent('fishing:server:SellLegalFish', function(args) 
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local args = tonumber(args)
	if args == 1 then 
		local mackerel = exports.ox_inventory:GetItem(src, "mackerel", nil, false)
		if mackerel ~= nil then
			local payment = Config.mackerelPrice
			exports.ox_inventory:RemoveItem(src, "mackerel", 1)
			Player.Functions.AddMoney('bank', payment , "mackerel-sell")
			TriggerClientEvent('QBCore:Notify', src, "1 Mackerel Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellLegalFish", source)
		else
		    TriggerClientEvent('QBCore:Notify', src, "You dont have any Mackerels to sell", "error")
		end
	elseif args == 2 then
		local codfish = exports.ox_inventory:GetItem(src, "codfish", nil, false)
		if codfish ~= nil then
			local payment = Config.codfishPrice
			exports.ox_inventory:RemoveItem(src, "codfish", 1)
			Player.Functions.AddMoney('bank', payment , "codfish-sell")
			TriggerClientEvent('QBCore:Notify', src, "1 Cod Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellLegalFish", source)
		else
		    TriggerClientEvent('QBCore:Notify', src, "You dont have any Cods to sell", "error")
		end
	elseif args == 3 then
		local bass = exports.ox_inventory:GetItem(src, "bass", nil, false)
		if bass ~= nil then
			local payment = Config.bassPrice
			exports.ox_inventory:RemoveItem(src, "bass", 1)
			Player.Functions.AddMoney('bank', payment , "bass-sell")
			TriggerClientEvent('QBCore:Notify', src, "1 Bass Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellLegalFish", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have any Bass to sell", "error")
		end
	elseif args == 4 then
		local flounder = exports.ox_inventory:GetItem(src, "flounder", nil, false)
		if flounder ~= nil then
			local payment = Config.flounderPrice
			exports.ox_inventory:RemoveItem(src, "flounder", 1)
			Player.Functions.AddMoney('bank', payment , "flounder-sell")
			TriggerClientEvent('QBCore:Notify', src, "1 Flounder Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellLegalFish", source)
		else
		    TriggerClientEvent('QBCore:Notify', src, "You dont have any Flounders to sell", "error")
		end
	else
		local stingray = exports.ox_inventory:GetItem(src, "stingray", nil, false)
		if stingray ~= nil then
			local payment = Config.stingrayPrice
			exports.ox_inventory:RemoveItem(src, "stingray", 1)
			Player.Functions.AddMoney('bank', payment , "stingray-sell")
			TriggerClientEvent('QBCore:Notify', src, "1 Stingray Sold for $"..payment, "success")
			TriggerClientEvent("doj:client:SellLegalFish", source)
		else
		    TriggerClientEvent('QBCore:Notify', src, "You dont have any Stingray to sell", "error")
		end
	end
end)

RegisterNetEvent('fishing:server:BuyFishingGear', function(args)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
	local args = tonumber(args)
	local bankBalance = Player.PlayerData.money["bank"]

	if args == 1 then 
		if bankBalance >= Config.fishingBaitPrice then
			Player.Functions.RemoveMoney('bank', Config.fishingBaitPrice, "fishbait")
			exports.ox_inventory:AddItem(src, 'fishbait', 1, {["quality"] = 100})
			TriggerClientEvent("doj:client:buyFishingGear", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have enough money..", "error")
		end
	elseif args == 2 then 
		if bankBalance >= Config.fishingRodPrice then
			Player.Functions.RemoveMoney('bank', Config.fishingRodPrice, "fishingrod")
			exports.ox_inventory:AddItem(src, 'fishingrod', 1, {["quality"] = 100})
			TriggerClientEvent("doj:client:buyFishingGear", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have enough money..", "error")
		end
	elseif args == 3 then 
		if bankBalance >= Config.BoatAnchorPrice then
			Player.Functions.RemoveMoney('bank', Config.BoatAnchorPrice, "anchor")
			exports.ox_inventory:AddItem(src, 'anchor', 1, {["quality"] = 100})
			TriggerClientEvent("doj:client:buyFishingGear", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have enough money..", "error")
		end
	else
		if bankBalance >= Config.BoatAnchorPrice then
			Player.Functions.RemoveMoney('bank', Config.BoatAnchorPrice, "fishicebox")
			local info = {
				boxid = math.random(111,999),
				boxOwner = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname,
			}
			exports.ox_inventory:AddItem(src, 'fishicebox', 1, info)
			TriggerClientEvent("doj:client:buyFishingGear", source)
		else
			TriggerClientEvent('QBCore:Notify', src, "You dont have enough money..", "error")
		end
	end
end)


--============================================================================ Callbacks
QBCore.Functions.CreateCallback('fishing:server:checkMoney', function(source, cb)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    local bankBalance = pData.PlayerData.money["bank"]
	local price = Config.BoatPrice
    if bankBalance >= price then
        pData.Functions.RemoveMoney('bank', Config.BoatPrice, "boat-rental")
		TriggerClientEvent('QBCore:Notify', src, "Boat has been rented for $"..price, "success")
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', src, "You dont have enough money..", "error")
        cb(false)
    end
end)
