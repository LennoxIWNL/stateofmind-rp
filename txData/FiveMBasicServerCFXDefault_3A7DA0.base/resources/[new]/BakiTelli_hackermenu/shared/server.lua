local QBCore = exports['qb-core']:GetCoreObject()

-------------------------------- 

QBCore.Functions.CreateUseableItem(Config.ItemName, function(src)
    check = CheckPlayer(src)
    TriggerClientEvent("BakiTelli_hackermenu:OpenMenu", src, check)
end)

-------------------------------- 

RegisterNetEvent('ox_inventory:onUseItem')
AddEventHandler('ox_inventory:onUseItem', function(item)
    if item == Config.ItemName then
        check = CheckPlayer(s)
    TriggerClientEvent("BakiTelli_hackermenu:OpenMenu", src, check)
    end
end)

-------------------------------- 

function getMoney(source)
    local zrt = getplayer()
    local xPlayer = zrt(source)	
    if Config.Money == "cash" then 
        money = xPlayer.PlayerData.money["cash"]
    else 
        money = xPlayer.PlayerData.money["bank"]
    end
    return money
end

-------------------------------- 

AddEventHandler("BakiTelli_hackermenu:SendTweet")
RegisterNetEvent("BakiTelli_hackermenu:SendTweet", function (text)
    local src = source 
    local zrt = getplayer()
    local xPlayer = zrt(src)	
    local identifier = getidentifier(xPlayer)
    if Config.Tweet.Phone == "quasarphone" then 
        -- TriggerServerCallback('qs-smartphone:PostNewTweet', function(check)
            local TweetMessage = {
                name     = Config.Tweet.Name,
                username = Config.Tweet.Username,
                message  = text,
                image    = Config.Tweet.profile
            }
            TriggerEvent('qs-smartphone:UpdateTweets', src, TweetMessage)
    -- end)
    elseif Config.Tweet.Phone == "qb-phone" then 
        local TweetMessage = {
            firstName = Config.Tweet.Name,
            lastName = Config.Tweet.Username,
            citizenid = identifier,
            message = text,
            time = "/ / /",
            tweetId = GenerateTweetId(),
            picture = Config.Tweet.profile,
            url = Config.Tweet.profile
        }
        TriggerEvent('qb-phone:server:UpdateTweets', "asd", TweetMessage)
    else 
        -- if Config.Phone enter tweet trigger
    end
end)

-------------------------------- 

AddEventHandler("BakiTelli_hackermenu:SendAll")
RegisterNetEvent("BakiTelli_hackermenu:SendAll", function (text)
    TriggerClientEvent('QBCore:Notify', -1, "Hacker: ".. text)
end)
-------------------------------- 

function CheckPlayer(src)
    local zrt = getplayer()
    local xPlayer = zrt(src)	
    identifier = getidentifier(xPlayer)
    local rst = ExecuteSql("SELECT hackerMenu FROM `players` WHERE citizenid = '"..identifier.."'")
    return rst[1].hackerMenu 
end

-------------------------------- 

function getPlayerDetail(identifier)
    local rst = ExecuteSql("SELECT charinfo, job FROM `players` WHERE citizenid = '"..identifier.."'")
    return rst[1]
end
-------------------------------- 

function getPlayeNumber(identifier)
    local query = "SELECT charinfo FROM `players` WHERE citizenid = '" .. identifier .. "'"
    local result = ExecuteSql(query)
    number = json.decode(result[1].charinfo).phone
    return number
end

-------------------------------- 

function numbertoidentifier(phone_number)
    local query = "SELECT citizenid FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = '" .. phone_number .. "'"
    local rst = ExecuteSql(query)
    number = rst[1].citizenid
    return number
end

-------------------------------- 

function getPlayerid(id)
    return QBCore.Functions.GetPlayerByCitizenId(id).PlayerData.source or false
end

-------------------------------- 

function updateMy(idf, time, addxp, id, decoded)
    local banTime = tonumber(time)
    local currentTime = os.time()
    local endTime = currentTime + (banTime * 60)
    xp = decoded.xp + addxp 
    decoded.xp = xp
    decoded[id] = endTime
    ExecuteSql("UPDATE `players` SET hackerMenu = '"..json.encode(decoded).."' WHERE citizenid = '"..idf.."'")
