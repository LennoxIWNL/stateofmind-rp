--- Bail: a quote, then a commit, the same shape som-housing's mortgage flow
--- uses. The client never sends an amount or an account.

local core = exports['som-core']

Bail = {}

---@param citizenid string
---@return table|nil sentence, number|nil remaining
local function activeWithRemaining(citizenid)
    local sentence = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(SECOND, booked_at, NOW()) AS elapsed
        FROM som_jail_sentences WHERE citizenid = ? AND status = 'serving'
    ]], { citizenid })

    if not sentence then return nil, nil end

    return sentence, math.max(0, sentence.total_seconds - (tonumber(sentence.elapsed) or 0))
end

---@param citizenid string
---@return boolean eligible, number|string amountOrError, table|nil sentence
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

    return true, math.max(Config.Bail.minAmount, remaining * Config.Bail.rateMultiplier), sentence
end

lib.callback.register('som-jail:server:bailQuote', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local eligible, amountOrError = quote(player.citizenid)
    if not eligible then return { success = false, error = amountOrError } end

    return { success = true, amount = amountOrError }
end)

lib.callback.register('som-jail:server:requestBail', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local eligible, amount, sentence = quote(player.citizenid)
    if not eligible then return { success = false, error = amount } end

    -- Claim before charging so a concurrent sweep or second request cannot
    -- release or charge the same sentence twice.
    if not Jail.Claim(sentence, 'bailed', nil) then
        return { success = false, error = 'not currently serving a sentence' }
    end

    local reason = ('bail:%d'):format(sentence.id)
    local paid, payErr = core:payWith(source, 'bank', amount, reason)

    if not paid then
        Jail.Unclaim(sentence)
        return { success = false, error = payErr or 'could not pay' }
    end

    core:businessTransact(Config.Business, amount, reason)

    MySQL.insert.await([[
        INSERT INTO som_jail_bail (sentence_id, citizenid, amount, status, appeal_due_at)
        VALUES (?, ?, ?, 'posted', DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], { sentence.id, player.citizenid, amount, Config.Bail.appealHours })

    Jail.Free(sentence)

    return { success = true, amount = amount }
end)

--- Tidies rows whose window passed with no re-arrest. No money moves.
function Bail.Sweep()
    MySQL.update.await(
        "UPDATE som_jail_bail SET status = 'cleared' WHERE status = 'posted' AND appeal_due_at <= NOW()")
end

CreateThread(function()
    Wait(6000)

    while true do
        Wait(60000)
        pcall(Bail.Sweep)
    end
end)
