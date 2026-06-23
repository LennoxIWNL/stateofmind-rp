local QBCore = exports['qb-core']:GetCoreObject()
local MenuWaiter = 0
local Weeds = {}
local isMenu = false
local MenuWeed = 1
local disable_actions = false 
local CurrentCops = 0
local peds = {}

RegisterNetEvent('police:SetCopCount')
AddEventHandler('police:SetCopCount', function(amount)
    CurrentCops = amount
end)


function StartSeed()
    local player = PlayerPedId()
    local coord = GetEntityCoords(player)
    local avaible = false  

    local cSCoords = GetOffsetFromEntityInWorldCoords(GetPlayerPed(PlayerId()), 0.0, 0.0, -5.0)
    local spatulaspawn = CreateObject(GetHashKey(Config.Props["spatulamodel"]), cSCoords.x, cSCoords.y, cSCoords.z, 1, 1, 1)
    local netid = ObjToNet(spatulaspawn)
    local hasItem = QBCore.Functions.HasItem("trowel")

    TaskStartScenarioInPlace(PlayerPedId(), "world_human_gardener_plant", 0, false)
    AttachEntityToEntity(spatulaspawn,GetPlayerPed(PlayerId()),GetPedBoneIndex(GetPlayerPed(PlayerId()), 28422),-0.005,0.0,0.0,190.0,190.0,-50.0,1,1,0,1,0,1)
    spatula_net = netid
    disable_actions = true
    Citizen.Wait(Config.Wait["Seed"] * 1000)
    disable_actions = false
    DetachEntity(NetToObj(spatula_net), 1, 1)
    DeleteEntity(NetToObj(spatula_net))
    spatula_net = nil
    ClearPedTasks(PlayerPedId())
    for k, v in pairs(Config.Coords) do
        local dst = #(coord - vector3(v.x,v.y,v.z))
        if dst < v.w then
            avaible = true 
        end
    end
    if avaible then 
        if hasItem then
            if CurrentCops >= Config.PoliceRequired then
                if #Weeds + 1 <= Config.MaxWeed then    
                    obj = CreateObject(Config.Props["Weed_Lvl1"], vector3(coord.x - 0.75, coord.y, coord.z - 1.5), true)
                    FreezeEntityPosition(obj, true)
                    TriggerServerEvent("BakiTelli_weed:RemoveWeedSeed")
                    Weeds[#Weeds + 1] = {
                        lvl = 1,
                        obj = obj,
                        growth = 5,
                        health = 10,
                        water = 5,
                        fertilizer = 5,
                        objcoord = GetEntityCoords(obj),
                    }
                else 
                    QBCore.Functions.Notify("You can only grow a maximum of 3 cannabis plants! Greedy!!!", "error", 4000)
                end
            else
                QBCore.Functions.Notify("There are not enough police on duty!", 'error', 4000)
            end
        else
            QBCore.Functions.Notify("You need a trowel to be able to plant")
        end
    else 
        QBCore.Functions.Notify("This area cannot be planted!","error",4000)
    end
end

Citizen.CreateThread(function()
	while true do
		local sleep = 1500
		local playercoord = GetEntityCoords(PlayerPedId())
        if #Weeds >= 1 then  
            for k, v in pairs(Weeds) do
		        local dst = #(playercoord - vector3(v.objcoord.x,v.objcoord.y,v.objcoord.z))
                if dst < 5 then 
				sleep = 1
                exports['pa-textui-2']:create3DTextUI("test2", {
                    id = 1,
                    coords = vector3(v.objcoord.x, v.objcoord.y, v.objcoord.z+1.0),
                    displayDist = 6.0,
                    interactDist = 2.0,
                    enableKeyClick = false, -- If true when you near it and click key it will trigger the event that you write inside triggerData
                    keyNum = 38,
                    key = "E",
                    text = Config.Langs["OpenWeed"],
                    theme = "green", -- or red
                    triggerData = {
                        triggerName = "",
                        args = {}
                    }
                })
				-- DrawText3D(v.objcoord.x, v.objcoord.y, v.objcoord.z+1.0, Config.Langs["OpenWeed"])
                    if dst < 2.5 then 
                        if IsControlJustReleased(0,38) then
                            OpenMenu(k)
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
	end
end)

Citizen.CreateThread(function()
	while true do
		local sleep = 1000
		local playercoord = GetEntityCoords(PlayerPedId())
        if disable_actions then 
            sleep = 0
            DisableAllControlActions(0)
        else 
            sleep = 1000
        end
        Citizen.Wait(sleep)
	end
end)

