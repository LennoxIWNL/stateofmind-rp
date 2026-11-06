--- Phone loans. A character borrows a listed amount over a listed number of weeks from the city
--- treasury and repays it, with a flat fee, back into the treasury. Everything that moves the owed
--- balance (an instalment, a login settle, collection, an early payoff) first claims it with one
--- conditional UPDATE, then moves the money, and puts the claim back if the money does not move.
--- A week the borrower cannot or does not pay is counted as missed, never retried every tick.
--- Forgiving a debt is the one thing that creates money, and it is a staff command that is ledgered.
--- Made by Lennox.

local core = exports['som-core']
local phone = exports['som-phone']

Loans = {}

local picks = {}
local lending = false

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function listed(list, value)
    if type(value) ~= 'number' then return nil end
    for _, v in ipairs(list) do
        if v == value then return v end
    end
end

local function tell(citizenid, text, kind)
    local player = core:getPlayerByCitizenId(citizenid)
    if player then TriggerClientEvent('som:client:notify', player.source, text, kind or 'inform') end
end

---What a loan costs, worked out on the server.
function Loans.Terms(amount, weeks)
    local fee = math.floor(amount * Config.feeRate)
    return { fee = fee, total = amount + fee, instalment = math.ceil((amount + fee) / weeks) }
end

-- ---------------------------------------------------------------------------
-- Claims
-- ---------------------------------------------------------------------------

---Takes `amount` off what is owed, only if that much is still owed and the loan is still in `prior`.
---The loan becomes 'paid' in the same statement when nothing is left.
local function take(id, amount, prior)
    local claimed = MySQL.update.await(
        "UPDATE som_loans SET status = IF(remaining = ?, 'paid', status), remaining = remaining - ? WHERE id = ? AND status = ? AND remaining >= ?",
        { amount, amount, id, prior, amount })
    return (claimed or 0) >= 1
end

---Puts a claim back: the amount owed, and any missed weeks that were cleared with it.
local function give(id, amount, prior, missed)
    MySQL.update.await(
        "UPDATE som_loans SET remaining = remaining + ?, missed_cycles = missed_cycles + ?, status = IF(status = 'paid', ?, status) WHERE id = ?",
        { amount, missed or 0, prior, id })
end

---Moves the money for a claim already made: borrower's bank to the treasury. Undoes the claim and
---any debit if it cannot finish.
local function pay(borrower, id, amount, prior, missed)
    local reason = 'loan:' .. id
    if not core:removeMoney(borrower.source, 'bank', amount, reason) then
        give(id, amount, prior, missed)
        return false
    end
    if not core:taxToTreasury(amount, reason) then
        core:addMoney(borrower.source, 'bank', amount, reason .. ':refund')
        give(id, amount, prior, missed)
        return false
    end
    return true
end

local function defaultIfDue(id)
    local defaulted = MySQL.update.await(
        "UPDATE som_loans SET status = 'defaulted' WHERE id = ? AND status = 'active' AND missed_cycles >= ?",
        { id, Config.defaultAfterMissed })
    if (defaulted or 0) < 1 then return end

    local loan = MySQL.single.await('SELECT citizenid FROM som_loans WHERE id = ?', { id })
    if loan then tell(loan.citizenid, 'Your loan is in default. What is in your bank will be taken until it is paid.', 'error') end
end

-- ---------------------------------------------------------------------------
-- Borrowing
-- ---------------------------------------------------------------------------

