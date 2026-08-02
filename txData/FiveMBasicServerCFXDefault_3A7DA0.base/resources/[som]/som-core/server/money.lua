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

    local ok, err = pcall(function()
        MySQL.transaction.await({
            {
                query = ('UPDATE som_character_money SET `%s` = ? WHERE citizenid = ?'):format(account),
                values = { balance, player.citizenid },
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
    end)

    if not ok then
        -- Roll the in-memory balance back so state and database stay agreed.
        player.money[account] = balance - delta
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
        'SELECT b.id, b.account_id, a.balance FROM som_businesses b '
        .. 'LEFT JOIN som_bank_accounts a ON a.id = b.account_id WHERE b.name = ?',
        { businessName }
    )
    if not business or not business.account_id then return false, 'business has no account' end

    local balance = business.balance + delta
    if balance < 0 then return false, 'insufficient business funds' end

    MySQL.transaction.await({
        {
            query = 'UPDATE som_bank_accounts SET balance = ? WHERE id = ?',
            values = { balance, business.account_id },
        },
        {
            query = [[
                INSERT INTO som_transactions
                    (citizenid, account, amount, balance, direction, flow, reason, resource, business_id)
                VALUES (NULL, 'bank', ?, ?, ?, ?, ?, ?, ?)
            ]],
            values = {
                math.abs(delta), balance,
                delta > 0 and 'credit' or 'debit',
                delta > 0 and 'faucet' or 'sink',
                reason, callerResource(), business.id,
            },
        },
    })

    return true
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

-- ---------------------------------------------------------------------------
-- Exports. Server side only: a client cannot invoke a server export.
-- ---------------------------------------------------------------------------

exports('addMoney', Money.Add)
exports('removeMoney', Money.Remove)
exports('getMoney', Money.Get)
exports('hasMoney', Money.Has)
exports('transferMoney', Money.Transfer)
exports('businessTransact', Money.BusinessTransact)
exports('taxToTreasury', Money.TaxToTreasury)
exports('getTreasury', Money.GetTreasury)
