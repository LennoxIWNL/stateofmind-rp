-- Pause overlay.
--
-- A pink wash over the paused world, and nothing else. The native menu does
-- everything: map, settings, waypoints, quitting.
--
-- Drawn with DrawRect rather than NUI, and that is the entire point. NUI
-- renders above the frontend and captures the cursor, which made the menu
-- underneath unclickable. DrawRect goes into the game's 2D layer, so the menu
-- draws over the top of it and there is no cursor to steal.
--
-- A full custom pause menu was built before this and thrown away. See the
-- README.

local tint = Config.Tint

CreateThread(function()
    while true do
        if IsPauseMenuActive() then
            -- Per frame is what drawing demands: a DrawRect lasts one frame.
            -- The loop only spins while the menu is actually open.
            repeat
                DrawRect(0.5, 0.5, 1.0, 1.0, tint.r, tint.g, tint.b, tint.a)
                Wait(0)
            until not IsPauseMenuActive()
        end

        Wait(200)
    end
end)