local function start(player, amount, weeks)
    local terms = Loans.Terms(amount, weeks)

    if core:getTreasury() - amount < Config.treasuryFloor then return done(false, 'the bank cannot lend right now') end
    if MySQL.scalar.await("SELECT 1 FROM som_loans WHERE citizenid = ? AND status IN ('active', 'defaulted')", { player.citizenid }) then
        return done(false, 'you already have a loan open')
    end

    -- The claim: one open loan per character, and the total still owed stays under the cap.
    local id = MySQL.insert.await([[
        INSERT INTO som_loans (citizenid, principal, fee, instalment, remaining, next_due)
        SELECT ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY) FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_loans WHERE citizenid = ? AND status IN ('active', 'defaulted'))
          AND (SELECT COALESCE(SUM(remaining), 0) FROM som_loans WHERE status IN ('active', 'defaulted')) + ? <= ?
    ]], { player.citizenid, amount, terms.fee, terms.instalment, terms.total, Config.intervalDays, player.citizenid, terms.total, Config.globalCap })
    if not id or id < 1 then return done(false, 'the bank is not lending more right now') end

    local function cancel() MySQL.update.await("UPDATE som_loans SET status = 'cancelled', remaining = 0 WHERE id = ? AND status = 'active'", { id }) end

    if not core:treasuryTransact(-amount, 'loan:' .. id) then cancel(); return done(false, 'the bank cannot lend right now') end
    if not core:addMoney(player.source, 'bank', amount, 'loan:' .. id) then
        core:treasuryTransact(amount, 'loan:' .. id .. ':refund')
        cancel()
        return done(false, 'the loan fell through')
    end
    return done(true, nil, { id = id })
end

-- ---------------------------------------------------------------------------
-- Weeks, collection and login
-- ---------------------------------------------------------------------------

---One week of an active loan. The claim moves next_due on and takes the instalment off what is owed;
---if the borrower is away or cannot pay, the owed balance goes back and the week is counted as missed.
function Loans.Collect(loan)
    local borrower = core:getPlayerByCitizenId(loan.citizenid)
    local amount = math.min(loan.instalment, loan.remaining)

    if not borrower then
        local missed = MySQL.update.await(
            "UPDATE som_loans SET next_due = DATE_ADD(next_due, INTERVAL ? DAY), missed_cycles = missed_cycles + 1 WHERE id = ? AND status = 'active' AND UNIX_TIMESTAMP(next_due) = ?",
            { Config.intervalDays, loan.id, loan.due })
        if (missed or 0) >= 1 then defaultIfDue(loan.id) end
        return
    end

    local claimed = MySQL.update.await([[
        UPDATE som_loans SET next_due = DATE_ADD(next_due, INTERVAL ? DAY), status = IF(remaining = ?, 'paid', status), remaining = remaining - ?
        WHERE id = ? AND status = 'active' AND UNIX_TIMESTAMP(next_due) = ? AND remaining >= ?
    ]], { Config.intervalDays, amount, amount, loan.id, loan.due, amount })
    if (claimed or 0) < 1 then return end

    if not pay(borrower, loan.id, amount, 'active') then
        MySQL.update.await("UPDATE som_loans SET missed_cycles = missed_cycles + 1 WHERE id = ? AND status = 'active'", { loan.id })
        TriggerClientEvent('som:client:notify', borrower.source, 'You could not pay your loan this week', 'error')
        defaultIfDue(loan.id)
    end
end

---A loan in default: takes what is in the bank, never more than is owed or than is there.
function Loans.Collection(loan)
    local borrower = core:getPlayerByCitizenId(loan.citizenid)
    if not borrower then return end

    local amount = math.min(loan.remaining, math.floor(tonumber(core:getMoney(borrower.source, 'bank')) or 0))
    if amount < 1 or not take(loan.id, amount, 'defaulted') then return end

    if pay(borrower, loan.id, amount, 'defaulted') then
        TriggerClientEvent('som:client:notify', borrower.source, ('$%d was taken towards your loan'):format(amount), 'error')
    end
end

