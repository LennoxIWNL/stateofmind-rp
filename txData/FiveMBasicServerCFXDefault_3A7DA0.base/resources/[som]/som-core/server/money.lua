-- The money transaction bus.
--
-- This is the ONLY code in the framework that changes a balance. Every job,
-- shop, heist, and admin command routes through Money.Transact, which means:
--   1. every movement is validated the same way
--   2. every movement lands in som_transactions with its calling resource
--   3. Phase 4 sink/faucet analysis is a SQL query, not an estimate
--
-- There is deliberately NO net event here. Clients cannot reach this file.
-- A client-facing resource must expose its own validated action which then
-- calls these exports server side.

Money = {}

local validAccount = {}
for _, name in ipairs(Config.Money.accounts) do
    validAccount[name] = true
end

---Normalises whatever a caller passed as a player reference.
---@param ref number|string source or citizenid
---@return table|nil
local function resolve(ref)
    if type(ref) == 'number' then return Players.Get(ref) end
    if type(ref) == 'string' then return Players.GetByCitizenId(ref) end
    return nil
end

---Amounts must be positive whole numbers. Rejects NaN, inf, negatives,
---fractions, and strings that merely look numeric.
---@param amount any
---@return number|nil
local function sanitiseAmount(amount)
    local num = tonumber(amount)
    if not num then return nil end
    if num ~= num then return nil end            -- NaN
    if num == math.huge or num == -math.huge then return nil end
    if num <= 0 then return nil end
    if num % 1 ~= 0 then return nil end
    if num > 1e12 then return nil end            -- absurd value guard
    return num
end

---@return string name of the resource that called into the bus
local function callerResource()
    return GetInvokingResource() or 'som-core'
end

-- Cash is deliberately NOT an inventory item. It is a balance som-core owns
-- outright, like bank and crypto. Making it an item would mean ox_inventory
-- held the authoritative count, splitting ownership of the economy across two
-- systems and creating drift that is indistinguishable from a dupe.
--
-- Cash is still stealable, but through a validated server action rather than
-- by dragging a stack out of somebody's bag. See som-theft.

