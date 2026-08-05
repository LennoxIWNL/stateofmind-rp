-- Bank app backend.
--
-- Reads som_transactions and som_bank_accounts directly. That is the reason
-- this phone was built rather than adopted: the flagship app is a view over
-- tables the framework already owns, and any third-party phone would have
-- inserted its own account model in between.
--
-- Every amount here moves through som-core's transaction bus. Nothing in this
-- file writes a balance.

Bank = {}

-- ---------------------------------------------------------------------------
-- Statement labels
--
-- som_transactions.reason is a machine readable slug: it is what the sink and
-- faucet analysis groups by, and what an investigation greps for. It is NOT
-- something a player should ever read. "character-creation" on a bank
-- statement breaks the fiction the rest of the phone is holding up.
--
-- Translation happens HERE rather than in the NUI, so the raw slug never
-- reaches the client at all and cannot leak through dev tools either.
--
-- A whitelist, deliberately. An unknown reason falls back to a generic label
-- rather than being prettified, because prettifying still shows the slug and
-- the whole point is that it never appears. Unknowns are logged so they can be
-- given a real label.
-- ---------------------------------------------------------------------------

local STATEMENT_LABELS = {
    ['character-creation'] = 'Opening balance',
    ['shop-purchase']      = 'Purchase',
    ['phone-transfer']     = 'Transfer',
    ['transfer-reversal']  = 'Reversal',
    ['paycheck']           = 'Wages',
    ['salary']             = 'Wages',
    ['fine']               = 'Fine',
    ['fines']              = 'Fine',
    ['tax']                = 'Tax',
    ['treasury']           = 'City treasury',
    ['armoury-refund']     = 'Armoury refund',
    ['vehicle-refund']     = 'Vehicle refund',
    ['impound']            = 'Impound fee',
    ['impounded']          = 'Impound fee',
    ['rent']               = 'Rent',
    ['vehicle-rental']         = 'Vehicle rental',
    ['vehicle-rental-deposit'] = 'Rental deposit',
    ['vehicle-rental-refund']  = 'Deposit returned',
    ['rental-deposit']         = 'Rental deposit',
}

-- Reasons that carry an id, matched on their prefix.
--
-- The entries below duplicate several names in the exact table above ON
-- PURPOSE. An audit of what the codebase actually emits found that `fine`,
-- `paycheck`, `salary` and `commission` are ALWAYS written with an id or a job
-- appended (`fine:%d`, `paycheck:%s`), so the exact entries never matched a
-- single real transaction and every fine on the server read as "Transaction".
-- Both shapes are now covered so it does not matter which a caller uses.
local STATEMENT_PREFIXES = {
    ['bill']      = 'Bill payment',
    ['bill-auto'] = 'Automatic collection',
    ['license']   = 'Licence fee',
    ['licence']   = 'Licence fee',
    ['fine']         = 'Fine',
    ['fine-revenue'] = 'Fine revenue',
    ['fine-tax']     = 'Fine tax',
    ['paycheck']     = 'Wages',
    ['salary']       = 'Wages',
    ['appearance']   = 'Appearance',
    ['seizure']      = 'Seized',
    ['admin']        = 'Adjustment',
    ['subsidy']      = 'Department issue',
    -- som-garage and som-rentals carry the plate or model after the colon,
    -- which is exactly the kind of detail that must not reach a statement.
    ['vehicle']          = 'Vehicle purchase',
    ['vehicle-sale']     = 'Vehicle sale',
    ['vehicle-buyback']  = 'Vehicle buyback',
    ['vehicle-refund']   = 'Vehicle refund',
    ['rental']           = 'Vehicle rental',
    ['rental-deposit']   = 'Rental deposit',
    ['impound']          = 'Impound fee',
    -- Detail is a citizenid on the business leg and a business name on the
    -- employee leg. Neither belongs on a statement, so only the category shows.
    ['commission']       = 'Commission',
    ['seize']            = 'Seized',
    ['evidence']         = 'Evidence',
}

-- Prefixes whose detail after the colon is an ITEM NAME, and which therefore
-- can say what was actually bought rather than only that something was.
--
-- This is the difference between a statement reading "Transaction" and one
-- reading "Armoury: Carbine Rifle". The item name is still a slug, so it is
-- resolved through ox_inventory's own label and only shown if that lookup
-- succeeds. An unresolved item falls back to the category, never to the slug.
--
-- Deliberately a whitelist of PREFIXES, not of details. `commission:` is
-- absent because its detail is a citizenid, and `vehicle:` because its detail
-- is a spawn name; neither is something a player should read on a statement.
local ITEM_DETAIL_PREFIXES = {
    ['armoury'] = 'Armoury',
    ['subsidy'] = 'Department issue',
    ['shop']    = 'Purchase',
}

