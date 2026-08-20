-- lib.skillCheck, lib.cancelSkillCheck and lib.skillCheckActive, replaced with
-- som-ui's.
--
-- NOT loaded by som-ui, and NOT in its client_scripts. Consumers load it
-- themselves, after ox_lib:
--
--     client_scripts {
--         '@som-ui/client/skillcheck.lua',
--         'client/whatever.lua',
--     }
--
-- For that include to resolve, this path is listed in som-ui's files{} block.
-- Read the header of client/progressbar.lua before changing any of that: the
-- three silent traps it documents apply here identically.
--
-- WHY THIS EXISTS. Same reason as the progress bar and the context menu:
-- ox_lib's UI is a compiled React bundle and cannot be restyled, so every skill
-- check on the server looked like ox_lib. This one is the third and smallest of
-- the three, and it is the one som-lockpick is waiting on.
--
-- WHAT DIFFERS FROM THE OTHER TWO SHIMS. There is no closure to keep on this
-- side: a skill check takes a difficulty and returns a boolean. So this file is
-- only a translation of ox_lib's argument shapes into the one shape the page
-- draws, plus the blocking promise that ox_lib's own callers expect.
--
-- The result is a CLIENT CLAIM, as it is in ox_lib. It decides presentation.
-- Nothing a server does may rest on it; see client/skillcheckui.lua.

if not lib then return end

-- Kept so a stopped som-ui degrades to ox_lib's minigame rather than failing
-- every lockpick on the server.
local oxSkillCheck = lib.skillCheck
local oxCancelSkillCheck = lib.cancelSkillCheck
local oxSkillCheckActive = lib.skillCheckActive

local ui = exports['som-ui']

local pending = nil
local token = nil

local function uiReady()
    return GetResourceState('som-ui') == 'started'
end

-- ox_lib's three named difficulties, with its own numbers. areaSize is the size
-- of the target arc in degrees and speedMultiplier scales how fast the needle
-- travels, so hard is a smaller target reached sooner.
local PRESETS = {
    easy   = { areaSize = 50, speedMultiplier = 1.0 },
    medium = { areaSize = 40, speedMultiplier = 1.5 },
    hard   = { areaSize = 25, speedMultiplier = 1.75 },
}

---@param entry string|table
---@return table|nil
local function round(entry)
    if type(entry) == 'string' then
        local preset = PRESETS[entry]
        return preset and { areaSize = preset.areaSize, speedMultiplier = preset.speedMultiplier } or nil
    end

    if type(entry) ~= 'table' then return nil end

    -- A caller-supplied table. Clamped rather than trusted: an areaSize of 400
    -- is a target that covers the whole dial and a speedMultiplier of 0 is a
    -- needle that never arrives, and both read as the minigame being broken.
    local area = tonumber(entry.areaSize) or 50
    local speed = tonumber(entry.speedMultiplier) or 1.0

    if area < 5 then area = 5 elseif area > 180 then area = 180 end
    if speed < 0.25 then speed = 0.25 elseif speed > 5 then speed = 5 end

    return { areaSize = area, speedMultiplier = speed }
end

---ox_lib accepts one difficulty or an array of them, where an array means
---consecutive rounds and all of them have to be passed.
---@param difficulty any
---@return table[]
local function rounds(difficulty)
    -- A single table difficulty is itself a map, so the array test is on the
    -- first element rather than on the type.
    if type(difficulty) == 'table' and difficulty[1] ~= nil then
        local out = {}

        for index = 1, #difficulty do
            local entry = round(difficulty[index])
            if entry then out[#out + 1] = entry end
        end

        return out
    end

    local entry = round(difficulty)
    return entry and { entry } or {}
end

---ox_lib defaults to the E key and picks one of the given keys per round.
---@param inputs any
---@return string[]
local function keys(inputs)
    if type(inputs) ~= 'table' or inputs[1] == nil then return { 'e' } end

    local out = {}

    for index = 1, #inputs do
        local key = inputs[index]
        if type(key) == 'string' and #key > 0 then
            out[#out + 1] = key:lower()
        end
    end

    return #out > 0 and out or { 'e' }
end

-- ---------------------------------------------------------------------------
-- The ox_lib surface
-- ---------------------------------------------------------------------------

---@param difficulty string|table|table[]
---@param inputs string[]|nil
---@return boolean|nil
function lib.skillCheck(difficulty, inputs)
    if not uiReady() then return oxSkillCheck(difficulty, inputs) end

    -- ox_lib returns nil rather than erroring when one is already running, and
    -- callers written against it check for that.
    if pending then return end

    local list = rounds(difficulty)
    if #list == 0 then return end

    local claimed = ui:skillCheckOpen({ rounds = list, inputs = keys(inputs) })
    if not claimed then return end

    token = claimed
    pending = promise.new()

    local result = Citizen.Await(pending)

    pending = nil
    token = nil

    return result
end

function lib.cancelSkillCheck()
    if not uiReady() then return oxCancelSkillCheck() end

    -- ox_lib errors here, and callers rely on that to catch a cancel with
    -- nothing to cancel, so the behaviour is kept.
    if not pending then error('No skillCheck is active') end

    ui:skillCheckCancel(token)
end

---@return boolean
function lib.skillCheckActive()
    if not uiReady() then return oxSkillCheckActive() end

    return pending ~= nil
end

-- ---------------------------------------------------------------------------
-- The result coming back
--
-- One handler per consuming resource, resolved by token, exactly as the context
-- menu shim does: som-ui broadcasts and only the resource holding the live
-- token acts on it.
-- ---------------------------------------------------------------------------

AddEventHandler('som-ui:client:skillcheck', function(msg)
    if type(msg) ~= 'table' then return end
    if not pending or not token or msg.token ~= token then return end

    pending:resolve(msg.success == true)
end)
