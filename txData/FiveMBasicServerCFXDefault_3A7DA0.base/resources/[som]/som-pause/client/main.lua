-- Pause bar client.
--
-- Nothing here touches the minimap. An earlier version expanded the radar and
-- repositioned its components to sit behind a custom map panel, and never put
-- them back, which left the HUD with a huge translucent map stuck on screen.
-- The native map does that job properly, so this hands off to it instead.

local FRONTEND = GetHashKey('FE_MENU_VERSION_MP_PAUSE')

local isOpen = false
-- Set while the native frontend is deliberately open. The suppression loop
-- below closes any pause menu it sees, so without this it would instantly
-- close the map it was just asked to open.
local handedOff = false

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerScreenblurFadeOut(200)
end

local function open()
    if isOpen or handedOff then return end
    if not exports['som-core']:isPlayerLoaded() then return end

    local data = lib.callback.await('som-pause:server:overview', false)
    if not data then return end

    isOpen = true
    TriggerScreenblurFadeIn(Config.Overlay.blurMs)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            actions = Config.Actions,
            character = data.character,
            server = data.server,
            overlay = Config.Overlay,
            config = Config.Server,
        },
    })
end

---Closes the bar and opens a native frontend page.
---@param frontend number last argument to ActivateFrontendMenu
local function handOff(frontend)
    close()
    handedOff = true

    -- A frame of daylight so the NUI focus release lands before the frontend
    -- takes input, otherwise the menu opens with the cursor still captured.
    CreateThread(function()
        Wait(50)
        ActivateFrontendMenu(FRONTEND, false, frontend)

        -- Hold the suppression off until the player leaves the native menu.
        while not IsPauseMenuActive() do Wait(50) end
        while IsPauseMenuActive() do Wait(100) end

        handedOff = false
    end)
end

-- The beige wash is part of the native menu render, so the menu is closed the
-- frame it opens and this bar takes its place. A per-frame check is what input
-- demands here: polling slower lets the native menu visibly flash first.
CreateThread(function()
    while true do
        if not handedOff and IsPauseMenuActive() then
            SetPauseMenuActive(false)
            if not isOpen then open() end
        end

        -- Nothing should reach the world while the bar is up.
        if isOpen then DisableAllControlActions(0) end

        Wait(0)
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('action', function(data, cb)
    cb({})

    local id = type(data) == 'table' and data.id
    if not id then return end

    for _, action in ipairs(Config.Actions) do
        if action.id == id then
            if action.frontend then
                handOff(action.frontend)
            elseif id == 'disconnect' then
                -- The server drops the player, so som-core's save-on-drop path
                -- runs exactly as it would for any other disconnect.
                TriggerServerEvent('som-pause:server:quit')
            end
            return
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not isOpen then return end

    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(0)
end)