---Pays what a returning borrower missed. The missed count is cleared with the same claim that takes
---the money off what is owed, and both go back if the payment fails.
function Loans.Settle(citizenid)
    local borrower = type(citizenid) == 'string' and core:getPlayerByCitizenId(citizenid)
    if not borrower then return end

    local owed = MySQL.query.await(
        "SELECT id, instalment, remaining, missed_cycles FROM som_loans WHERE citizenid = ? AND status = 'active' AND missed_cycles > 0",
        { citizenid }) or {}

    for _, loan in ipairs(owed) do
        local amount = math.min(loan.remaining, loan.instalment * loan.missed_cycles)
        local claimed = MySQL.update.await([[
            UPDATE som_loans SET status = IF(remaining = ?, 'paid', status), remaining = remaining - ?, missed_cycles = 0
            WHERE id = ? AND status = 'active' AND missed_cycles = ? AND remaining >= ?
        ]], { amount, amount, loan.id, loan.missed_cycles, amount })

        if (claimed or 0) >= 1 then pay(borrower, loan.id, amount, 'active', loan.missed_cycles) end
    end
end

function Loans.Sweep()
    local due = MySQL.query.await([[
        SELECT id, citizenid, instalment, remaining, UNIX_TIMESTAMP(next_due) AS due
        FROM som_loans WHERE status = 'active' AND next_due <= NOW()
    ]]) or {}

    for _, loan in ipairs(due) do
        local ok, err = pcall(Loans.Collect, loan)
        if not ok then print(('[som-loans] loan %s failed: %s'):format(tostring(loan.id), tostring(err))) end
    end

    for _, loan in ipairs(MySQL.query.await("SELECT id, citizenid, remaining FROM som_loans WHERE status = 'defaulted'") or {}) do
        local ok, err = pcall(Loans.Collection, loan)
        if not ok then print(('[som-loans] collection %s failed: %s'):format(tostring(loan.id), tostring(err))) end
    end
end

CreateThread(function()
    Wait(5000)

    if not pcall(MySQL.scalar.await, 'SELECT 1 FROM som_loans LIMIT 1') then
        print('[som-loans] som_loans is missing. Import setup.sql.')
        return
    end

    while true do
        Wait(Config.sweepMinutes * 60000)
        local ok, err = pcall(Loans.Sweep)
        if not ok then print(('[som-loans] sweep failed: %s'):format(tostring(err))) end
    end
end)

AddEventHandler('som:server:playerLoaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    SetTimeout(10000, function() pcall(Loans.Settle, citizenid) end)
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then picks[citizenid] = nil end
end)

-- ---------------------------------------------------------------------------
-- Phone
-- ---------------------------------------------------------------------------

local function openLoan(citizenid)
    return MySQL.single.await([[
        SELECT id, remaining, instalment, missed_cycles, status, GREATEST(0, UNIX_TIMESTAMP(next_due) - UNIX_TIMESTAMP(NOW())) AS secs
        FROM som_loans WHERE citizenid = ? AND status IN ('active', 'defaulted') LIMIT 1
    ]], { citizenid })
end

local actions = {}

