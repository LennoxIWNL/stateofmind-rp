Core = nil
CoreName = nil
CoreReady = false
Citizen.CreateThread(function()
    for k, v in pairs(Cores) do
        if GetResourceState(v.ResourceName) == "starting" or GetResourceState(v.ResourceName) == "started" then
            CoreName = v.ResourceName
            Core = v.GetFramework()
            CoreReady = true
        end
    end
end)

function TriggerCallback(name, cb, ...)
    Config.ServerCallbacks[name] = cb
    TriggerServerEvent('ac-radio:server:triggerCallback', name, ...)
end

RegisterNetEvent('ac-radio:client:triggerCallback', function(name, ...)
    if Config.ServerCallbacks[name] then
        Config.ServerCallbacks[name](...)
        Config.ServerCallbacks[name] = nil
    end
end)

function Notify(text, length, type)
    if CoreName == "qb-core" then
        Core.Functions.Notify(text, length, type)
    elseif CoreName == "es_extended" then
        Core.ShowNotification(text)
    end
end

function GetPlayerData()
    if CoreName == "qb-core" then
        local player = Core.Functions.GetPlayerData()
        return player
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerData()
        return player
    end
end

function GetPlayerJob()
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayerData()
        return player.job
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerData()
        return player.job
    end
end

Citizen.CreateThread(function()
    -- Volume
	local volumeData = GetResourceKvpString('volume-ac-radio')
    if volumeData then RadioVolume = Round(tonumber(volumeData)) end
    if Config.ItemCheckLoop then
        while true do
            Citizen.Wait(5000)
            if onRadio then
                if CoreName == "qb-core" or CoreName == "qbx_core" then
                    if not DoRadioCheck() or PlayerData.metadata.isdead or PlayerData.metadata.inlaststand then
                        if RadioChannel ~= 0 then
                            leaveRadio()
                        end
                    end
                else
                    print(DoRadioCheck())
                    if not DoRadioCheck() then
                        if RadioChannel ~= 0 then
                            leaveRadio()
                        end
                    end
                end
            end
        end
    end
end)

-- ox_inventory's GetPlayerItems hands back its own PlayerData.inventory, which
-- is nil until it has finished setting the player up. som-compat fires
-- QBCore:Player:SetPlayerData the moment a character loads, and that is what
-- reaches DoRadioCheck, so on a fresh load the export answered nil and the
-- pairs() over it raised "table expected, got nil" every single time.
--
-- Waits rather than defaulting to an empty table: {} answers "no radio" for
-- somebody who is holding one, which is worse than a short wait. Capped,
-- because a spin with no end is its own bug, and on Wait(100) rather than
-- Wait(0) so this is not a per-frame loop.
function GetOxItems()
    local items = exports.ox_inventory:GetPlayerItems()
    local waited = 0

    while not items and waited < 10000 do
        Citizen.Wait(100)
        waited = waited + 100
        items = exports.ox_inventory:GetPlayerItems()
    end

    return items
end

function DoRadioCheck()
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local PlayerData = Core.Functions.GetPlayerData()
        while not next(PlayerData) do Citizen.Wait(0) end
        local hasOX = GetResourceState('ox_inventory') == 'started'
        if hasOX then
            local oxItems = GetOxItems()
            if not oxItems then return false end

            for k, v in pairs(oxItems) do
                if v.name == Config.RadioItem then
                    return true
                end
            end
            return false
        end
        for _, item in pairs(PlayerData.items) do
            if item.name == "radio" then
                return true
            end
        end
        return false
    elseif CoreName == "es_extended" then
        while not Core.IsPlayerLoaded() do Citizen.Wait(0) end
        local hasOX = GetResourceState('ox_inventory') == 'started'
        if hasOX then
            local oxItems = GetOxItems()
            if not oxItems then return false end

            for k, v in pairs(oxItems) do
                if v.name == Config.RadioItem then
                    return true
                end
            end
            return false
        end
        if Core.IsPlayerLoaded() then
            if Core.SearchInventory(Config.RadioItem, 1) then
                local hasItem = Core.SearchInventory(Config.RadioItem, 1) >= 1
                if hasItem then
                    return true
                end
            else
                return false
            end
        end
        return false
    end
end

--Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = Core.Functions.GetPlayerData()
    DoRadioCheck()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DoRadioCheck({})
    PlayerData = {}
    leaveRadio()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    DoRadioCheck()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    DoRadioCheck()
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        while not CoreReady do Citizen.Wait(0) end
        if CoreName == "qb-core" or CoreName == "qbx_core" then
            PlayerData = Core.Functions.GetPlayerData()
            DoRadioCheck()
        elseif CoreName == "es_extended" then
            DoRadioCheck()
        end
    end
end)