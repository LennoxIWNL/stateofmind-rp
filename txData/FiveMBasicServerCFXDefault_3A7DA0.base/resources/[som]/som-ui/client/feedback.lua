-- Feedback: the sound half of "something happened".
--
-- Exists because nothing on this server acknowledged an action. A purchase, a
-- vehicle coming out of a garage, a refusal: all of them changed some numbers
-- silently and left the player to infer the result from a list redrawing. That
-- is the difference between a shop and a debug menu, and it is not a per-screen
-- problem, so it is not solved per screen.
--
-- Deliberately tiny and deliberately central. One vocabulary of sounds, named
-- in shared/config.lua, so every resource says "purchase" rather than each one
-- choosing its own audio string and drifting.
--
-- Sound only. The VISUAL half belongs to whichever UI is on screen, because
-- only it knows what moved.

---@param kind string a key of Config.Sounds
local function playSound(kind)
    if not Config.Sounds or not Config.Sounds.enabled then return end

    local sound = Config.Sounds[kind]
    if not sound then return end

    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

exports('playSound', playSound)

-- Server-triggered, for feedback the client cannot know it earned: a fine
-- landing, a paycheck, a bill accepted somewhere else.
--
-- Cosmetic only, so there is nothing here worth validating beyond the argument
-- being a name we recognise. A client cannot fire this at another client;
-- TriggerClientEvent is server to client only.
RegisterNetEvent('som-ui:client:sound', function(kind)
    if type(kind) ~= 'string' then return end
    playSound(kind)
end)
