if Config.Version == "new" then
    QBCore = exports['qb-core']:GetCoreObject()
end

RegisterNetEvent("elixir-chopshop:syncchopcars")
AddEventHandler("elixir-chopshop:syncchopcars", SyncCars)

function GiveReward(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if data == "wheel1" or data == "wheel2" or data == "wheel3" or data == "wheel4" then
    		exports.ox_inventory:AddItem(src, "car_wheel", 1)

	elseif data == "door" then
    	exports.ox_inventory:AddItem(src, "car_door", 1)
		
	elseif data == "hood" then
    	exports.ox_inventory:AddItem(src, "radiator", 1)

	elseif data == "trunk" then 
		local randomitem = math.random(1, 3)
		local item = Config.TrunkItems[randomitem]["item"]
		local amount = Config.TrunkItems[randomitem]["amount"]
		exports.ox_inventory:AddItem(src, item, amount)
		TriggerClientEvent('QBCore:Notify', src, "You found "..amount.." "..item.." in the trunk", 'success')
		Citizen.Wait(8500)
		exports.ox_inventory:AddItem(src, "trunk", 1)
	end
end

RegisterServerEvent('elixir-chopshop:server:callCops')
AddEventHandler('elixir-chopshop:server:callCops', function(type, bank, streetLabel, coords)
    local msg = ""
    msg = "Possible Vehicle Robbery"
    local alertData = {
        title = "Chopshop",
        coords = {x = coords.x, y = coords.y, z = coords.z},
        description = msg,
    }
    TriggerClientEvent("elixir-chopshop:client:robberyCall", -1, type, bank, streetLabel, coords)
    TriggerClientEvent("qb-phone:client:addPoliceAlert", -1, alertData)
end)

RegisterNetEvent("elixir-chopshop:server:rewardplayer")
AddEventHandler("elixir-chopshop:server:rewardplayer", GiveReward)

function SyncCars(list) 
	TriggerClientEvent('elixir-chopshop:carlist', -1,list) 
end

RegisterNetEvent("elixir-chopshop:server:chopdoor")
AddEventHandler("elixir-chopshop:server:chopdoor", function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local door = "car_door"
	
	if exports.ox_inventory:GetItem(src, door, nil, false) ~= nil then
		local randomitem = math.random(1, 5)
		local item = Config.DoorItems[randomitem]["item"]
		local amount = Config.DoorItems[randomitem]["amount"]
		exports.ox_inventory:RemoveItem(src, "car_door", 1)
		TriggerClientEvent('elixir-chopshop:doorchopanim', src)
		Citizen.Wait(12500)
		exports.ox_inventory:AddItem(src, item, amount)
	else
		TriggerClientEvent('QBCore:Notify', src, 'You have no doors to scrap..', 'error')
	end
end)

RegisterNetEvent("elixir-chopshop:server:chopwheel")
AddEventHandler("elixir-chopshop:server:chopwheel", function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local wheel = "car_wheel"

	if exports.ox_inventory:GetItem(src, wheel, nil, false) ~= nil then
		local randomitem = math.random(1, 3)
		local item = Config.WheelItems[randomitem]["item"]
		local amount = Config.WheelItems[randomitem]["amount"]
		exports.ox_inventory:RemoveItem(src, "car_wheel", 1)
		TriggerClientEvent('elixir-chopshop:wheelchopanim', src)
		Citizen.Wait(14000)
		exports.ox_inventory:AddItem(src, item, amount)
	else
		TriggerClientEvent('QBCore:Notify', src, 'You have no wheels to scrap..', 'error')
	end
end)


RegisterNetEvent("elixir-chopshop:server:chophood")
AddEventHandler("elixir-chopshop:server:chophood", function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local hood = "radiator" 

	if exports.ox_inventory:GetItem(src, hood, nil, false) ~= nil then
		local randomitem = math.random(1, 5)
		local item = Config.DoorItems[randomitem]["item"]
		local amount = Config.DoorItems[randomitem]["amount"]
		exports.ox_inventory:RemoveItem(src, "radiator", 1)
		TriggerClientEvent('elixir-chopshop:hoodchopanim', src)
		Citizen.Wait(12500)
		exports.ox_inventory:AddItem(src, item, amount)
	else
		TriggerClientEvent('QBCore:Notify', src, 'You have no hoods to scrap..', 'error')
	end
end)


RegisterNetEvent("elixir-chopshop:server:choptrunk")
AddEventHandler("elixir-chopshop:server:choptrunk", function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local trunk = "trunk"

	if exports.ox_inventory:GetItem(src, trunk, nil, false) ~= nil then
		local randomitem = math.random(1, 5)
		local item = Config.DoorItems[randomitem]["item"]
		local amount = Config.DoorItems[randomitem]["amount"]
		exports.ox_inventory:RemoveItem(src, "trunk", 1)
		TriggerClientEvent('elixir-chopshop:trunkchopanim', src)
		Citizen.Wait(12500)
		exports.ox_inventory:AddItem(src, item, amount)
	else
		TriggerClientEvent('QBCore:Notify', src, 'You have no trunks to scrap..', 'error')
	end
end)