Citizen.CreateThread(function()
	while true do
        if #Weeds >= 1 then  
            for k, v in pairs(Weeds) do
                if v.growth <= 0 then
                    exports['pa-textui-2']:delete3DTextUI('test2')
                    DeleteEntity(v.obj)
                    table.remove(Weeds, k)
                    SendNUIMessage({action = "Close"})
                else
                    if v.health <= 0 then 
                        if v.water >= 0 and v.fertilizer >= 0 then 
                            Weeds[k].water = v.water - 1
                            Weeds[k].fertilizer = v.fertilizer - 1
                            Weeds[k].health = v.health + 0.5
                        else
                            Weeds[k].growth = v.growth - 0.5
                        end
                    else
                        if v.water >= 0 and v.fertilizer >= 0 then 
                            Weeds[k].water = v.water - 1
                            Weeds[k].fertilizer = v.fertilizer - 1
                            if Weeds[k].health >= 100 then 
                                Weeds[k].health = 100
                            else 
                                Weeds[k].health = v.health + 1
                            end
                        else
                            Weeds[k].health = v.health - 1
                        end
                    end
                    if v.health >= v.growth then 
                        if Weeds[k].growth >= 100 then 
                            Weeds[k].growth = 100
                        else 
                            Weeds[k].growth = v.growth + 1
                        end
                    else
                        Weeds[k].growth = v.growth - 0.5
                    end
                    if (v.growth >= 25 and v.lvl == 1) then
                        UpgradeWeed(k, 2)
                    elseif (v.growth >= 40 and v.lvl == 2) then 
                        UpgradeWeed(k, 3)
                    elseif (v.growth >= 65 and v.lvl == 3) then 
                        UpgradeWeed(k, 4)
                    elseif (v.growth >= 80 and v.lvl == 4) then 
                        UpgradeWeed(k, 5)
                    end
                    if isMenu then 
                        SendNUIMessage({
                            action="OpenMenu", 
                            growth = Weeds[MenuWeed].growth, 
                            health = Weeds[MenuWeed].health,
                            water = Weeds[MenuWeed].water,
                            fertilizer = Weeds[MenuWeed].fertilizer
                        })
                    end
                end
            end
        end
        Citizen.Wait(Config.Wait["Check"] * 1000)
	end
end)

function UpgradeWeed(weed_id, lvl)
    lvl = tonumber(lvl)
    weed_id = tonumber(weed_id)
    DeleteEntity(Weeds[weed_id].obj)
    if lvl == 2 then
       obj = CreateObject(Config.Props["Weed_Lvl2"], Weeds[weed_id].objcoord, true)
    elseif lvl == 3 then 
        obj = CreateObject(Config.Props["Weed_Lvl3"], Weeds[weed_id].objcoord, true)
    elseif lvl == 4 then 
        obj = CreateObject(Config.Props["Weed_Lvl4"], vector3(Weeds[weed_id].objcoord.x, Weeds[weed_id].objcoord.y, Weeds[weed_id].objcoord.z - 2.5), true)
    elseif lvl == 5 then 
        obj = CreateObject(Config.Props["Weed_Lvl5"], vector3(Weeds[weed_id].objcoord.x, Weeds[weed_id].objcoord.y, Weeds[weed_id].objcoord.z - 2.5), true)
    end
    FreezeEntityPosition(obj, true)
    Weeds[weed_id] = {
        lvl = lvl,
        obj = obj,
        growth = Weeds[weed_id].growth,
        health = Weeds[weed_id].health,
        water = Weeds[weed_id].water,
        fertilizer = Weeds[weed_id].fertilizer,
        objcoord = GetEntityCoords(obj),
    }
end

function OpenMenu(id)
    if MenuWaiter < GetGameTimer() then 
		MenuWaiter = GetGameTimer() + 3500
        SetNuiFocus(1, 1)
        isMenu = true 
        MenuWeed = id
        w = Weeds[id]
        SendNUIMessage({
            action="OpenMenu", 
            growth = w.growth, 
            health = w.health,
            water = w.water,
            fertilizer = w.fertilizer
        })
    else 
        -- notify(Config.Langs["Waiter"])
        QBCore.Functions.Notify("You can't open the menu too quickly, please wait a moment", "error", 4000)
    end
end

RegisterNUICallback("close", function ()
    MenuWaiter = GetGameTimer() + 2000
    SetNuiFocus(0, 0)
    isMenu = false 
end)

