local verifyR = 'cs_fscanner'

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= verifyR) then
		print('Do Not Change Name of '..GetCurrentResourceName()..' else It Will Stop Working')
        return
    end
end)

local version = GetResourceMetadata(GetCurrentResourceName(), "version")
CreateThread(function()
    print("^4Running Latest Version of "..GetCurrentResourceName().."! ^0")
    if CodeStudio.ServerType == "ESX" and CodeStudio.Enable_Fingerprint_ID then
        local queries = {"ALTER TABLE users ADD COLUMN IF NOT EXISTS fingerprint LONGTEXT NOT NULL DEFAULT '0' COLLATE 'utf8_general_ci';"}
        MySQL.transaction(queries)
    end
end)


function GetFingerID(identifier)
    if CodeStudio.Enable_Fingerprint_ID then
        local Return_ID = nil
        MySQL.single('SELECT fingerprint FROM users WHERE identifier = ?',{identifier}, function(result)
            if result.fingerprint == '0' or not result.fingerprint then
                local NewFinger = CreateFingerId()
                MySQL.update.await('UPDATE users SET fingerprint = ? WHERE identifier = ?', {
                    NewFinger,
                    identifier
                })
                Return_ID =  NewFinger
            else
                Return_ID = result.fingerprint
            end
        end)
        while not Return_ID do
            Wait(0)
        end
        return Return_ID
    else
        return false
    end
end


local StringCharset = {}
local NumberCharset = {}

for i = 48, 57 do NumberCharset[#NumberCharset + 1] = string.char(i) end
for i = 65, 90 do StringCharset[#StringCharset + 1] = string.char(i) end
for i = 97, 122 do StringCharset[#StringCharset + 1] = string.char(i) end

function RandomStr(length)
    if length <= 0 then return '' end
    return RandomStr(length - 1) .. StringCharset[math.random(1, #StringCharset)]
end

function RandomInt(length)
    if length <= 0 then return '' end
    return RandomInt(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
end


function CreateFingerId()
    local UniqueFound = false
    local FingerId = nil
    while not UniqueFound do
        FingerId = tostring(RandomStr(2) .. RandomInt(3) .. RandomStr(1) .. RandomInt(2) .. RandomStr(3))
        local result = MySQL.prepare.await('SELECT COUNT(*) as count FROM users WHERE fingerprint = ?', { FingerId })
        if result == 0 then
            UniqueFound = true
        end
    end
    return FingerId
end



RegisterServerEvent('cs:fscanner:scanFinger', function(target, taker)
    local src = source
    if target == 'self' then
        TriggerClientEvent('cs:fscanner:scanFinger', src, GetPlayerDetail(tonumber(src)))
        if CodeStudio.DicordLogs then
            SendDiscordLog(GetPlayerDetail(tonumber(src)), GetPlayerDetail(tonumber(src)))
        end
        return
    end
    TriggerClientEvent('cs:fscanner:scanFinger', tonumber(target), GetPlayerDetail(tonumber(target)))
    TriggerClientEvent('cs:fscanner:scanFinger', tonumber(taker), GetPlayerDetail(tonumber(target)))
    if CodeStudio.DicordLogs then
        SendDiscordLog(GetPlayerDetail(tonumber(taker)), GetPlayerDetail(tonumber(target)))
    end
end)


RegisterServerEvent('cs:fscanner:giveScan', function(target, TestTaker)
    local src = source
    TriggerClientEvent('cs:fscanner:giveScan', tonumber(target), tonumber(target), TestTaker)
    TriggerClientEvent('cs:fscanner:giveScan', tonumber(src), tonumber(target), TestTaker)
end)

RegisterServerEvent('cs:fscanner:resetUI', function(target)
    TriggerClientEvent('cs:fscanner:resetUI', tonumber(target))
end)


RegisterServerEvent('cs:fscanner:closeUI', function(target)
    TriggerClientEvent('cs:fscanner:closeUI', tonumber(target))
end)