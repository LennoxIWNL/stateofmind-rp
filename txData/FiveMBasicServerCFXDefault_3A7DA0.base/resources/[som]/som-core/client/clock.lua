--- Applies the server's game clock. Nothing runs per frame: it applies when the state changes, when the
--- character has loaded, and on a slow timer that corrects drift and recovers after the character select scene.

local FROZEN_MS = 99999999

local function apply(state)
    -- Until the character has loaded, som-multichar owns the clock for its scene.
    if not exports['som-core']:isPlayerLoaded() then return end
    if type(state) ~= 'table' then return end

    local h, m, s = SomClock.Time(GetCloudTimeAsInt(), state)
    NetworkOverrideClockTime(h, m, s)
    NetworkOverrideClockMillisecondsPerGameMinute(state.frozen and FROZEN_MS or math.floor(state.dayMinutes * 60000 / 1440))
end

-- The handler gets the new value itself; GlobalState may not hold it yet when the handler runs.
AddStateBagChangeHandler('somClock', 'global', function(_, _, value) apply(value) end)
AddEventHandler('som:client:onPlayerLoaded', function() apply(GlobalState.somClock) end)

CreateThread(function()
    while true do
        Wait(15000)
        apply(GlobalState.somClock)
    end
end)
