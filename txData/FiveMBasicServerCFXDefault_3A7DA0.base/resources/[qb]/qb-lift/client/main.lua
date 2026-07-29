-- Copyright (C) 2021 KUMApt & Shadowskrt

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local PlayerJob, PlayerGang = {}
local floorsMenu = {}

AddEventHandler('onResourceStart', function(resource)
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
    PlayerGang = PlayerData.gang
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
    PlayerGang = PlayerData.gang
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    PlayerGang = gang
end)

-- local DrawText3Ds = function(x, y, z, text)
-- 	SetTextScale(0.35, 0.35)
--     SetTextFont(4)
--     SetTextProportional(1)
--     SetTextColour(255, 255, 255, 215)
--     SetTextEntry("STRING")
--     SetTextCentre(true)
--     AddTextComponentString(text)
--     SetDrawOrigin(x,y,z, 0)
--     DrawText(0.0, 0.0)
--     local factor = (string.len(text)) / 370
--     DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
--     ClearDrawOrigin()
-- end

local function openFloorsMenu(lift, floor)
    floorsMenu = {
        {
            header = Config.Elevators[lift].Name,
            text = Config.Language[Config.UseLanguage].CurrentFloor .. Config.Elevators[lift].Floors[floor].Label,
            isMenuHeader = true
        },
    }

    for j = 1, #Config.Elevators[lift].Floors, 1 do
        if j ~= floor then
            floorsMenu[#floorsMenu + 1] = {
                header = '' .. Config.Elevators[lift].Floors[j].Label ..'',
                txt = '' .. Config.Elevators[lift].Floors[j].FloorDesc ..'',
                params = {
                    event = 'qb-lift:checkFloorPermission',
                    args = {
                        lift = lift,
                        floor = Config.Elevators[lift].Floors[j],
                    }
                }
            }
        end
	end
    exports['qb-menu']:openMenu(floorsMenu)
end

local function changeFloor(data)
    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(600)
    StopAnimTask(ped, "anim@apt_trans@elevator", "elev_1", 1.0)
    SetEntityCoords(ped, data.floor.Coords.x, data.floor.Coords.y, data.floor.Coords.z, 0, 0, 0, false)
    SetEntityHeading(ped, tonumber(data.floor.ExitHeading) or 0.0)
    Wait(500)
    DoScreenFadeIn(600)
end

CreateThread(function()
    while not HasStreamedTextureDictLoaded("ozzi_ui") do Wait(10) RequestStreamedTextureDict("ozzi_ui", true) end
    Wait(1000)
    while true do
        Wait(5)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local inLiftRange = false
        for k, v in pairs(Config.Elevators) do
            for i, b in pairs(Config.Elevators[k].Floors) do
                local liftDist = #(pos - b.Coords)
                SetDrawOrigin( b.Coords.x, b.Coords.y, b.Coords.z + 0.2, 0)
                if liftDist <= 7 then
                    inLiftRange = true
                    DrawMarker(2, b.Coords.x, b.Coords.y, b.Coords.z + 0.3, 0, 0, 0, 0, 0, 0,
                        0.15, 0.15, 0.15, 255, 20, 147, 180, false, true, 2, false, nil, nil, false)
                    if liftDist <= 1.5 then
                        if not IsPedInAnyVehicle(ped) then
                            SetTextFont(4)
                            SetTextScale(0.35, 0.35)
                            SetTextColour(255, 20, 147, 255)
                            SetTextOutline()
                            SetTextCentre(true)
                            SetTextEntry('STRING')
                            AddTextComponentString('~w~[~q~E~w~] Elevator')
                            DrawText(0.5, 0.9)
                            if IsControlJustPressed(0, 38) then
                                openFloorsMenu(k, i)
                            end
                        end
                    end
                end
            end
        end
        if not inLiftRange then
            Wait(1000)
        end
    end
end)



RegisterNetEvent('qb-lift:checkFloorPermission')
AddEventHandler('qb-lift:checkFloorPermission', function(data)
    if Config.Elevators[data.lift].Group then
        if data.floor.Restricted then
            if IsAuthorized(data.lift) then
                changeFloor(data)
            else
                QBCore.Functions.Notify(Config.Language[Config.UseLanguage].Restricted, "error")
            end
        else
            changeFloor(data)
        end
    else
        changeFloor(data)
    end
end)

--helper function
function IsAuthorized(lift)
    for a=1, #Config.Elevators[lift].Group do
        if PlayerJob.name == Config.Elevators[lift].Group[a] or PlayerGang.name == Config.Elevators[lift].Group[a] then
            return true
        end
    end
    return false
end