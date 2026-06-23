local TargetPlayer = nil
local isOpen = false

local verifyR = 'cs_fscanner'
local RUN_SCRIPT = false
local TestTaker = nil


AddEventHandler('onClientResourceStart', function (resourceName)
    if(GetCurrentResourceName() ~= verifyR) then
      return
    end
    RUN_SCRIPT = true
end)


RegisterNetEvent('cs:fscanner:openUI', function()
    if not RUN_SCRIPT then return end
    if isOpen then return end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openUI",
        language = CodeStudio.Language,
        move = true,
    })
    isOpen = true
end)


RegisterNUICallback('giveScan', function()
    if not RUN_SCRIPT then return end
    local player, distance = GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent('cs:fscanner:giveScan', playerId, GetPlayerServerId(PlayerId()))
        Notify(CodeStudio.Language.tester_share)
        if CodeStudio.Animations.Enable then
            loadModel(CodeStudio.Animations.Scanner_Prop)
            loadAnimDict(CodeStudio.Animations.Use_Dict)
            prop = CreateObject(CodeStudio.Animations.Scanner_Prop, GetEntityCoords(PlayerPedId()), true, true, true)
            AttachEntityToEntity(prop, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), 0.1, 0.03, -0.04, -85.0, 0.0, 0.0, true, true, false, false, 1, true)
            TaskPlayAnim(PlayerPedId(), CodeStudio.Animations.Use_Dict, CodeStudio.Animations.Use_Anim, 2.0, -2.0,-1,2,1,0, 0,0)
        end
    else
        TriggerEvent('cs:fscanner:giveScan', 0)
    end
end)


RegisterNetEvent('cs:fscanner:giveScan', function(target, taker)
    if not RUN_SCRIPT then return end
    if target ~= 0 then
        TargetPlayer = target
        TestTaker = taker
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "giveScan",
        move = target,
    })
    isOpen = true
end)


RegisterNUICallback('scanFinger', function(target)
    if not RUN_SCRIPT then return end
    if TargetPlayer then
        if GetPlayerServerId(PlayerId()) == target.pID then
            TriggerServerEvent('cs:fscanner:scanFinger', GetPlayerServerId(PlayerId()), TestTaker)
        else
            Notify(CodeStudio.Language.tester_smoke)
        end
    else
        TriggerServerEvent('cs:fscanner:scanFinger', 'self')
    end
end)


RegisterNetEvent('cs:fscanner:scanFinger', function(value)
    if prop and CodeStudio.Animations.Enable then
        ClearPedTasks(PlayerPedId())
        DeleteObject(prop)
    end
    SendNUIMessage({
        action = "scanFinger",
        time = CodeStudio.Wait_TIme * 1000,
        showFingerID = CodeStudio.Enable_Fingerprint_ID,
        data = value
    })
end)




RegisterNUICallback('closeUI', function(data)
    if data then
        if TargetPlayer then
            TriggerServerEvent('cs:fscanner:closeUI', TargetPlayer)
        end
    else
        isOpen = false
        SetNuiFocus(false, false)
        if TargetPlayer then
            TriggerServerEvent('cs:fscanner:closeUI', TargetPlayer)
        end
        TargetPlayer = nil
        TestTaker = nil
    end
    if prop and CodeStudio.Animations.Enable then
        ClearPedTasks(PlayerPedId())
        DeleteObject(prop)
    end
end)

RegisterNetEvent('cs:fscanner:closeUI', function(data)
    SendNUIMessage({
        action = "close"
    })
end)


function loadAnimDict(dict)	
    while not HasAnimDictLoaded(dict) do 
        RequestAnimDict(dict) Wait(5) 
    end 
end

function loadModel(model) 
    if not HasModelLoaded(model) then 
        RequestModel(model) 
        while not HasModelLoaded(model) do 
            Wait(0) 
        end 
    end 
end

function GetClosestPlayer(coords)
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    local closestPlayers = GetPlayersFromCoords(coords)
    local closestDistance = -1
    local closestPlayer = -1
    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() and closestPlayers[i] ~= -1 then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

function GetPlayersFromCoords(coords, distance)
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    distance = distance or 5
    local closePlayers = {}
    for _, player in pairs(players) do
        local target = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(target)
        local targetdistance = #(targetCoords - coords)
        if targetdistance <= distance then
            closePlayers[#closePlayers + 1] = player
        end
    end
    return closePlayers
end