---The single auditable mutation. Not exported: callers use Add/Remove/Transfer.
---@param player table
---@param account string
---@param delta number signed
---@param reason string
---@param opts table|nil { counterparty, businessId, resource, flow }
---@return boolean success, string|nil err
local function transact(player, account, delta, reason, opts)
    opts = opts or {}

    local balance = player.money[account] + delta
    if balance < 0 then return false, 'insufficient funds' end

    player.money[account] = balance

    local direction = delta > 0 and 'credit' or 'debit'
    local flow = opts.flow
    if not flow then
        -- No counterparty means the money came from or went to nowhere, which
        -- is exactly what a faucet and a sink are.
        flow = opts.counterparty and 'transfer' or (delta > 0 and 'faucet' or 'sink')
    end

    -- The balance is written as a change (`col + delta`), never as the result. Two
    -- changes in flight can reach the database in either order; adding both always
    -- lands on the same total, while writing "the balance I computed" would let the
    -- older one win and bring money back.
    local ok, err = pcall(function()
        local done = MySQL.transaction.await({
            {
                query = ('UPDATE som_character_money SET `%s` = `%s` + ? WHERE citizenid = ?'):format(account, account),
                values = { delta, player.citizenid },
            },
            {
                query = [[
                    INSERT INTO som_transactions
                        (citizenid, account, amount, balance, direction, flow, reason, resource, counterparty, business_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]],
                values = {
                    player.citizenid, account, math.abs(delta), balance,
                    direction, flow, reason, opts.resource or callerResource(),
                    opts.counterparty, opts.businessId,
                },
            },
        })
        if not done then error('transaction failed') end
    end)

    if not ok then
        -- Roll the in-memory balance back so state and database stay agreed.
        -- Undo only this change: another one may have landed in memory while this save was waiting.
        player.money[account] = player.money[account] - delta
        print(('[som-core] transaction failed for %s: %s'):format(player.citizenid, err))
        return false, 'database error'
    end

    TriggerClientEvent('som:client:setMoney', player.source, player.money)
    TriggerEvent('som:server:moneyChanged', player.source, player.citizenid, account, delta, balance, reason)

    return true
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---@param ref number|string source or citizenid
---@param account string
---@param amount number positive
---@param reason string
---@param opts table|nil
---@return boolean success, string|nil err
function Money.Add(ref, account, amount, reason, opts)
    local player = resolve(ref)
    if not player then return false, 'player not found' end
    if not validAccount[account] then return false, 'invalid account' end
    if Config.Money.protected[account] and not (opts and opts.allowProtected) then
        return false, 'protected account'
    end

    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end
    if type(reason) ~= 'string' or reason == '' then return false, 'reason required' end

    opts = opts or {}
    opts.resource = opts.resource or callerResource()
    return transact(player, account, value, reason, opts)
end

---@return boolean success, string|nil err
function Money.Remove(ref, account, amount, reason, opts)
    local player = resolve(ref)
    if not player then return false, 'player not found' end
    if not validAccount[account] then return false, 'invalid account' end
    if Config.Money.protected[account] and not (opts and opts.allowProtected) then
        return false, 'protected account'
    end

    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end
    if type(reason) ~= 'string' or reason == '' then return false, 'reason required' end
    if player.money[account] < value then return false, 'insufficient funds' end

    opts = opts or {}
    opts.resource = opts.resource or callerResource()
    return transact(player, account, -value, reason, opts)
end

---@param ref number|string
---@param account string|nil defaults to every account
---@return number|table
function Money.Get(ref, account)
    local player = resolve(ref)
    if not player then return 0 end
    if account then return player.money[account] or 0 end
    return player.money
end

---Player to player. Both legs are written, so the ledger reconciles to zero.
---@return boolean success, string|nil err
function Money.Transfer(fromRef, toRef, account, amount, reason)
    local from = resolve(fromRef)
    local to = resolve(toRef)
    if not from or not to then return false, 'player not found' end
    if from.citizenid == to.citizenid then return false, 'cannot transfer to self' end
    if not validAccount[account] then return false, 'invalid account' end
    if Config.Money.protected[account] then return false, 'protected account' end

    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end
    if from.money[account] < value then return false, 'insufficient funds' end

    local resource = callerResource()

    local ok = transact(from, account, -value, reason, {
        counterparty = to.citizenid, flow = 'transfer', resource = resource,
    })
    if not ok then return false, 'debit failed' end

    local credited = transact(to, account, value, reason, {
        counterparty = from.citizenid, flow = 'transfer', resource = resource,
    })
    if not credited then
        -- Put it back. The reversal is itself ledgered, so the failure is visible.
        transact(from, account, value, 'transfer-reversal', {
            counterparty = to.citizenid, flow = 'transfer', resource = resource,
        })
        return false, 'credit failed, reversed'
    end

    return true
end

---Credits a character who is not online, writing balance and ledger together.
---
---Offline characters have no in-memory money table, so transact() cannot serve
---them. The database is the only state that exists for them, which makes this
---the one place a balance is written without a loaded player.
---@param citizenid string
---@param account string
---@param value number positive, already sanitised
---@param reason string
---@param opts table|nil
---@return boolean success, string|nil err
local function creditOffline(citizenid, account, value, reason, opts)
    opts = opts or {}

    if not MySQL.scalar.await('SELECT 1 FROM som_character_money WHERE citizenid = ?', { citizenid }) then
        return false, 'no such character'
    end

    -- Added in the database, not read then written back: two credits to the same
    -- offline character (or one landing as they log in) must both count.
    local ok, err = pcall(function()
        local done = MySQL.transaction.await({
            {
                query = ('UPDATE som_character_money SET `%s` = `%s` + ? WHERE citizenid = ?'):format(account, account),
                values = { value, citizenid },
            },
            {
                query = ([[
                    INSERT INTO som_transactions
                        (citizenid, account, amount, balance, direction, flow, reason, resource, counterparty, business_id)
                    SELECT m.citizenid, ?, ?, m.`%s`, 'credit', ?, ?, ?, ?, ?
                    FROM som_character_money m WHERE m.citizenid = ?
                ]]):format(account),
                values = {
                    account, value, opts.flow or 'transfer', reason,
                    opts.resource or callerResource(), opts.counterparty, opts.businessId, citizenid,
                },
            },
        })
        if not done then error('transaction failed') end
    end)

    if not ok then
        print(('[som-core] offline credit failed for %s: %s'):format(citizenid, err))
        return false, 'database error'
    end

    return true
end

---Transfers to a character by citizenid, online or not.
---
---Money.Transfer needs both sides loaded. Being paid should not depend on the
---recipient happening to be in the city, so this falls through to a direct
---database credit when they are away.
---@param fromRef number|string sender
---@param toCitizenId string
---@param account string
---@param amount number
---@param reason string
---@return boolean success, string|nil err
function Money.TransferToCitizen(fromRef, toCitizenId, account, amount, reason)
    if type(toCitizenId) ~= 'string' then return false, 'invalid recipient' end

    local online = Players.GetByCitizenId(toCitizenId)
    if online then
        return Money.Transfer(fromRef, online.source, account, amount, reason)
    end

    local from = resolve(fromRef)
    if not from then return false, 'player not found' end
    if from.citizenid == toCitizenId then return false, 'cannot transfer to self' end
    if not validAccount[account] then return false, 'invalid account' end
    if Config.Money.protected[account] then return false, 'protected account' end

    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end
    if from.money[account] < value then return false, 'insufficient funds' end

    local resource = callerResource()

    local ok = transact(from, account, -value, reason, {
        counterparty = toCitizenId, flow = 'transfer', resource = resource,
    })
    if not ok then return false, 'debit failed' end

    local credited, err = creditOffline(toCitizenId, account, value, reason, {
        counterparty = from.citizenid, resource = resource,
    })

    if not credited then
        -- Put it back. The reversal is itself ledgered, so the failure is visible.
        transact(from, account, value, 'transfer-reversal', {
            counterparty = toCitizenId, flow = 'transfer', resource = resource,
        })
        return false, err or 'credit failed, reversed'
    end

    return true
end

local payable = {}
for _, name in ipairs(Config.Money.payable or {}) do payable[name] = true end

---Charges a player for a purchase, from an account THEY chose.
---
---Every shop offers cash or card, so the validation lives here rather than
---being re-implemented, slightly differently, in each one. The account arrives
---from the client because the player picked it in a menu, which makes it
---exactly the kind of value that must be checked rather than trusted: without
---this, a shop could be paid in `dirty` and laundering would be pointless.
---@param source number
---@param account string as chosen by the player
---@param amount number
---@param reason string
---@return boolean success, string|nil err
function Money.PayWith(source, account, amount, reason)
    if type(account) ~= 'string' or not payable[account] then
        return false, 'that is not a way to pay'
    end

    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end

    local player = resolve(source)
    if not player then return false, 'player not found' end

    if (player.money[account] or 0) < value then
        return false, ('not enough %s'):format(Config.Money.payableLabels[account] or account)
    end

    local ok, err = Money.Remove(source, account, value, reason, {
        resource = callerResource(),
    })

    return ok, err
end

---What a player can pay with, and how much of each they have. Shops show this
---so the choice is informed rather than a guess.
---@param source number
---@return table[] { { account, label, balance } }
function Money.PaymentOptions(source)
    local player = resolve(source)
    if not player then return {} end

    local options = {}
    for _, account in ipairs(Config.Money.payable or {}) do
        options[#options + 1] = {
            account = account,
            label = Config.Money.payableLabels[account] or account,
            balance = player.money[account] or 0,
        }
    end

    return options
end

---Takes cash from one player and gives it to another.
---
---This is how cash gets robbed. Cash is not an item, so it cannot be dragged
---out of somebody's bag: a thief performs a validated action instead, and the
---server decides whether it is allowed and how much moves.
---
---Callers MUST have already checked proximity and that the victim is in a
---state that permits it. som-theft does both. This function only guarantees
---the money maths and the audit trail.
---@param fromRef number|string victim
---@param toRef number|string thief
---@param amount number|nil defaults to the victim's whole cash balance
---@return boolean success, number|string stolen amount, or an error
function Money.StealCash(fromRef, toRef, amount)
    local victim = resolve(fromRef)
    local thief = resolve(toRef)
    if not victim or not thief then return false, 'player not found' end
    if victim.citizenid == thief.citizenid then return false, 'cannot rob yourself' end

    local available = victim.money.cash
    if available <= 0 then return false, 'victim has no cash' end

    local value = amount and sanitiseAmount(amount) or available
    if not value then return false, 'invalid amount' end
    if value > available then value = available end

    local resource = callerResource()

    local ok = transact(victim, 'cash', -value, 'robbed', {
        counterparty = thief.citizenid, flow = 'transfer', resource = resource,
    })
    if not ok then return false, 'debit failed' end

    local credited = transact(thief, 'cash', value, 'robbery-proceeds', {
        counterparty = victim.citizenid, flow = 'transfer', resource = resource,
    })
    if not credited then
        transact(victim, 'cash', value, 'robbery-reversal', {
            counterparty = thief.citizenid, flow = 'transfer', resource = resource,
        })
        return false, 'credit failed, reversed'
    end

    return true, value
end

---@param ref number|string
---@param account string
---@param amount number
---@return boolean
function Money.Has(ref, account, amount)
    local player = resolve(ref)
    if not player then return false end
    local value = sanitiseAmount(amount)
    if not value then return false end
    return (player.money[account] or 0) >= value
end

-- ---------------------------------------------------------------------------
-- Business and treasury accounts
--
-- Payroll debits a business account rather than minting money, which is what
-- makes the Phase 4 sink/faucet ratio measurable in the first place.
-- ---------------------------------------------------------------------------

---@param businessName string
---@param amount number signed
---@param reason string
---@return boolean success, string|nil err
function Money.BusinessTransact(businessName, amount, reason)
    if type(businessName) ~= 'string' then return false, 'invalid business' end

    local delta = tonumber(amount)
    if not delta or delta % 1 ~= 0 or delta == 0 then return false, 'invalid amount' end
    if type(reason) ~= 'string' or reason == '' then return false, 'reason required' end

    local business = MySQL.single.await(
        'SELECT b.id, b.account_id FROM som_businesses b WHERE b.name = ?',
        { businessName }
    )
    if not business or not business.account_id then return false, 'business has no account' end

    -- One conditional add: two payments cannot both pass a balance check, and an older
    -- write cannot overwrite a newer one.
    local changed = MySQL.update.await(
        'UPDATE som_bank_accounts SET balance = balance + ? WHERE id = ? AND frozen = 0 AND balance + ? >= 0',
        { delta, business.account_id, delta })
    if (changed or 0) < 1 then
        local frozen = MySQL.scalar.await('SELECT frozen FROM som_bank_accounts WHERE id = ?', { business.account_id })
        return false, frozen == 1 and 'account frozen' or 'insufficient business funds'
    end

    local balance = MySQL.scalar.await('SELECT balance FROM som_bank_accounts WHERE id = ?', { business.account_id }) or 0
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO som_transactions
            (citizenid, account, amount, balance, direction, flow, reason, resource, business_id)
        VALUES (NULL, 'bank', ?, ?, ?, ?, ?, ?, ?)
    ]], {
        math.abs(delta), balance,
        delta > 0 and 'credit' or 'debit',
        delta > 0 and 'faucet' or 'sink',
        reason, callerResource(), business.id,
    })
    if not ok or not id or id < 1 then
        -- No ledger row means no money moved: put the balance back.
        MySQL.update.await('UPDATE som_bank_accounts SET balance = balance - ? WHERE id = ?', { delta, business.account_id })
        print(('[som-core] business ledger write failed for %s: %s'):format(businessName, tostring(id)))
        return false, 'database error'
    end

    return true
