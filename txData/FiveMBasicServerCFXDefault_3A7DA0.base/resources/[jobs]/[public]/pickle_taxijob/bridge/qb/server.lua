if GetResourceState('qb-core') ~= 'started' and GetResourceState('qbx_core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function RegisterCallback(name, cb)
    QBCore.Functions.CreateCallback(name, cb)
end

function RegisterUsableItem(...)
    QBCore.Functions.CreateUseableItem(...)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function Search(source, name)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if (name == "money") then
        return xPlayer.PlayerData.money['cash']
    elseif (name == "bank") then
        return xPlayer.PlayerData.money['cash'] -- If anyone knows how to get bank balance for QBCore, let me know.
    else
        local item = exports.ox_inventory:GetItem(source, name, nil, false)
        if item ~= nil then
            return item.count
        else
            return 0
        end
    end
end

function AddItem(source, name, amount, metadata)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if (name == "money") then
        return xPlayer.Functions.AddMoney("cash", amount)
    elseif (name == "bank") then
        return xPlayer.Functions.AddMoney("cash", amount) -- If anyone knows how to add to bank balance for QBCore, let me know.
    else
        return exports.ox_inventory:AddItem(source, name, amount, metadata)
    end
end

function RemoveItem(source, name, amount)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if (name == "money") then
        return xPlayer.Functions.RemoveMoney("cash", amount)
    elseif (name == "bank") then
        return xPlayer.Functions.RemoveMoney("cash", amount) -- If anyone knows how to remove from bank balance for QBCore, let me know.
    else
        return exports.ox_inventory:RemoveItem(source, name, amount)
    end
end 

function CanAccessGroup(source, data)
    if not data then return true end
    local pdata = QBCore.Functions.GetPlayer(source).PlayerData
    for k,v in pairs(data) do 
        if (pdata.job.name == k and pdata.job.grade.level >= v) then return true end
    end
    return false
end 

function GetIdentifier(source)
    local xPlayer = QBCore.Functions.GetPlayer(source).PlayerData
    return xPlayer.citizenid 
end