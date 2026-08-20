-- Skill checks: the authoritative state, and the drawing.
--
-- Same split as progress and context menus. This resource owns the one check on
-- screen and the NUI focus that comes with it; the shim that replaces
-- lib.skillCheck lives in client/skillcheck.lua and is loaded BY consumers so
-- that it runs where their `lib` table is.
--
-- Unlike the context menu this takes KEYBOARD focus and no cursor. A skill
-- check is a key press against a moving target, so the page has to receive the
-- key, and a cursor over the middle of the screen would be in the way.
--
-- WHAT THIS IS NOT. A skill check is a client side minigame and its result is a
-- claim made by the client, exactly as ox_lib's is. It decides presentation and
-- nothing else. No server action may treat "the player passed a skill check" as
-- authority for anything; the server re-checks the act itself, the same way it
-- does for every other interaction.

local activeToken = nil
local nextToken = 0
local deadman = nil

---Longest a check may run before the page is assumed dead.
---
---The page normally answers with a hit or a miss. It cannot if som-ui is
---restarted mid-check or a script error kills its loop, and the consumer is
---blocked on a promise, so without this a failed page would freeze whoever
---called it for the rest of the session with the focus still taken.
---@param rounds table[]
---@return number milliseconds
local function deadline(rounds)
    local total = 0

    for i = 1, #rounds do
        local speed = tonumber(rounds[i].speedMultiplier) or 1.0
        if speed <= 0 then speed = 1.0 end

        -- The page sweeps at 200 degrees per second times the multiplier, and
        -- the furthest the needle can ever have to travel in a round is an area
        -- starting at 270 degrees and 180 wide, so 450 degrees, so 2250ms at
        -- multiplier 1. Rounded up, plus the flash. Deliberately generous: this
        -- is a backstop for a dead page, and firing it on a slow but live one
        -- would report a miss the player did not make.
        total = total + (2500 / speed) + 500
    end

    return total + 2000
end

---@param token number
---@param success boolean
local function finish(token, success)
    if not activeToken or token ~= activeToken then return end

    activeToken = nil
    deadman = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'skillcheck:hide' })

    TriggerEvent('som-ui:client:skillcheck', { token = token, success = success })
end

---@param payload table { rounds = {{ areaSize, speedMultiplier }}, inputs = { 'e' } }
---@return number|nil token
local function open(payload)
    if type(payload) ~= 'table' or type(payload.rounds) ~= 'table' then return end
    if #payload.rounds == 0 then return end

    -- A second check while one is running is refused rather than allowed to
    -- take the screen. Unlike a menu, two of these overlapping means two
    -- resources both blocked on a promise and one of them never answered.
    if activeToken then return end

    nextToken = nextToken + 1
    local token = nextToken
    activeToken = token

    -- Focus but no cursor, and game input off: the page needs the key press and
    -- the player must not be able to drive through the check.
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'skillcheck:show',
        token = token,
        data = payload,
    })

    local limit = deadline(payload.rounds)

    deadman = token
    CreateThread(function()
        Wait(limit)
        if deadman == token then
            deadman = nil
            finish(token, false)
        end
    end)

    return token
end

---Cancelled by the caller, which counts as a miss. ox_lib's cancelSkillCheck
---resolves the promise the same way.
---@param token number|nil
local function cancel(token)
    if not activeToken then return end
    if token and token ~= activeToken then return end

    deadman = nil
    finish(activeToken, false)
end

---@param token number|nil
---@return boolean
local function isActive(token)
    if not activeToken then return false end
    if token and token ~= activeToken then return false end
    return true
end

exports('skillCheckOpen', open)
exports('skillCheckCancel', cancel)
exports('skillCheckActive', isActive)

-- ---------------------------------------------------------------------------
-- Back from the NUI
--
-- One callback, answered before anything is decided, for the reason the context
-- menu's header gives: a callback that throws before cb() leaves the page
-- waiting on a promise that never settles.
--
-- No colon in the name. It becomes the path of the page's fetch.
-- ---------------------------------------------------------------------------

RegisterNUICallback('skillCheckOver', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local token = tonumber(data.token)
    if not token or token ~= activeToken then return end

    local success = data.success == true

    if Feedback then Feedback.play(success and 'success' or 'error') end

    deadman = nil
    finish(token, success)
end)

-- A restart mid-check would otherwise leave focus taken with no page to answer
-- it, which is a player who can neither move nor click.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not activeToken then return end

    activeToken = nil
    deadman = nil
    SetNuiFocus(false, false)
end)
