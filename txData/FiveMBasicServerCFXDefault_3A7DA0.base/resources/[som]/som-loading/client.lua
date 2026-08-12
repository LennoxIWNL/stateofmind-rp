-- Dismisses the loading screen.
--
-- loadscreen_manual_shutdown 'yes' in the manifest means the game will NOT take
-- this page down on its own. If this thread never runs, the player sits on the
-- loading screen forever, so everything here is deliberately unconditional:
-- no config gate, no early return, no dependency on another resource.
--
-- There is no server half and no NUI callback. The page cannot talk back
-- during a loadscreen, because the client that would answer does not exist
-- yet, so the whole contract is one way: the game posts loadProgress in and
-- this file decides when it is over.

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(200)
    end

    -- A beat past the session actually starting. Tearing the page down on the
    -- exact frame the session begins drops the player onto an unrendered world
    -- for a moment, which reads worse than a slightly longer load.
    Wait(500)

    -- BOTH are needed and they do different things. ShutdownLoadingScreen ends
    -- the game's own loading state; ShutdownLoadingScreenNui removes this page.
    -- Calling only the first leaves the page on screen over a live game.
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)
