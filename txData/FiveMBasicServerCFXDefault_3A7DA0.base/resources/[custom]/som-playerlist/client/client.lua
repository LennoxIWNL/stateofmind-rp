local playerList = {}
local disconnectedPlayers = {}
AC = {}
QBCore = exports['qb-core']:GetCoreObject()

RegisterCommand("list",function()
    OpenMenu()

end)

RegisterKeyMapping('list', 'PLayer List Menu', 'keyboard', 'U')

function OpenMenu() 
    TriggerEvent('som-playerlist:client:manualUpdate')
    Wait(500)
    if playerList then 
        SendNUIMessage({
            type = "OPEN",
            data = {
                activePlayers = playerList,
                disconnectedPlayers = disconnectedPlayers
            }
        })
        SetNuiFocus(1,1)
    end
end



RegisterCommand("list",function()
    TriggerEvent('som-playerlist:client:manualUpdate')
    Wait(500)
    if playerList then 
        SendNUIMessage({
            type = "OPEN",
            data = {
                activePlayers = playerList,
                disconnectedPlayers = disconnectedPlayers
            }
        })
        SetNuiFocus(1,1)
        print(json.encode(playerList))
    end
end)


RegisterNetEvent('som-playerlist:client:manualUpdate')
AddEventHandler('som-playerlist:client:manualUpdate', function(activePlayers,disPlayers)
    TriggerServerEvent('som-playerlist:server:manualUpdate')
    playerList = activePlayers
    disconnectedPlayers = disPlayers
end)

RegisterNUICallback("getData", function(data,cb)
    if data.variable == "online" then
        cb(playerList)
    else
        cb(disconnectedPlayers)
    end
end)


RegisterNUICallback("close",function()
    SetNuiFocus(0,0)
end)