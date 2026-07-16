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
    local water = exports.ox_inventory:GetItem(src, Config.Items["Water"], nil, false)
    local fertilizer = exports.ox_inventory:GetItem(src, Config.Items["Fertilizer"], nil, false)
    local dust = exports.ox_inventory:GetItem(src, Config.Items["Dust"], nil, false)
    if id == "Water" then
		if water ~= nil then
        -- if getitem(src, Config.Items["Water"]) >= 1 then 
                exports.ox_inventory:RemoveItem(src, Config.Items["Water"], 1)
                TriggerClientEvent("BakiTelli_weed:giveCl", src, menu, id)
        else
            TriggerClientEvent('QBCore:Notify', src, "You have no water", "error", 4000)
        end
    elseif id == "Fertilizer" then 
        if fertilizer ~= nil then
        -- if getitem(src, Config.Items["Fertilizer"]) >= 1 then 
            exports.ox_inventory:RemoveItem(src, Config.Items["Fertilizer"], 1)
            TriggerClientEvent("BakiTelli_weed:giveCl", src, menu, id)
        else
            TriggerClientEvent('QBCore:Notify', src, "You don't have fertilizer", "error", 4000)
        end
    elseif id == "Dust" then 
        if dust ~= nil then

        -- if getitem(src, Config.Items["Dust"]) >= 1 then 
            exports.ox_inventory:RemoveItem(src, Config.Items["Dust"], 1)
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
    exports.ox_inventory:AddItem(src, Config.Items["Weed"], weed)
end)

RegisterNetEvent("BakiTelli_weed:RemoveWeedSeed")
AddEventHandler("BakiTelli_weed:RemoveWeedSeed", function (weed)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, "weed_seed", 1)
end)


RegisterNetEvent("ler-weedpicking:processweed2")
AddEventHandler("ler-weedpicking:processweed2", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.ox_inventory:RemoveItem(src, Config.Items["Weed"], 1)
    exports.ox_inventory:AddItem(src, "weed_whitewidow", 2)
end)
