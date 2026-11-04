--- Bail: a quote, then a commit, same shape som-housing's mortgage flow
--- already uses. Forfeiture itself lives in jail.lua's book handler, not
--- here — see its comment for why that's not a second money movement.

local core = exports['som-core']

Bail = {}

---The caller's own active sentence plus its remaining seconds, or nil.
---@param citizenid string
---@return table|nil sentence, number|nil remaining
local function activeWithRemaining(citizenid)
    local sentence = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, booked_at, NOW()) AS elapsed
        FROM som_jail_sentences WHERE citizenid = ? AND status = 'serving'
    ]], { citizenid })

    if not sentence then return nil, nil end

    local remaining = sentence.total_seconds - (tonumber(sentence.elapsed) or 0)
    if remaining < 0 then remaining = 0 end

    return sentence, remaining
end

---Eligibility plus the amount, re-derived every time rather than cached —
---the client never gets to hand this number back.
---@param citizenid string
---@return boolean eligible, number|string amountOrError
local function quote(citizenid)
    local sentence, remaining = activeWithRemaining(citizenid)
    if not sentence then return false, 'not currently serving a sentence' end

    if sentence.total_seconds < Config.Bail.felonyThresholdMonths * Config.Cell.secondsPerMonth then
        return false, 'not eligible for bail'
    end

    local existing = MySQL.scalar.await(
        "SELECT id FROM som_jail_bail WHERE sentence_id = ? AND status = 'posted'",
        { sentence.id })
    if existing then return false, 'bail already posted' end

    local amount = math.max(Config.Bail.minAmount, remaining * Config.Bail.rateMultiplier)
    return true, amount, sentence
end

lib.callback.register('som-jail:server:bailQuote', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local eligible, amountOrError = quote(player.citizenid)
    if not eligible then return { success = false, error = amountOrError } end

    return { success = true, amount = amountOrError }
end)

lib.callback.register('som-jail:server:requestBail', function(source, data)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    -- Re-derived from scratch. The client sends nothing usable here — not
    -- even an account, since this always pays from bank, matching how a
    -- fine is paid — the same discipline som-housing's mortgage flow uses:
    -- "the client sends a slug, never a price."
    local eligible, amount, sentence = quote(player.citizenid)
    if not eligible then return { success = false, error = amount } end

    local paid, payErr = core:payWith(source, 'bank', amount,
        ('bail:%d'):format(sentence.id))

    if not paid then
        return { success = false, error = payErr or 'could not pay' }
    end

    MySQL.insert.await([[
        INSERT INTO som_jail_bail (sentence_id, citizenid, amount, status, appeal_due_at)
        VALUES (?, ?, ?, 'posted', DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], { sentence.id, player.citizenid, amount, Config.Bail.appealHours })

    Jail.Release(sentence, 'bailed', nil)

    return { success = true, amount = amount }
end)

-- ---------------------------------------------------------------------------
-- The appeal-window sweep
-- ---------------------------------------------------------------------------

--- No money moves here. Bail was already spent at payment time; a window
--- passing with no re-arrest just tidies the row for queries, the same way
--- jail.lua's own sweep tidies served sentences.
local function sweep()
    MySQL.update.await(
        "UPDATE som_jail_bail SET status = 'cleared' WHERE status = 'posted' AND appeal_due_at <= NOW()")
end

CreateThread(function()
    Wait(6000)

    while true do
        Wait(60000)
        pcall(sweep)
    end
end)