end

---Signed movement on a gang's bank account, created on first use. The balance
---is changed with one conditional UPDATE so two payments cannot both pass a
---balance check, and the ledger row carries the gang as counterparty.
---@param gangName string
---@param amount number signed, negative to pay out
---@param reason string
---@return boolean success, string|nil err
function Money.GangTransact(gangName, amount, reason)
    if type(gangName) ~= 'string' or gangName == 'none' or not Gangs[gangName] then return false, 'invalid gang' end

    local delta = tonumber(amount)
    if not delta or delta % 1 ~= 0 or delta == 0 or math.abs(delta) > 1e12 then return false, 'invalid amount' end
    if type(reason) ~= 'string' or reason == '' then return false, 'reason required' end

    local row = MySQL.single.await('SELECT account_id FROM som_gangs WHERE name = ?', { gangName })
    if not row then return false, 'gang not set up' end

    local accountId = row.account_id
    if not accountId then
        MySQL.update.await(
            "INSERT IGNORE INTO som_bank_accounts (account_no, label, type, owner) VALUES (?, ?, 'gang', ?)",
            { 'GANG-' .. gangName:upper(), Gangs[gangName].label, gangName })
        accountId = MySQL.scalar.await('SELECT id FROM som_bank_accounts WHERE account_no = ?', { 'GANG-' .. gangName:upper() })
        if not accountId then return false, 'no account' end
        MySQL.update.await('UPDATE som_gangs SET account_id = ? WHERE name = ? AND account_id IS NULL', { accountId, gangName })
    end

    local changed = MySQL.update.await(
        'UPDATE som_bank_accounts SET balance = balance + ? WHERE id = ? AND frozen = 0 AND balance + ? >= 0',
        { delta, accountId, delta })
    if (changed or 0) < 1 then return false, 'insufficient gang funds' end

    local balance = MySQL.scalar.await('SELECT balance FROM som_bank_accounts WHERE id = ?', { accountId }) or 0
    MySQL.insert.await([[
        INSERT INTO som_transactions
            (citizenid, account, amount, balance, direction, flow, reason, resource, counterparty)
        VALUES (NULL, 'bank', ?, ?, ?, 'transfer', ?, ?, ?)
    ]], { math.abs(delta), balance, delta > 0 and 'credit' or 'debit', reason, callerResource(), gangName })

    return true
