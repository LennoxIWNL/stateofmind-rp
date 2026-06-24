local QBCore = exports['qb-core']:GetCoreObject()

local function SendNPWDNotify(title, content, icon)
    pcall(function()
        exports['npwd']:createNotification({
            notisId = 'qb-compat-' .. tostring(math.random(100000, 999999)),
            appId = 'DIALER',
            content = content or '',
            secondaryTitle = title or 'Notification',
            keepOpen = false,
            duration = 5000,
            path = '/',
        })
    end)
end

RegisterNetEvent('qb-phone-compat:client:notify', function(app, title, content, icon)
    SendNPWDNotify(title, content, icon)
end)

RegisterNetEvent('qb-phone:client:addPoliceAlert', function(alertData)
    if not alertData then return end
    local title = alertData.title or alertData.alert or 'Police Alert'
    local coords = alertData.coords or nil
    local coordsText = ''
    if coords then
        coordsText = (' | Location: %.1f, %.1f'):format(coords.x or 0.0, coords.y or 0.0)
    end
    SendNPWDNotify('Police Alert', title .. coordsText)
end)

RegisterNetEvent('qb-phone:client:CustomNotification', function(title, message, icon, color, duration)
    SendNPWDNotify(title or 'Notification', message or '')
end)

RegisterNetEvent('qb-phone:client:BillingEmail', function(data, toggle)
    if not data then return end
    local society = data.society or 'Unknown'
    local amount = data.amount or 0
    SendNPWDNotify('Invoice', ('$%s from %s'):format(amount, society))
end)

RegisterNetEvent('qb-phone:client:NewMailNotify', function(mailData)
    if not mailData then return end
    local sender = mailData.sender or 'Unknown'
    local subject = mailData.subject or 'New Mail'
    SendNPWDNotify(sender, subject)
end)

RegisterNetEvent('qb-phone:client:UpdateMails', function(mails)
end)

RegisterNetEvent('qb-phone:client:UpdateMessages', function()
end)

RegisterNetEvent('qb-phone:client:UpdateAdvertsDel', function()
end)

RegisterNetEvent('qb-phone:client:UpdateAdverts', function()
end)

RegisterNetEvent('qb-phone:client:CancelCall', function()
end)

RegisterNetEvent('qb-phone:client:AnswerCall', function()
end)

RegisterNetEvent('qb-phone:client:GetCalled', function()
end)

RegisterNetEvent('qb-phone:client:AddRecentCall', function()
end)

RegisterNetEvent('qb-phone:client:TransferMoney', function(data)
    if data then
        SendNPWDNotify('Bank Transfer', ('Received $%s'):format(data.amount or 0))
    end
end)

RegisterNetEvent('qb-phone:client:UpdateTweets', function()
end)

RegisterNetEvent('qb-phone:client:RaceNotify', function(message)
    if message then
        SendNPWDNotify('Racing', tostring(message))
    end
end)

RegisterNetEvent('qb-phone:client:UpdateLapraces', function()
end)

RegisterNetEvent('qb-phone:client:GetMentioned', function()
end)

RegisterNetEvent('qb-phone:client:UpdateHashtags', function()
end)

RegisterNetEvent('qb-phone:client:AddNewSuggestion', function()
end)

RegisterNetEvent('qb-phone:client:AddTransaction', function(data)
    if data then
        SendNPWDNotify('Crypto', data.message or 'Transaction completed')
    end
end)

RegisterNetEvent('qb-phone:RefreshPhone', function()
end)

RegisterNetEvent('qb-phone:client:GiveContactDetails', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.charinfo then return end
    local name = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
    local phone = PlayerData.charinfo.phone
    TriggerEvent('QBCore:Notify', ('Shared contact: %s (%s)'):format(name, phone), 'success')
end)