Citizen.CreateThread(function()
    for k, v in pairs(Config.Coords) do        
        if Config.Blip.Alpha then 
            local Alpha = AddBlipForRadius(v.x,v.y,v.z, v.w)
            SetBlipHighDetail(Alpha, true)
            SetBlipColour(Alpha, 1)
            SetBlipAlpha (Alpha, 128)
        end
        if Config.Blip.Blip then 
            blip = AddBlipForCoord(v.x, v.y, v.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(Config.Langs.Blip)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

function LoadProp()
    for k, v in pairs(Config.Props) do        
        if not HasModelLoaded(v) then
            RequestModel(v)
            while not HasModelLoaded(v) do
                Citizen.Wait(1)
            end
        end
    end
end

function Harvest(id)
    local cSCoords = GetOffsetFromEntityInWorldCoords(GetPlayerPed(PlayerId()), 0.0, 0.0, -5.0)
    local spatulaspawn = CreateObject(GetHashKey(Config.Props["spatulamodel"]), cSCoords.x, cSCoords.y, cSCoords.z, 1, 1, 1)
    local netid = ObjToNet(spatulaspawn)
    local hasItem = QBCore.Functions.HasItem("empty_weed_bag")
    local hasitemnilon = QBCore.Functions.HasItem("cutter")
    if hasItem then
        if hasitemnilon then
            TaskStartScenarioInPlace(PlayerPedId(), "world_human_gardener_plant", 0, false)
            AttachEntityToEntity(spatulaspawn,GetPlayerPed(PlayerId()),GetPedBoneIndex(GetPlayerPed(PlayerId()), 28422),-0.005,0.0,0.0,190.0,190.0,-50.0,1,1,0,1,0,1)
            spatula_net = netid
            disable_actions = true
            Citizen.Wait(Config.Wait["Harvest"] * 1000)
            disable_actions = false
            DetachEntity(NetToObj(spatula_net), 1, 1)
            DeleteEntity(NetToObj(spatula_net))
            spatula_net = nil
            ClearPedTasks(PlayerPedId())
            if Weeds[id].growth >= 30 then 
                -- GiveWeed = math.ceil(Weeds[id].growth * Config.Harvest / 10)
                GiveWeed = 1
                TriggerServerEvent("BakiTelli_weed:Harvest", GiveWeed)
                -- notify(Config.Langs["Harvest"])
                exports['pa-textui-2']:delete3DTextUI('test2')
                QBCore.Functions.Notify("You have successfully harvested!","success", 4000)
            else 
                -- notify(Config.Langs["Harvest_eror"])
                QBCore.Functions.Notify("Too early to harvest!", "error", 4000)
            end
            exports['pa-textui-2']:delete3DTextUI('test2')
            DeleteEntity(Weeds[id].obj)
            table.remove(Weeds, id)
            SendNUIMessage({action = "Close"})
        else
            QBCore.Functions.Notify("You don't have a plastic bag yet","error", 4000)
        end
    else
        QBCore.Functions.Notify("You don't have scissors yet","error", 4000)
    end
end

AddEventHandler('onClientMapStop', function()
    for k, v in pairs(Weeds) do
        DeleteEntity(v.obj)
        exports['pa-textui-2']:delete3DTextUI('test2')
    end
end)

RegisterNUICallback("Give", function (data)
    if data.idx == "Harvest" then
        Harvest(MenuWeed)
    else 
        TriggerServerEvent("BakiTelli_weed:giveSV", MenuWeed, data.idx)
    end
end)

AddEventHandler("BakiTelli_weed:giveCl")
RegisterNetEvent("BakiTelli_weed:giveCl", function (MenuW,idx)
    if idx == "Water" then
        Weeds[MenuW].water = Weeds[MenuW].water + Config.Give["Water"]
    elseif idx == "Fertilizer" then 
        Weeds[MenuW].fertilizer = Weeds[MenuW].fertilizer + Config.Give["Fertilizer"]
    elseif idx == "Dust" then
        if Weeds[MenuW].health >= 100 then 
            Weeds[MenuW].growth = 100
        else 
            Weeds[MenuW].health = Weeds[MenuW].health + Config.Give.Dust["Healt"]
        end
        if Weeds[MenuW].growth >= 100 then 
            Weeds[MenuW].growth = 100
        else 
            Weeds[MenuW].growth = Weeds[MenuW].growth + Config.Give.Dust["Growth"]
        end
    end
    if isMenu then 
        SendNUIMessage({
            action="OpenMenu", 
            growth = Weeds[MenuW].growth, 
            health =  Weeds[MenuW].health,
            water = Weeds[MenuW].water,
            fertilizer = Weeds[MenuW].fertilizer
        })
    end
end)

RegisterNetEvent('ler-haican:client:dieuchecan')
AddEventHandler('ler-haican:client:dieuchecan', function()
    local hasItem = QBCore.Functions.HasItem("weedbud")
    if hasItem then
        QBCore.Functions.Progressbar("search_register", "Drying Can..", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
            disableInventory = true,
        }, {}, {}, {}, function()
         TriggerServerEvent('ler-weedpicking:processweed2')
            ClearPedTasks(PlayerPedId())
        end, function()
            ClearPedTasks(PlayerPedId())
        end) -- Cancel
    end
end)

exports['qb-target']:AddTargetModel(`a_f_m_fatbla_01`, {
    options = {
        {
            event = "ler-haican:client:dieuchecan",
            icon = "fas fa-anchor",
            label = "Drying Can",
        },
    },
    distance = 2.0
})

AddEventHandler("BakiTelli_weed:Seed")
RegisterNetEvent("BakiTelli_weed:Seed", function ()
    StartSeed()
end)