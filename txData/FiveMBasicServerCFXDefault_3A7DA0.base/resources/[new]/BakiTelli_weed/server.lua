local QBCore = exports['qb-core']:GetCoreObject()
function UseItem(source) 
    if getitem(source, Config.Items["Seed"]) >= 1 then 
        removeitem(source, Config.Items["Seed"], 1)
        TriggerClientEvent("BakiTelli_weed:Seed", source)
        sendToDiscord(Config.Webhook, source, "Seed Planted! ", "\n" .. GetPlayerName(source) .. "(" .. source .. ") \n\n**Seed Type : **" .. Config.Items["Seed"], 15158332)
    end
end

RegisterNetEvent("BakiTelli_weed:giveSV")
AddEventHandler("BakiTelli_weed:giveSV", function (menu, id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local water = Player.Functions.GetItemByName(Config.Items["Water"])
    local fertilizer = Player.Functions.GetItemByName(Config.Items["Fertilizer"])
    local dust = Player.Functions.GetItemByName(Config.Items["Dust"])
    if id == "Water" then
		if water ~= nil then
        -- if getitem(src, Config.Items["Water"]) >= 1 then 
                Player.Functions.RemoveItem(Config.Items["Water"], 1)
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items["Water"]], "remove", 1)
                TriggerClientEvent("BakiTelli_weed:giveCl", src, menu, id)
        else
            TriggerClientEvent('QBCore:Notify', src, "You have no water", "error", 4000)
        end
    elseif id == "Fertilizer" then 
        if fertilizer ~= nil then
        -- if getitem(src, Config.Items["Fertilizer"]) >= 1 then 
            Player.Functions.RemoveItem(Config.Items["Fertilizer"], 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items["Fertilizer"]], "remove", 1)
            TriggerClientEvent("BakiTelli_weed:giveCl", src, menu, id)
        else
            TriggerClientEvent('QBCore:Notify', src, "You don't have fertilizer", "error", 4000)
        end
    elseif id == "Dust" then 
        if dust ~= nil then

        -- if getitem(src, Config.Items["Dust"]) >= 1 then 
            Player.Functions.RemoveItem(Config.Items["Dust"], 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items["Dust"]], "remove", 1)
            TriggerClientEvent("BakiTelli_weed:giveCl", src, menu, id)
        else
            TriggerClientEvent('QBCore:Notify', src, "You don't have Dust", "error", 4000)

        end
    end
end)

RegisterNetEvent("BakiTelli_weed:Harvest")
AddEventHandler("BakiTelli_weed:Harvest", function (weed)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.AddItem(Config.Items["Weed"], weed)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items["Weed"]], "add", weed)
end)

RegisterNetEvent("BakiTelli_weed:RemoveWeedSeed")
AddEventHandler("BakiTelli_weed:RemoveWeedSeed", function (weed)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem("weed_seed", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["weed_seed"], "remove", 1)
end)


RegisterNetEvent("ler-weedpicking:processweed2")
AddEventHandler("ler-weedpicking:processweed2", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem(Config.Items["Weed"], 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items["Weed"]], "remove", 1)
    Player.Functions.AddItem("weed_whitewidow", 2)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['weed_whitewidow'], "add", 2)
end)