---ox_inventory's display label for an item name.
---@param name string
---@return string|nil
local function itemLabel(name)
    if type(name) ~= 'string' or name == '' then return nil end
    if GetResourceState('ox_inventory') ~= 'started' then return nil end

    local ok, items = pcall(function() return exports.ox_inventory:Items() end)
    if not ok or type(items) ~= 'table' then return nil end

    local def = items[name]
    return type(def) == 'table' and def.label or nil
end

local unknownReasons = {}

---@param reason string|nil
---@return string label safe to show a player
local function statementLabel(reason)
    if type(reason) ~= 'string' or reason == '' then return 'Transaction' end

    local exact = STATEMENT_LABELS[reason]
    if exact then return exact end

    local prefix, detail = reason:match('^([%a%-]+):(.*)$')

    if prefix then
        -- Say what was bought where the detail is safe to resolve.
        local head = ITEM_DETAIL_PREFIXES[prefix]

        if head then
            local label = itemLabel(detail)
            return label and ('%s: %s'):format(head, label) or head
        end

        if STATEMENT_PREFIXES[prefix] then return STATEMENT_PREFIXES[prefix] end
    end

    -- Logged once per PREFIX, not once per reason.
    --
    -- Keyed on the whole string, an unmapped `fine:%d` inserted a new permanent
    -- entry and printed a new console line for every fine ever issued, because
    -- the id is an auto-increment. The cache was only ever exercised by exactly
    -- the slugs whose cardinality is unbounded, which is the opposite of what
    -- it was for.
    local key = prefix or reason

    if not unknownReasons[key] then
        unknownReasons[key] = true
        print(('[som-phone] no statement label for reason "%s", showing "Transaction"')
            :format(key))
    end

    return 'Transaction'
end

-- Exposed so the card alert in server/main.lua uses the SAME whitelist as the
-- statement. Two mappings would drift, and a banner is bank UI: the rule that a
-- raw ledger slug never reaches a player applies to it exactly as it does to the
-- statement behind it. bank.lua loads first, so this is set before main.lua runs.
Bank.StatementLabel = statementLabel

---Generates a shareable account number for a character, once.
---@param player table som-core player
---@return string|nil account_no
local function ensureAccount(player)
    local existing = MySQL.single.await(
        'SELECT account_no FROM som_bank_accounts WHERE owner = ? AND type = ?',
        { player.citizenid, 'personal' })

    if existing then return existing.account_no end

    -- Digits only, no prefix. In game these are read aloud, written on
    -- yellowpages adverts and typed into the phone, and a branded prefix reads
    -- as a script artefact rather than an account number.
    --
    -- Collisions are retried rather than assumed away.
    for _ = 1, 20 do
        local candidate = ('%08d'):format(math.random(10000000, 99999999))

        local taken = MySQL.scalar.await(
            'SELECT 1 FROM som_bank_accounts WHERE account_no = ?', { candidate })

        if not taken then
            MySQL.insert.await([[
                INSERT INTO som_bank_accounts (account_no, label, type, owner, balance)
                VALUES (?, ?, 'personal', ?, 0)
            ]], {
                candidate,
                ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
                player.citizenid,
            })
            return candidate
        end
    end

    return nil
end