end

---@param gangName string
---@return number
function Money.GetGangBalance(gangName)
    if type(gangName) ~= 'string' then return 0 end
    return MySQL.scalar.await(
        'SELECT a.balance FROM som_gangs g JOIN som_bank_accounts a ON a.id = g.account_id WHERE g.name = ?',
        { gangName }) or 0
end

---Moves tax into the state treasury. Phase 4 exposes this in a UI.
---@param amount number positive
---@param reason string
---@return boolean
function Money.TaxToTreasury(amount, reason)
    local value = sanitiseAmount(amount)
    if not value then return false, 'invalid amount' end

    MySQL.update.await('UPDATE som_treasury SET balance = balance + ? WHERE id = 1', { value })
    MySQL.insert.await([[
        INSERT INTO som_transactions
            (citizenid, account, amount, balance, direction, flow, reason, resource)
        VALUES (NULL, 'bank', ?, (SELECT balance FROM som_treasury WHERE id = 1), 'credit', 'sink', ?, ?)
    ]], { value, reason or 'tax', callerResource() })

    return true
end

---@return number
function Money.GetTreasury()
    return MySQL.scalar.await('SELECT balance FROM som_treasury WHERE id = 1') or 0
end

---Signed treasury movement, for spending as well as collecting.
---
---TaxToTreasury only accepts positive amounts, so paying a city budget out
---needs its own path rather than a negative tax, which would silently fail.
---@param delta number signed, negative to spend
---@param reason string
---@return boolean success, string|nil err
function Money.TreasuryTransact(delta, reason)
    local value = tonumber(delta)
    if not value or value ~= value or value % 1 ~= 0 or value == 0 then
        return false, 'invalid amount'
    end

    local changed = MySQL.update.await(
        'UPDATE som_treasury SET balance = balance + ? WHERE id = 1 AND balance + ? >= 0',
        { value, value })
    if (changed or 0) < 1 then return false, 'insufficient treasury funds' end

    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO som_transactions
            (citizenid, account, amount, balance, direction, flow, reason, resource)
        VALUES (NULL, 'bank', ?, (SELECT balance FROM som_treasury WHERE id = 1), ?, ?, ?, ?)
    ]], {
        math.abs(value),
        value > 0 and 'credit' or 'debit',
        value > 0 and 'sink' or 'faucet',
        reason or 'treasury', callerResource(),
    })
    if not ok or not id or id < 1 then
        -- No ledger row means no money moved: put the balance back.
        MySQL.update.await('UPDATE som_treasury SET balance = balance - ? WHERE id = 1', { value })
        print(('[som-core] treasury ledger write failed: %s'):format(tostring(id)))
        return false, 'database error'
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Exports. Server side only: a client cannot invoke a server export.
-- ---------------------------------------------------------------------------

exports('addMoney', Money.Add)
exports('removeMoney', Money.Remove)
exports('getMoney', Money.Get)
exports('stealCash', Money.StealCash)
exports('hasMoney', Money.Has)
exports('transferMoney', Money.Transfer)
exports('transferToCitizen', Money.TransferToCitizen)
exports('payWith', Money.PayWith)
exports('paymentOptions', Money.PaymentOptions)
exports('businessTransact', Money.BusinessTransact)
exports('gangTransact', Money.GangTransact)
exports('getGangBalance', Money.GetGangBalance)
exports('taxToTreasury', Money.TaxToTreasury)
exports('getTreasury', Money.GetTreasury)
exports('treasuryTransact', Money.TreasuryTransact)