function actions.view(_, _, player)
    local loan = openLoan(player.citizenid)

    if loan then
        local rows = {
            { title = ('You owe $%d'):format(loan.remaining) },
        }
        if loan.status == 'defaulted' then
            rows[2] = { title = 'In collection', sub = 'What is in your bank is taken until this is paid' }
        else
            rows[2] = { title = ('$%d due in %d days'):format(math.min(loan.instalment, loan.remaining), math.ceil(loan.secs / 86400)), sub = loan.missed_cycles > 0 and ('%d missed'):format(loan.missed_cycles) or nil }
        end
        rows[3] = { title = ('Pay off $%d now'):format(loan.remaining), sub = 'Tap to pay the rest', action = 'payoff' }
        return done(true, nil, { view = { sections = { { title = 'Your loan', rows = rows } }, empty = '' } })
    end

    local sections = {}
    local amounts = {}
    for _, amount in ipairs(Config.amounts) do
        amounts[#amounts + 1] = { title = ('$%d'):format(amount), sub = 'Tap to choose', action = 'pick', payload = { amount = amount } }
    end
    sections[1] = { title = 'Borrow', rows = amounts }

    local picked = picks[player.citizenid]
    if picked then
        local terms = {}
        for _, weeks in ipairs(Config.weeks) do
            local t = Loans.Terms(picked, weeks)
            terms[#terms + 1] = { title = ('%d weeks'):format(weeks), sub = ('$%d a week, $%d fee, $%d in all'):format(t.instalment, t.fee, t.total), action = 'borrow', payload = { weeks = weeks } }
        end
        sections[2] = { title = ('Terms for $%d'):format(picked), rows = terms }
    end

    return done(true, nil, { view = { sections = sections, empty = '' } })
end

function actions.pick(source, payload, player)
    local amount = listed(Config.amounts, payload.amount)
    if not amount then return done(false, 'bad request') end

    picks[player.citizenid] = amount
    TriggerClientEvent('som-phone:client:refresh', source)
    return done(true)
end

function actions.borrow(source, payload, player)
    local weeks = listed(Config.weeks, payload.weeks)
    local amount = picks[player.citizenid]
    if not weeks or not amount then return done(false, 'bad request') end
    if lending then return done(false, 'try again in a moment') end

    -- One loan is made at a time, so the treasury floor, the cap and the debit are decided together.
    lending = true
    local ok, result = pcall(start, player, amount, weeks)
    lending = false

    if not ok then
        print(('[som-loans] borrowing failed: %s'):format(tostring(result)))
        return done(false, 'the loan fell through')
    end

    if result.success then picks[player.citizenid] = nil end
    TriggerClientEvent('som-phone:client:refresh', source)
    return result
end

function actions.payoff(source, _, player)
    local loan = openLoan(player.citizenid)
    if not loan then return done(false, 'you have no loan') end

    if not take(loan.id, loan.remaining, loan.status) then return done(false, 'try again in a moment') end
    if not pay(player, loan.id, loan.remaining, loan.status) then return done(false, 'not enough in your bank') end

    TriggerClientEvent('som-phone:client:refresh', source)
    return done(true)
end

phone:registerApp({
    id = 'loans', label = 'Bank loans', icon = 'receipt', colour = '#5e5ce6', order = 68,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

-- ---------------------------------------------------------------------------
-- Staff
-- ---------------------------------------------------------------------------

---Writes a debt off. This is the only place a loan creates money: the treasury already paid the
---amount out and will not get it back, so the write-off is ledgered as a faucet.
lib.addCommand('forgiveloan', {
    help = 'Forgive an open loan (staff)',
    params = { { name = 'id', type = 'number', help = 'Loan id' } },
}, function(source, args)
    local function say(text) if source == 0 then print('[som-loans] ' .. text) else TriggerClientEvent('som:client:notify', source, text, 'inform') end end

    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return say('no permission') end

    local id = type(args.id) == 'number' and args.id % 1 == 0 and args.id or nil
    if not id then return say('give a loan id') end

    local loan = MySQL.single.await("SELECT citizenid, remaining, status FROM som_loans WHERE id = ? AND status IN ('active', 'defaulted')", { id })
    if not loan then return say('no open loan with that id') end

    local claimed = MySQL.update.await("UPDATE som_loans SET status = 'forgiven', remaining = 0 WHERE id = ? AND status IN ('active', 'defaulted') AND remaining = ?", { id, loan.remaining })
    if (claimed or 0) < 1 then return say('that loan changed, try again') end

    local ok, row = pcall(MySQL.insert.await, [[
        INSERT INTO som_transactions (citizenid, account, amount, balance, direction, flow, reason, resource)
        SELECT ?, 'bank', ?, COALESCE((SELECT bank FROM som_character_money WHERE citizenid = ?), 0), 'credit', 'faucet', 'loan:forgiven', 'som-loans' FROM DUAL
    ]], { loan.citizenid, loan.remaining, loan.citizenid })
    if not ok or not row or row < 1 then
        MySQL.update.await("UPDATE som_loans SET status = ?, remaining = ? WHERE id = ? AND status = 'forgiven'", { loan.status, loan.remaining, id })
        return say('could not write the ledger row, nothing was forgiven')
    end

    tell(loan.citizenid, 'Your loan was written off.', 'success')
    say(('forgave $%d'):format(loan.remaining))
end)
