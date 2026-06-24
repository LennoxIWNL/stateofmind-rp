RegisterServerEvent('submit:bug:report')
AddEventHandler('submit:bug:report', function(data)
    local src = source
    local pName = GetPlayerName(source)
    local connect = {
        {
            ["color"] = "8388736",
            ["title"] = "New Report - ".. pName,
            ["description"] = "Title: \n\n `"..data.title.."` \n\n━━━━━━━━━━━━━━━━━━\n\n Description: \n\n `"..data.description.."` \n\n━━━━━━━━━━━━━━━━━━\n\n VOD / Clip / Screenshot URLs: \n\n `"..data.url.."` \n\n━━━━━━━━━━━━━━━━━━\n\n",
	        ["footer"] = {
                ["text"] = "by ElixirFW 4.0",
            },
            ["image"] = {
                ["url"] = "https://cdn.discordapp.com/attachments/1246580007351095356/1246580301715607602/hacker-profile22.png?ex=665ce7e0&is=665b9660&hm=545771ba5ad26513d27672b903cbeb87192a45ea7d4b0eafc7c69eba546d6a44&"
            }
        }
    }
    local webhookUrl = "" -- insert your own report webhook
    if webhookUrl ~= "" then
        PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({username = "State of Mind RP - Reports", embeds = connect}), { ['Content-Type'] = 'application/json' })
    end
end)