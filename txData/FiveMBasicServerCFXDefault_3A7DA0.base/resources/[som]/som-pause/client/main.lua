-- Pause menu client.
--
-- Thin, like every other som-* client: it owns the native suppression and the
-- map hole, nothing else. Character data, permissions and the player count all
-- come from the server, because a client asking itself who it is would be
-- answering its own question.

local isOpen = false
local onMap = false

local MINIMAP_COMPONENTS = { 'minimap', 'minimap_mask', 'minimap_blur' }

---Puts the expanded radar behind the hole in the UI.
---@param enabled boolean
local function setMap(enabled)
    onMap = enabled

    if not enabled then
        SetBigmapActive(false, false)
        DisplayRadar(false)
        return
    end

    DisplayRadar(true)
    SetBigmapActive(true, false)

    if not Config.Map.reposition then return end

    for _, component in ipairs(MINIMAP_COMPONENTS) do
        SetMinimapComponentPosition(component, 'L', 'B',
            Config.Map.posX, Config.Map.posY, Config.Map.sizeX, Config.Map.sizeY)
    end
end

local function close()
    if not isOpen then return end

    isOpen = false
    setMap(false)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(200)

    -- Hand the radar back in whatever state the HUD normally wants it.
    DisplayRadar(true)
end

local function open()
    if isOpen then return end
    if not exports['som-core']:isPlayerLoaded() then return end

    local data = lib.callback.await('som-pause:server:overview', false)
    if not data then return end

    -- Waypoint list is flattened here so the NUI never holds coordinates: it
    -- sends back an index, and this file resolves it against config.
    local destinations = {}
    for i, entry in ipairs(Config.Waypoints) do
        destinations[i] = { index = i, label = entry.label, category = entry.category }
    end

    isOpen = true
    TriggerScreenblurFadeIn(Config.Overlay.blurMs)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            tabs = data.tabs,
            character = data.character,
            server = data.server,
            staff = data.staff,
            overlay = Config.Overlay,
            config = Config.Server,
            map = Config.Map,
            destinations = destinations,
        },
    })

    setMap(true)
end

-- The native menu cannot be styled or tinted, so it is closed the frame it
-- opens and this one takes its place. A per-frame check is what input demands
-- here: polling slower lets the native menu visibly flash first.
CreateThread(function()
    while true do
        if IsPauseMenuActive() then
            SetPauseMenuActive(false)
            if not isOpen then open() end
        end

        if isOpen then
            -- Nothing should reach the world while paused.
            DisableAllControlActions(0)

            if onMap then
                if Config.Map.hideStreetNames then
                    HideHudComponentThisFrame(9)   -- street name
                    HideHudComponentThisFrame(7)   -- area name
                end
                HideHudComponentThisFrame(14)      -- reticle
            else
                HideHudAndRadarThisFrame()
            end
        end

        Wait(0)
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('tab', function(data, cb)
    cb({})
    setMap(type(data) == 'table' and data.id == 'map')
end)

RegisterNUICallback('waypoint', function(data, cb)
    local index = type(data) == 'table' and tonumber(data.index)
    local entry = index and Config.Waypoints[index]

    if not entry then
        cb({ success = false })
        return
    end

    SetNewWaypoint(entry.coords.x, entry.coords.y)
    cb({ success = true, label = entry.label })
end)

RegisterNUICallback('clearWaypoint', function(_, cb)
    -- 8 is the waypoint blip sprite; deleting it is how the game clears one.
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    cb({ success = true })
end)

RegisterNUICallback('quit', function(_, cb)
    cb({})
    -- The server drops the player, so the save-on-drop path in som-core runs
    -- exactly as it would for any other disconnect.
    TriggerServerEvent('som-pause:server:quit')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not isOpen then return end

    SetNuiFocus(false, false)
    SetBigmapActive(false, false)
    DisplayRadar(true)
    TriggerScreenblurFadeOut(0)
end)