end

-------------------------------- 

function addmoney(src, count)
    local zrt = getplayer()
    local xPlayer = zrt(src)
    xPlayer.Functions.AddMoney('bank', count)
end

-------------------------------- 

AddEventHandler("BakiTelli_hackermenu:getUserDetail")
RegisterNetEvent("BakiTelli_hackermenu:getUserDetail", function (name, id)
    src = source
    if name == "PhonefromName" then 
        get = getPlayerDetail(id)
        getc = json.decode(get.charinfo)
        getj = json.decode(get.job)
        rtrn = Config.Langs["Identifier"] .. " ".. getc.firstname .." "..getc.lastname .." ".. getj.name.. " ".. getc.birthdate .. " ".. getc.gender
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"text" , rtrn)
    elseif name == "PhoneCheck" then 
        get = getPlayeNumber(id)
        rtrn = Config.Langs["PhoneNumber"] .. " "..get
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"text" , rtrn)
    elseif name == "LocationCheck" then
        if getPlayerid(id) then
            local player = GetPlayerPed(getPlayerid(id))
            local coord = GetEntityCoords(player)
            nofity(src, Config.Langs["Gps"])
            TriggerClientEvent("BakiTelli_hackermenu:SetGPS", src , coord)
        else 
            nofity(src, Config.Langs["NoPlayer"])
        end
    end
end)

-------------------------------- 

function totalPolice()
    local count = 0
    local allPlayer = QBCore.Functions.GetPlayers()
	for i=1, #allPlayer, 1 do
        local Player = QBCore.Functions.GetPlayer(allPlayer[i])
        if Player.PlayerData.job.name == Config.HackerMenu.LspdActivePersonel.permission then
            count = count + 1
        end
    end
    return count
end

-------------------------------- 

function SearchPlayer(sentData)
    local query = "SELECT id, citizenid, charinfo, job FROM `players` WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))) LIKE '%" .. sentData .. "%' OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE '%" .. sentData .. "%' OR LOWER(`id`) LIKE '%" .. sentData .. "%' OR CONCAT(LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))), ' ', LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')))) LIKE '%" .. sentData .. "%' LIMIT 20"
    local people = ExecuteSql(query)
    return people
end

-------------------------------- 

function SearchNumber(sentData)
    local query = "SELECT id, citizenid, charinfo, job FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE '%" .. sentData .. "%' LIMIT 20"
    local people = ExecuteSql(query)
    return people
end

-------------------------------- 

function removeMoney(src, count)
    local zrt = getplayer()
    local xPlayer = zrt(src)	
    if Config.Money == "cash" then 
        xPlayer.Functions.RemoveMoney('cash', count, "Bank depost")
    else
        xPlayer.Functions.RemoveMoney('bank', count, "Bank depost")
    end
end

-------------------------------- 

function getplayer(source)
	xPlayer = QBCore.Functions.GetPlayer
	return xPlayer
end

-------------------------------- 

function nofity(source,text)
    TriggerClientEvent('QBCore:Notify', source, text)
end

-------------------------------- 

function getidentifier(xPlayer)
	hex = xPlayer.PlayerData.citizenid
	return hex
end

-------------------------------- 

function ExecuteSql(query)
    local IsBusy = true
    local result = nil
    if Config.Mysql == "oxmysql" then
        if MySQL == nil then
            exports.oxmysql:execute(query, function(data)
                result = data
                IsBusy = false
            end)
            -------------------------------- 
        else
            MySQL.query(query, {}, function(data)
                result = data
                IsBusy = false
            end)
        end
        -------------------------------- 
    elseif Config.Mysql == "ghmattimysql" then
        exports.ghmattimysql:execute(query, {}, function(data)
            result = data
            IsBusy = false
        end)
    elseif Config.Mysql == "mysql-async" then   
        MySQL.Async.fetchAll(query, {}, function(data)
            result = data
            IsBusy = false
        end)
        -------------------------------- 
    end
    while IsBusy do
        Citizen.Wait(0)
    end
    return result
end

------------------------------------------------------------------------------------

------------------------------------------------------------------------------------

-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX --

------------------------------------------------------------------------------------