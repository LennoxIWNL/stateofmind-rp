--- Challenges the server owns. The client is shown a puzzle and sends back an
--- answer; the server decides whether it is right, whether it came too fast,
--- and whether the token is still good. Callers get a boolean taken from the
--- server's own state, never from what the client says it did.
---
--- A puzzle on a screen can still be solved by a bot. What this stops is
--- skipping the puzzle, repeating a solved one, and reporting a win that never
--- happened, which is what every client-reported minigame allows.

Hack = {}

-- source -> challenge. One at a time per player.
local active = {}

local function now() return GetGameTimer() end

local function nonce()
    return ('%08x%08x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
end

local function newCode(length)
    local code = {}
    for i = 1, length do code[i] = math.random(0, 9) end
    return code
end

---@param size number
---@param count number
---@return table marks, number[] order cell indexes in the order they must be picked
local function newMarks(size, count)
    local cells = {}
    for i = 1, size * size do cells[i] = i end
    for i = #cells, 2, -1 do
        local j = math.random(i)
        cells[i], cells[j] = cells[j], cells[i]
    end

    local numbers = {}
    for n = 1, count do numbers[n] = n end
    for i = #numbers, 2, -1 do
        local j = math.random(i)
        numbers[i], numbers[j] = numbers[j], numbers[i]
    end

    local marks, order = {}, {}
    for i = 1, count do
        marks[i] = { cell = cells[i], n = numbers[i] }
        order[numbers[i]] = cells[i]
    end

    return marks, order
end

---Starts a challenge. The returned view is what the client may see: for memory
---that necessarily includes the numbers, for crack it never includes the code.
---@param source number
---@param kind string 'memory' or 'crack'
---@param level string 'easy', 'normal' or 'hard'
---@return table|nil view, string|nil error
function Hack.Begin(source, kind, level)
    local settings = (kind == 'memory' and Config.Memory or kind == 'crack' and Config.Crack or {})[level]
    if type(level) ~= 'string' or type(settings) ~= 'table' then return nil, 'no such challenge' end

    local current = active[source]
    if current and not current.done and now() < current.expiresAt then return nil, 'busy' end

    local challenge = {
        kind = kind, nonce = nonce(), startedAt = now(), expiresAt = now() + Config.ExpireMs,
        solved = false, done = false,
    }

    local view = { kind = kind, nonce = challenge.nonce }

    if kind == 'memory' then
        local marks, order = newMarks(settings.size, settings.count)
        challenge.order = order
        challenge.minMs = settings.showMs + settings.count * Config.Memory.minClickMs
        view.size, view.showMs, view.marks = settings.size, settings.showMs, marks
    else
        challenge.code = newCode(settings.length)
        challenge.attempts = settings.attempts
        view.length, view.attempts = settings.length, settings.attempts
    end

    active[source] = challenge
    return view
end

---@param source number
---@param token any
---@return table|nil challenge, string|nil error
local function open(source, token)
    local challenge = active[source]
    if not challenge or challenge.nonce ~= token then return nil, 'no such challenge' end
    if challenge.done then return nil, 'already answered' end

    if now() > challenge.expiresAt then
        challenge.done = true
        return nil, 'too late'
    end

    return challenge
end

---Memory: the answer is the cells picked, in order. Single use whatever the result.
---@param source number
---@param token any
---@param answer any
---@return table
function Hack.Submit(source, token, answer)
    local challenge, err = open(source, token)
    if not challenge or challenge.kind ~= 'memory' then return { success = false, error = err or 'wrong challenge' } end

    challenge.done = true

    if type(answer) ~= 'table' or #answer ~= #challenge.order then return { success = true, solved = false } end
    if now() - challenge.startedAt < challenge.minMs then return { success = true, solved = false } end

    for i, cell in ipairs(challenge.order) do
        if answer[i] ~= cell then return { success = true, solved = false } end
    end

    challenge.solved = true
    return { success = true, solved = true }
end

---Crack: one guess. The code stays here; the client only ever sees feedback.
---@param source number
---@param token any
---@param guess any
---@return table
function Hack.Guess(source, token, guess)
    local challenge, err = open(source, token)
    if not challenge or challenge.kind ~= 'crack' then return { success = false, error = err or 'wrong challenge' } end

    local code = challenge.code

    if type(guess) ~= 'table' or #guess ~= #code then return { success = false, error = 'bad guess' } end
    for i = 1, #code do
        if math.type(guess[i]) ~= 'integer' or guess[i] < 0 or guess[i] > 9 then
            return { success = false, error = 'bad guess' }
        end
    end

    if challenge.lastGuess and now() - challenge.lastGuess < Config.Crack.guessGapMs then
        return { success = false, error = 'slow down' }
    end
    challenge.lastGuess = now()

    local feedback, left = {}, {}
    for i = 1, #code do
        if guess[i] == code[i] then
            feedback[i] = 'hit'
        else
            feedback[i] = 'miss'
            left[code[i]] = (left[code[i]] or 0) + 1
        end
    end

    for i = 1, #code do
        if feedback[i] == 'miss' and (left[guess[i]] or 0) > 0 then
            feedback[i] = 'near'
            left[guess[i]] = left[guess[i]] - 1
        end
    end

    challenge.attempts = challenge.attempts - 1

    local solved = true
    for i = 1, #code do
        if feedback[i] ~= 'hit' then solved = false end
    end

    if solved then challenge.solved = true end
    if solved or challenge.attempts <= 0 then challenge.done = true end

    return { success = true, feedback = feedback, left = challenge.attempts, solved = solved, done = challenge.done }
end

---How the player is shown a challenge. A field so tests can stand in for a client.
---Blocks until the client says it is finished or the challenge expires; what it
---returns is ignored, the result is read from the server's own record.
---@param source number
---@param view table
Hack.Play = function(source, view)
    local finished = promise.new()

    lib.callback('som-hack:client:play', source, function() finished:resolve(true) end, view)
    SetTimeout(Config.ExpireMs, function() finished:resolve(false) end)

    Citizen.Await(finished)
end

---Runs a challenge for a player and returns whether the SERVER saw it solved.
---Called by other resources, from a thread, since it waits on the player.
---@param source number
---@param kind string
---@param level string
---@return boolean solved, string|nil error
function Hack.Run(source, kind, level)
    local view, err = Hack.Begin(source, kind, level)
    if not view then return false, err end

    pcall(Hack.Play, source, view)

    local challenge = active[source]
    local solved = challenge ~= nil and challenge.nonce == view.nonce and challenge.solved == true

    if challenge and challenge.nonce == view.nonce then challenge.done = true end
    return solved
end

lib.callback.register('som-hack:server:submit', function(source, token, answer)
    return Hack.Submit(source, token, answer)
end)

lib.callback.register('som-hack:server:guess', function(source, token, guess)
    return Hack.Guess(source, token, guess)
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
end)

exports('run', Hack.Run)
