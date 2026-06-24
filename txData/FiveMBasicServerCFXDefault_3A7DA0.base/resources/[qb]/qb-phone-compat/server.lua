local QBCore = exports['qb-core']:GetCoreObject()

local function SendNPWDNotification(src, app, title, content, icon)
    if not src or src <= 0 then return end
    TriggerClientEvent('qb-phone-compat:client:notify', src, app, title, content, icon)
end

local function GetSourceByCitizenId(citizenid)
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            return player.PlayerData.source
        end
    end
    return nil
end

local function SendNewMailToOffline(citizenid, mailData)
    local src = GetSourceByCitizenId(citizenid)
    if src then
        local subject = mailData.subject or mailData.sender or 'New Mail'
        local message = mailData.message or ''
        if mailData.button and mailData.button.buttonData then
            message = message .. ' [Action available]'
        end
        SendNPWDNotification(src, 'EMAIL', subject, message)
    end
end

exports('sendNewMailToOffline', SendNewMailToOffline)

RegisterNetEvent('qb-phone:server:sendNewMail', function(mailData)
    local src = source
    if mailData then
        local subject = mailData.subject or mailData.sender or 'New Mail'
        local message = mailData.message or ''
        SendNPWDNotification(src, 'EMAIL', subject, message)
    end
end)

RegisterNetEvent('qb-phone:server:BillingEmail', function(data, toggle)
    local src = source
    if data then
        local society = data.society or 'Unknown'
        local amount = data.amount or 0
        TriggerClientEvent('qb-phone:client:BillingEmail', src, data, toggle)
    end
end)

RegisterNetEvent('qb-phone:server:GiveMailReward', function(mailId)
end)

RegisterNetEvent('qb-phone:server:PayInvoice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not data then return end

    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then return end

    if Player.Functions.RemoveMoney('bank', amount, 'phone-invoice-payment') then
        if data.society and data.society ~= '' then
            local society = data.society
            if exports['qb-banking'] then
                pcall(function()
                    exports['qb-banking']:AddMoney(society, amount, 'invoice-payment')
                end)
            end
        end
        TriggerClientEvent('QBCore:Notify', src, 'Invoice paid: $' .. amount, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money', 'error')
    end
end)

RegisterNetEvent('qb-phone:server:DeclineInvoice', function(data)
    local src = source
    TriggerClientEvent('QBCore:Notify', src, 'Invoice declined', 'info')
end)

QBCore.Functions.CreateCallback('qb-phone:server:HasPhone', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local items = Player.PlayerData.items
    for _, item in pairs(items) do
        if item.name == 'phone' then
            cb(true)
            return
        end
    end
    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetCallState', function(source, cb)
    cb(0)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetPhoneData', function(source, cb)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetContactPictures', function(source, cb)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetContactPicture', function(source, cb, number)
    cb(nil)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetPicture', function(source, cb, number)
    cb(nil)
end)

QBCore.Functions.CreateCallback('qb-phone:server:FetchResult', function(source, cb, data)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetVehicleSearchResults', function(source, cb, plate)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:ScanPlate', function(source, cb, plate)
    cb(nil)
end)

QBCore.Functions.CreateCallback('qb-phone:server:CanTransferMoney', function(source, cb, data)
    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetCurrentLawyers', function(source, cb)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetWebhook', function(source, cb)
    cb('')
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetPlayerHouses', function(source, cb)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:GetHouseKeys', function(source, cb, citizenid)
    cb({})
end)

QBCore.Functions.CreateCallback('qb-phone:server:TransferCid', function(source, cb, data)
    cb(false)
end)

QBCore.Functions.CreateCallback('qb-phone:server:MeosGetPlayerHouses', function(source, cb, citizenid)
    cb({})
end)
