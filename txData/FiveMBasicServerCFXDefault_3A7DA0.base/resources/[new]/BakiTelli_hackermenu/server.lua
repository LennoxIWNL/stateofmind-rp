-- {"xp":0,"LspdActivePersonel":0,"PhoneCheck":0,"PhonefromName":0,"CctvCamera":0,"AnonimTweet":0,"CarLock":0,"LocationCheck":0,"BankHack":0,"SendAllDM":0}
RegisterCommand("opentablet", function (s)
    src = s
    check = CheckPlayer(s)
    TriggerClientEvent("BakiTelli_hackermenu:OpenMenu", src, check)
end)

AddEventHandler("BakiTelli_hackermenu:ClickMain")
RegisterNetEvent("BakiTelli_hackermenu:ClickMain", function (id)
    src = source
    local zrt = getplayer()
    local xPlayer = zrt(src)	
    identifier = getidentifier(xPlayer)
    check = CheckPlayer(source)
    decoded = json.decode(check)
    lvlc = calculateLevel(decoded["xp"])
    lvlm = Config.HackerMenu[id].level
    idm = tonumber(decoded[id])
    lvlw = Config.HackerMenu[id].waiter
    lvls = Config.HackerMenu[id].addXP
    moneym = Config.HackerMenu[id].price
    moneyc = getMoney(src)
    if lvlc >= lvlm then 
        if moneym <= moneyc then
            if idm == 0 then
            -- if true then
                removeMoney(src, moneym)
                updateMy(identifier, lvlw, lvls, id, decoded)
                sendToDiscord(Config.Webhook, src, "Hacking Start! ", "\n" .. GetPlayerName(src) .. "(" .. src .. ") \n\nHack : **" .. Config.HackerMenu[id].label .. "**\n\n Current Level: **" .. lvlc.. "**", 15158332)
                TriggerClientEvent("BakiTelli_hackermenu:StartHack", src, id)
            else
                local currentTime = os.time()
                if currentTime < idm then
                    TriggerClientEvent("BakiTelli_hackermenu:Notification", src, "error", Config.Langs["TimeError"])
                else
                    removeMoney(src, moneym)
                    updateMy(identifier, lvlw, lvls, id, decoded)
                    sendToDiscord(Config.Webhook, src, "Hacking Start! ", "\n" .. GetPlayerName(src) .. "(" .. src .. ") \n\nHack : **" .. Config.HackerMenu[id].label .. "**\n\n Current Level: **" .. lvlc.. "**", 15158332)
                    TriggerClientEvent("BakiTelli_hackermenu:StartHack", src, id)
                end
            end
        else
            TriggerClientEvent("BakiTelli_hackermenu:Notification", src, "error", Config.Langs["MoneyError"])
        end
    else
        TriggerClientEvent("BakiTelli_hackermenu:Notification", src, "error", Config.Langs["LevelError"])
    end
end)

AddEventHandler("BakiTelli_hackermenu:getData")
RegisterNetEvent("BakiTelli_hackermenu:getData", function (id)
    src = source
    if id == "LspdActivePersonel" then 
        rtrn = Config.Langs["ActivePolice"] .." ".. totalPolice() 
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"text" , rtrn)
    elseif id == "PhoneCheck" or id == "PhonefromName" or id == "CctvCamera" or id == "LocationCheck" then 
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"table")
    elseif id == "AnonimTweet" or id == "SendAllDM" then 
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"entertext")
    elseif id == "BankHack" then
        money = math.random(Config.HackerMenu.BankHack.giveMoney.min, Config.HackerMenu.BankHack.giveMoney.max)
        addmoney(src, money)
        rtrn = Config.Langs["BankHack"].." $" ..money
        TriggerClientEvent("BakiTelli_hackermenu:cl:getData",src ,"text" , rtrn)
    end
end)

AddEventHandler("BakiTelli_hackermenu:getUsers")
RegisterNetEvent("BakiTelli_hackermenu:getUsers", function (text, id)
    src = source
    if id == "LocationCheck" then
        TriggerClientEvent("BakiTelli_hackermenu:cl:getUsers",src , SearchNumber(tonumber(text)))
    else     
        TriggerClientEvent("BakiTelli_hackermenu:cl:getUsers",src , SearchPlayer(text))
    end
end)


function calculateLevel(experience)
    local level = math.floor(tonumber(experience) / 100)
    return level
end

function StartHack(src, id)
    if id == "LspdActivePersonel" then
        TriggerClientEvent("BakiTelli_hackermenu:StartHack", src, id)
    end
end

 function GenerateTweetId()
    local tweetId = "TWEET-"..math.random(11111111, 99999999)
    return tweetId
end

function sendToDiscord(DiscordLog, source, title, des, color)
        local debuxIMG = "https://media.discordapp.net/attachments/1246580007351095356/1246580301715607602/hacker-profile22.png?ex=665d90a0&is=665c3f20&hm=79795d6fa25d523198e86fc20ef395ec44894264dd89569f5dea21ce40b46397&=&format=webp&quality=lossless&width=576&height=576"
        local log = {
            {
                ["title"] = "ELIXIR HACKER MENU",
                ["color"] = color,
                author = {
                    name = "ELIXIR WeaponShop",
                    icon_url = "https://media.discordapp.net/attachments/1246580007351095356/1246580301715607602/hacker-profile22.png?ex=665d90a0&is=665c3f20&hm=79795d6fa25d523198e86fc20ef395ec44894264dd89569f5dea21ce40b46397&=&format=webp&quality=lossless&width=576&height=576",
                    url = "https://discord.gg/YPYXBU2n6w"
                },
                ["fields"] = {
                    {
                        ["name"] = "> Info:",
                        ["value"] = title,
                        ["inline"] = false
                    },
                    {
                        ["name"] = "> Version:",
                        ["value"] = "1.0",
                        ["inline"] = false
                    },
                    {
                        ["name"] = "> Detail:",
                        ["value"] = des,
                        ["inline"] = false
                    },
                    {
                        ["name"] = "> Website:",
                        ["value"] = 'https://elixirfw.tebex.io',
                        ["inline"] = true
                    },
                    {
                        ["name"] = "> Support:",
                        ["value"] = 'https://discord.gg/YPYXBU2n6w',
                        ["inline"] = true
                    },
                },
                ["thumbnail"] = {
                    ["url"] = "https://media.discordapp.net/attachments/1246580007351095356/1246580301715607602/hacker-profile22.png?ex=665d90a0&is=665c3f20&hm=79795d6fa25d523198e86fc20ef395ec44894264dd89569f5dea21ce40b46397&=&format=webp&quality=lossless&width=576&height=576"
                },
            },
        }
        Citizen.Wait(tonumber(1000))
        PerformHttpRequest(DiscordLog, function(err, text, headers) end, 'POST', json.encode({ username = "ElixirFW WorkShop", embeds = log, avatar_url = debuxIMG }), { ['Content-Type'] = 'application/json' })
end

