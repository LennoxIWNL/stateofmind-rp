local QBCore = exports['qb-core']:GetCoreObject()

local quantity = 0
local ItemList = {
    ["casino_goldchip"] = 1,
}

RegisterServerEvent("qb-casino:server:GoldSell")
AddEventHandler("qb-casino:server:GoldSell", function()
    local src = source
    local price = Config.casinoChipPrice
    local Player = QBCore.Functions.GetPlayer(src)
    local xItem = exports.ox_inventory:GetItem(src, "casino_goldchip", nil, false)
    if xItem ~= nil then
        local quantity = 0
        for k, v in pairs(Player.PlayerData.items) do
            if Player.PlayerData.items[k] ~= nil then
                if ItemList[Player.PlayerData.items[k].name] ~= nil then
                    quantity = quantity + Player.PlayerData.items[k].amount
                    exports.ox_inventory:RemoveItem(src, Player.PlayerData.items[k].name, Player.PlayerData.items[k].amount, nil, k)
                end
            end
        end
        price = price * quantity
        Player.Functions.AddMoney(Config.payment, price, "sold-casino-chips")
        TriggerClientEvent('QBCore:Notify', src, "You sold "..quantity.." Gold chips for $"..price)
        TriggerEvent('qb-log:server:CreateLog', 'guedesteste', 'Dinheiro Venda | '..Player.PlayerData.name, 'default', quantity.." fichas de ouro por "..price.."€")
        TriggerClientEvent("doj:casinoChipMenu", src)
		quantity = 0
    else
        TriggerClientEvent('QBCore:Notify', src, "You dont have any gold casino chips...", "error") 
        TriggerClientEvent("doj:casinoChipMenu", src)
    end
end)


RegisterNetEvent("doj:server:purchaseMembership", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local MembershipCheck = exports.ox_inventory:GetItem(src, 'casino_member', nil, false)
    if MembershipCheck ~= nil then
        TriggerClientEvent('doj:casinoMembershipMenu', src)
        TriggerClientEvent('QBCore:Notify', src, 'You already have a Membership', 'error')
    else
	    if exports.ox_inventory:AddItem(src, 'casino_member', 1, info, false) then
            TriggerClientEvent('doj:casinoMembershipMenu', src)

        end
    end
end)

RegisterNetEvent("doj:server:purchaseVIPMembership", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local VIPMembershipCheck = exports.ox_inventory:GetItem(src, 'casino_vip', nil, false)
    if VIPMembershipCheck ~= nil then
        TriggerClientEvent('doj:casinoMembershipMenu', src)
        TriggerClientEvent('QBCore:Notify', src, 'You already have a Membership', 'error')
    else
	    if exports.ox_inventory:AddItem(src, 'casino_vip', 1, info, false) then
            TriggerClientEvent('doj:casinoMembershipMenu', src)

        end
    end 
end)


QBCore.Functions.CreateCallback('doj:server:HasCasinoMembership', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Item = exports.ox_inventory:GetItem(source, "casino_member", nil, false)

    if Item ~= nil then 
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('doj:server:HasVIPMembership', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Item = exports.ox_inventory:GetItem(source, "casino_vip", nil, false)

    if Item ~= nil then 
        cb(true)
    else
        cb(false)
    end
end)





-- RegisterNetEvent("doj:server:validateMembership")
-- AddEventHandler("doj:server:validateMembership", function(args)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)
--     local args = tonumber(args)
-- 	if args == 1 then 
--         if Player.Functions.GetItemByName("casino_member") then
--             Player.Functions.RemoveItem("casino_member", 1)
--             local info = {
--                 owner = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname,
--             }
--             Player.Functions.AddItem("casino_member_validated", 1, false, info)
--             TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["casino_member_validated"], "add", 1) 
--             TriggerClientEvent('QBCore:Notify', src, "Membership has been validated", "success")
--         else
--             TriggerClientEvent('QBCore:Notify', src, "You need to buy a Casino Membership first", "error")
--         end
--     else
--         if Player.Functions.GetItemByName("casino_vip") then
--             Player.Functions.RemoveItem("casino_vip", 1)
--             local info = {
--                 owner = Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname,
--             }
--             Player.Functions.AddItem("casino_vip_validated", 1, false, info)
--             TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["casino_vip_validated"], "add", 1) 
--             TriggerClientEvent('QBCore:Notify', src, "Membership has been validated", "success")
--         else
--             TriggerClientEvent('QBCore:Notify', src, "You need to buy a V.I.P Membership first", "error")
--         end
--     end
-- end)


















