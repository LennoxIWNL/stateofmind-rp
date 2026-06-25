local QBCore = exports['qb-core']:GetCoreObject()
local WH_ECONOMY      = 'https://discord.com/api/webhooks/1519638879974457365/EI4ETuWu0U1PgfGEYX4xQfy9F7OvM94H6B7mybl3qtMm9gkXAiDb1HJNzEjfGF2MNFC0'
local WH_INVENTORY    = 'https://discord.com/api/webhooks/1519638881731870842/CqHmm9zbY4mIB0k1CdBDSmHfXL6kfRBy4-PXkno6VVRwfosfrj01557s-VAN2qTKYU_y'
local WH_CRIME        = 'https://discord.com/api/webhooks/1519638884504436817/V8ETrLrN-v62Ne3b2HrUGh8NGEiN1fI9GBHfTjkLQpprHC2xtqzRMhOqnD2tJxDebWaa'
local WH_PLAYER_STAFF = 'https://discord.com/api/webhooks/1519638887016824954/UD2T2CIGhOyEuCQFg7VZzHKUpxFvB8hB8sTKIOv7ABdapH-qjKintWPYEkfJgKXeWaFo'
local WH_COMMS        = 'https://discord.com/api/webhooks/1519638891093557288/UD_EvY9-7bK320TZIGzTVLcO-OcPSdukNInO5QuXbeHBTpu65JkqQ1gFcZsK2MwQS9pd'
local WH_SYSTEM       = 'https://discord.com/api/webhooks/1519638893073399929/soUYhzuPsR1WyQDkmjCcyO7UrYcD2R-HnXe1R9ydtEAcELeAOMIzJIsY_HLiDoyVxZXP'

local Webhooks = {
    -- System
    ['default']         = WH_SYSTEM,
    ['testwebhook']     = WH_SYSTEM,
    ['weather']         = WH_SYSTEM,
    -- Economy
    ['playermoney']     = WH_ECONOMY,
    ['banking']         = WH_ECONOMY,
    ['vehicleshop']     = WH_ECONOMY,
    ['vehicleupgrades'] = WH_ECONOMY,
    ['shops']           = WH_ECONOMY,
    ['dealers']         = WH_ECONOMY,
    ['bennys']          = WH_ECONOMY,
    ['casino']          = WH_ECONOMY,
    ['pawnshop']        = WH_ECONOMY,
    -- Inventory
    ['playerinventory'] = WH_INVENTORY,
    ['drop']            = WH_INVENTORY,
    ['trunk']           = WH_INVENTORY,
    ['glovebox']        = WH_INVENTORY,
    ['stash']           = WH_INVENTORY,
    ['moneysafes']      = WH_INVENTORY,
    -- Crime
    ['robbing']         = WH_CRIME,
    ['storerobbery']    = WH_CRIME,
    ['bankrobbery']     = WH_CRIME,
    ['robbery']         = WH_CRIME,
    ['traphouse']       = WH_CRIME,
    ['powerplants']     = WH_CRIME,
    ['jewelery']        = WH_CRIME,
    -- Player / Staff
    ['joinleave']       = WH_PLAYER_STAFF,
    ['bans']            = WH_PLAYER_STAFF,
    ['anticheat']       = WH_PLAYER_STAFF,
    ['bossmenu']        = WH_PLAYER_STAFF,
    ['gangmenu']        = WH_PLAYER_STAFF,
    ['house']           = WH_PLAYER_STAFF,
    ['qbjobs']          = WH_PLAYER_STAFF,
    ['death']           = WH_PLAYER_STAFF,
    ['cuffing']         = WH_PLAYER_STAFF,
    ['ambulancejob']    = WH_PLAYER_STAFF,
    -- Comms
    ['ooc']             = WH_COMMS,
    ['me']              = WH_COMMS,
    ['report']          = WH_COMMS,
    ['911']             = WH_COMMS,
    ['112']             = WH_COMMS,
    ['palert']          = WH_COMMS,
    ['pmelding']        = WH_COMMS,
}

local colors = { -- https://www.spycolor.com/
    ['default'] = 14423100,
    ['blue'] = 255,
    ['red'] = 16711680,
    ['green'] = 65280,
    ['white'] = 16777215,
    ['black'] = 0,
    ['orange'] = 16744192,
    ['yellow'] = 16776960,
    ['pink'] = 16761035,
    ['lightgreen'] = 65309,
}

local logQueue = {}

RegisterNetEvent('qb-log:server:CreateLog', function(name, title, color, message, tagEveryone)
    local postData = {}
    local tag = tagEveryone or false
    if not Webhooks[name] then print('Tried to call a log that isn\'t configured with the name of ' ..name) return end
    local webHook = Webhooks[name] ~= '' and Webhooks[name] or Webhooks['default']
    local embedData = {
        {
            ['title'] = title,
            ['color'] = colors[color] or colors['default'],
            ['footer'] = {
                ['text'] = os.date('%c'),
            },
            ['description'] = message,
            ['author'] = {
                ['name'] = 'QBCore Logs',
                ['icon_url'] = 'https://raw.githubusercontent.com/GhzGarage/qb-media-kit/main/Display%20Pictures/Logo%20-%20Display%20Picture%20-%20Stylized%20-%20Red.png',
            },
        }
    }

    if not logQueue[name] then logQueue[name] = {} end
    logQueue[name][#logQueue[name] + 1] = {webhook = webHook, data = embedData}

    if #logQueue[name] >= 10 then
        if tag then
            postData = {username = 'QB Logs', content = '@everyone', embeds = {}}
        else
            postData = {username = 'QB Logs', embeds = {}}
        end
        for i = 1, #logQueue[name] do postData.embeds[#postData.embeds + 1] = logQueue[name][i].data[1] end
        PerformHttpRequest(logQueue[name][1].webhook, function() end, 'POST', json.encode(postData), { ['Content-Type'] = 'application/json' })
        logQueue[name] = {}
    end
end)

Citizen.CreateThread(function()
    local timer = 0
    while true do
        Wait(1000)
        timer = timer + 1
        if timer >= 60 then -- If 60 seconds have passed, post the logs
            timer = 0
            for name, queue in pairs(logQueue) do
                if #queue > 0 then
                    local postData = {username = 'QB Logs', embeds = {}}
                    for i = 1, #queue do
                        postData.embeds[#postData.embeds + 1] = queue[i].data[1]
                    end
                    PerformHttpRequest(queue[1].webhook, function() end, 'POST', json.encode(postData), {['Content-Type'] = 'application/json'})
                    logQueue[name] = {}
                end
            end
        end
    end
end)

QBCore.Commands.Add('testwebhook', 'Test Your Discord Webhook For Logs (God Only)', {}, false, function()
    TriggerEvent('qb-log:server:CreateLog', 'testwebhook', 'Test Webhook', 'default', 'Webhook setup successfully')
end, 'god')