---@param source number
---@return table
function Bank.GetOverview(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return {} end

    local accountNo = ensureAccount(player)

    -- Own account only. A player can never query somebody else's history here:
    -- the citizenid comes from the source, never from the request.
    local history = MySQL.query.await([[
        SELECT id, account, amount, balance, direction, flow, reason, counterparty, created_at
        FROM som_transactions
        WHERE citizenid = ?
        ORDER BY id DESC
        LIMIT ?
    ]], { player.citizenid, Config.Bank.historyLimit }) or {}

    -- The raw slug is replaced, not supplemented, so it never leaves the
    -- server. See STATEMENT_LABELS.
    for i = 1, #history do
        local row = history[i]
        row.label = statementLabel(row.reason)
        row.reason = nil
    end

    local bills = MySQL.query.await([[
        SELECT id, from_name, amount, reason, created_at
        FROM som_phone_bills
        WHERE to_citizenid = ? AND status = 'pending'
        ORDER BY id DESC
    ]], { player.citizenid }) or {}

    -- Only accounts still inside the billing window are offered as chips, so
    -- the list matches what CreateBill will actually accept.
    local saved = MySQL.query.await([[
        SELECT account_no, label FROM som_phone_accounts
        WHERE citizenid = ? AND saved_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        ORDER BY label
    ]], { player.citizenid, Config.Bank.bill.sharedWindowHours }) or {}

    return {
        accountNo = accountNo,
        name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        money = player.money,
        history = history,
        bills = bills,
        saved = saved,
    }
end

---Broadcasts the player's account number to nearby players as a notification.
---@param source number
---@return boolean success, string|nil err
function Bank.ShareAccount(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    local accountNo = ensureAccount(player)
    if not accountNo then return false, 'no account' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'no ped' end
    local origin = GetEntityCoords(ped)

    local name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
    local shared = 0

    -- Distance is checked here, not on the client, because a client could
    -- otherwise broadcast its details to the entire server.
    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        if targetId and targetId ~= source then
            local targetPed = GetPlayerPed(targetId)

            if targetPed and targetPed ~= 0
                and #(origin - GetEntityCoords(targetPed)) <= Config.Bank.shareRadius then

                local receiver = exports['som-core']:getPlayer(targetId)
                if receiver then
                    MySQL.insert.await([[
                        INSERT INTO som_phone_accounts (citizenid, account_no, label)
                        VALUES (?, ?, ?)
                        ON DUPLICATE KEY UPDATE label = VALUES(label)
                    ]], { receiver.citizenid, accountNo, name })

                    TriggerClientEvent('som-phone:client:banner', targetId,
                        'Bank', ('%s shared their account: %s'):format(name, accountNo), 'bank')
                    TriggerClientEvent('som-phone:client:refresh', targetId)

                    shared = shared + 1
                end
            end
        end
    end

    if shared == 0 then return false, 'nobody nearby' end
    return true, shared
end

---Raises a bill against another player. A REQUEST, not a withdrawal.
---@param source number
---@param accountNo string
---@param amount number
---@param reason string
---@return boolean success, string|nil err
function Bank.CreateBill(source, accountNo, amount, reason)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    if type(accountNo) ~= 'string' then return false, 'invalid account' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Bank.bill.minimum or amount > Config.Bank.bill.maximum then
        return false, ('amount must be between %d and %d')
            :format(Config.Bank.bill.minimum, Config.Bank.bill.maximum)
    end

    if type(reason) ~= 'string' or #reason < 3 or #reason > 128 then
        return false, 'a reason is required'
    end

    local target = MySQL.single.await(
        'SELECT owner FROM som_bank_accounts WHERE account_no = ? AND type = ?',
        { accountNo, 'personal' })

    if not target or not target.owner then return false, 'no such account' end

    local isSelf = target.owner == player.citizenid
    if isSelf and not Config.Bank.bill.allowSelf then
        return false, 'cannot bill yourself'
    end

    -- Billing needs the number to have been shared with you, and recently.
    -- Transfers deliberately do not: sending money to a stranger is generous,
    -- demanding it from one whose number you overheard is not.
    --
    -- Self-billing skips the check because you cannot share with yourself.
    if Config.Bank.bill.requireShared and not isSelf then
        local shared = MySQL.scalar.await([[
            SELECT 1 FROM som_phone_accounts
            WHERE citizenid = ? AND account_no = ?
              AND saved_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        ]], { player.citizenid, accountNo, Config.Bank.bill.sharedWindowHours })

        if not shared then
            return false, 'they have not shared that account with you recently'
        end
    end

    -- Cap outstanding bills from one sender, so billing cannot be used as
    -- harassment by flooding somebody's phone.
    local pending = MySQL.scalar.await([[
        SELECT COUNT(*) FROM som_phone_bills
        WHERE from_citizenid = ? AND to_citizenid = ? AND status = 'pending'
    ]], { player.citizenid, target.owner }) or 0

    if pending >= Config.Bank.bill.maxPendingPerSender then
        return false, 'too many unpaid bills already sent to them'
    end

    local senderName = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)

    -- If the sender is on duty at a business, the bill is raised on its behalf
    -- and the money will land in the business account rather than their pocket.
    local jobDef = exports['som-core']:getJobs()[player.job.name]
    local business = (player.job.onduty and jobDef and jobDef.business) or nil

    local id = MySQL.insert.await([[
        INSERT INTO som_phone_bills
            (from_citizenid, to_citizenid, from_name, business, amount, reason)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { player.citizenid, target.owner, senderName, business, amount, reason })

    local targetPlayer = exports['som-core']:getPlayerByCitizenId(target.owner)
    if targetPlayer then
        TriggerClientEvent('som-phone:client:banner', targetPlayer.source,
            'Bank', ('%s sent you a bill for $%s'):format(senderName, amount), 'receipt')
        TriggerClientEvent('som-phone:client:refresh', targetPlayer.source)
    end

    return true, id
end

---Raises a bill against a citizen on behalf of a business, with automatic
---collection after a deadline.
---
---SERVER ONLY, and deliberately not reachable from a client. Bank.CreateBill
---above is the player-facing path and enforces the account-sharing rules that
---stop billing being used as harassment. This one skips all of that, because
---its caller is a department issuing a fine rather than a person asking for
---money: there is no account to have been shared, and no consent to obtain.
---
---The safety here is that only another resource can call it, and the money can
---only ever land in a business account.
---@param citizenid string who owes it
---@param business string business account the money lands in
---@param amount number
---@param reason string shown on the phone, so it must read as English
---@param opts table|nil { dueDays, issuerCitizenid, fromName }
---@return number|nil billId, string|nil error
function Bank.BillCitizen(citizenid, business, amount, reason, opts)
    if type(citizenid) ~= 'string' or #citizenid < 3 then return nil, 'bad citizen id' end
    if type(business) ~= 'string' or business == '' then return nil, 'a business is required' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return nil, 'invalid amount' end

    if type(reason) ~= 'string' or #reason < 3 or #reason > 128 then
        return nil, 'a reason is required'
    end

    opts = type(opts) == 'table' and opts or {}

    local days = tonumber(opts.dueDays)
    days = (days and days > 0) and days or nil

    -- The issuer, when there is one, so the record says who wrote the ticket.
    -- from_citizenid is NOT NULL, so it falls back to the debtor when a
    -- department raises a bill with no individual behind it. That is safe
    -- because PayBill and CollectOverdue both branch on `business` FIRST: a
    -- bill with a business set never reaches the self-billing no-op, whatever
    -- from_citizenid happens to hold.
    local issuer = type(opts.issuerCitizenid) == 'string' and opts.issuerCitizenid or citizenid
    local name = type(opts.fromName) == 'string' and opts.fromName or business

    local id

    if days then
        -- The deadline is computed by MySQL rather than in Lua, because
        -- CollectOverdue compares it against MySQL's NOW(). Building it from
        -- the server's clock would drift the moment the two disagree on
        -- timezone, and a fine that collects a day early is a support ticket.
        id = MySQL.insert.await([[
            INSERT INTO som_phone_bills
                (from_citizenid, to_citizenid, from_name, business, amount,
                 reason, auto_collect, due_at)
            VALUES (?, ?, ?, ?, ?, ?, 1, DATE_ADD(NOW(), INTERVAL ? DAY))
        ]], { issuer, citizenid, name, business, amount, reason, days })
    else
        id = MySQL.insert.await([[
            INSERT INTO som_phone_bills
                (from_citizenid, to_citizenid, from_name, business, amount, reason)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], { issuer, citizenid, name, business, amount, reason })
    end

    local target = exports['som-core']:getPlayerByCitizenId(citizenid)
    if target then
        TriggerClientEvent('som-phone:client:banner', target.source,
            'Bank', ('%s: $%s'):format(reason, amount), 'receipt')
        TriggerClientEvent('som-phone:client:refresh', target.source)
    end

    return id
end

exports('billCitizen', Bank.BillCitizen)

---Accepts a bill. This is the only path that moves the money.
---@param source number
---@param billId number
---@return boolean success, string|nil err
function Bank.PayBill(source, billId)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    local bill = MySQL.single.await(
        'SELECT * FROM som_phone_bills WHERE id = ? AND status = ?',
        { tonumber(billId) or 0, 'pending' })

    if not bill then return false, 'no such bill' end
    -- Re-derived from source, so a client cannot pay or clear someone else's.
    if bill.to_citizenid ~= player.citizenid then return false, 'not your bill' end

    if bill.business then
        -- Business billing: the payer is debited and the business credited, so
        -- an employee cannot pocket what the shop charged.
        local paid = exports['som-core']:removeMoney(source, 'bank', bill.amount,
            ('bill:%d'):format(bill.id))
        if not paid then return false, 'insufficient funds' end

        exports['som-economy']:recordBusinessRevenue(bill.business, bill.amount)

    elseif bill.from_citizenid == bill.to_citizenid then
        -- Self-billing exists so one person can exercise the whole flow. No
        -- money moves, because debiting and crediting the same account is a
        -- no-op that would only add two confusing ledger rows.
        TriggerClientEvent('som-phone:client:banner', source,
            'Bank', 'Bill settled against your own account', 'receipt')

    else
        -- Paid by citizenid, so the sender does not have to be online to be
        -- owed money. som-core credits an offline character directly.
        local ok, err = exports['som-core']:transferToCitizen(
            source, bill.from_citizenid, 'bank', bill.amount, ('bill:%d'):format(bill.id))
        if not ok then return false, err or 'transfer failed' end

        local recipient = exports['som-core']:getPlayerByCitizenId(bill.from_citizenid)
        if recipient then
            TriggerClientEvent('som-phone:client:banner', recipient.source,
                'Bank', ('Bill paid: $%s'):format(bill.amount), 'receipt')
            TriggerClientEvent('som-phone:client:refresh', recipient.source)
        end
    end

    MySQL.update.await(
        'UPDATE som_phone_bills SET status = ?, settled_at = CURRENT_TIMESTAMP WHERE id = ?',
        { 'paid', bill.id })

    return true
end

---Settles overdue bills that were raised with auto collection.
---
---This exists for police fines. A fine is not an offer, so refusing to open
---your phone cannot be a way to dodge one. Ordinary player-to-player bills
---never set auto_collect and are unaffected: they stay pending forever until
---accepted or declined.
---
---Balances may go negative here. That is intentional and is the debt, not a
---bug: som-core's transaction bus refuses to overdraw, so anything it rejects
---is left pending and retried on the next sweep.
function Bank.CollectOverdue()
    local due = MySQL.query.await([[
        SELECT id, to_citizenid, from_citizenid, business, amount
        FROM som_phone_bills
        WHERE status = 'pending' AND auto_collect = 1
          AND due_at IS NOT NULL AND due_at <= NOW()
        ORDER BY id
        LIMIT 100
    ]]) or {}

    for _, bill in ipairs(due) do
        local ok

        if bill.business then
            ok = exports['som-core']:removeMoney(bill.to_citizenid, 'bank', bill.amount,
                ('bill-auto:%d'):format(bill.id))

            if ok then exports['som-economy']:recordBusinessRevenue(bill.business, bill.amount) end
        else
            ok = exports['som-core']:transferToCitizen(bill.to_citizenid, bill.from_citizenid,
                'bank', bill.amount, ('bill-auto:%d'):format(bill.id))
        end

        if ok then
            MySQL.update.await([[
                UPDATE som_phone_bills
                SET status = 'paid', settled_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ]], { bill.id })

            local debtor = exports['som-core']:getPlayerByCitizenId(bill.to_citizenid)
            if debtor then
                TriggerClientEvent('som-phone:client:banner', debtor.source,
                    'Bank', ('$%s was collected for an unpaid bill'):format(bill.amount), 'receipt')
                TriggerClientEvent('som-phone:client:refresh', debtor.source)
            end
        end
    end
end

---@param source number
---@param billId number
---@return boolean success, string|nil err
function Bank.DeclineBill(source, billId)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    local updated = MySQL.update.await([[
        UPDATE som_phone_bills SET status = 'declined', settled_at = CURRENT_TIMESTAMP
        WHERE id = ? AND to_citizenid = ? AND status = 'pending'
    ]], { tonumber(billId) or 0, player.citizenid })

    if updated < 1 then return false, 'no such bill' end
    return true
end

---Sends money to any account number.
---
---Deliberately NOT gated on the account having been shared with you. Knowing
---somebody's number is enough to pay them, the same way it is in real life;
---the restriction belongs on billing, which takes money rather than giving it.
---@param source number
---@param accountNo string
---@param amount number
---@return boolean success, string|nil err
function Bank.Transfer(source, accountNo, amount)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    if type(accountNo) ~= 'string' or accountNo == '' then return false, 'invalid account' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, 'invalid amount' end

    local target = MySQL.single.await(
        'SELECT owner FROM som_bank_accounts WHERE account_no = ? AND type = ?',
        { accountNo, 'personal' })

    if not target or not target.owner then return false, 'no such account' end
    if target.owner == player.citizenid then return false, 'cannot transfer to yourself' end

    -- By citizenid, so the recipient does not have to be in the city to be
    -- paid. som-core writes the balance and ledger row directly when offline.
    local ok, err = exports['som-core']:transferToCitizen(
        source, target.owner, 'bank', amount, 'phone-transfer')
    if not ok then return false, err or 'transfer failed' end

    local recipient = exports['som-core']:getPlayerByCitizenId(target.owner)
    if recipient then
        TriggerClientEvent('som-phone:client:banner', recipient.source, 'Bank',
            ('Received $%s from %s %s'):format(amount, player.charinfo.firstname, player.charinfo.lastname),
            'arrowDown')
        TriggerClientEvent('som-phone:client:refresh', recipient.source)
    end

    return true
end
