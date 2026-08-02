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

    local bills = MySQL.query.await([[
        SELECT id, from_name, amount, reason, created_at
        FROM som_phone_bills
        WHERE to_citizenid = ? AND status = 'pending'
        ORDER BY id DESC
    ]], { player.citizenid }) or {}

    local saved = MySQL.query.await(
        'SELECT account_no, label FROM som_phone_accounts WHERE citizenid = ? ORDER BY label',
        { player.citizenid }) or {}

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

                    TriggerClientEvent('som:client:notify', targetId,
                        ('%s shared their account: %s'):format(name, accountNo), 'info', 10000)
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
    if target.owner == player.citizenid then return false, 'cannot bill yourself' end

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
        TriggerClientEvent('som:client:notify', targetPlayer.source,
            ('%s sent you a bill for $%s'):format(senderName, amount), 'info', 10000)
        TriggerClientEvent('som-phone:client:refresh', targetPlayer.source)
    end

    return true, id
end

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
    else
        local recipient = exports['som-core']:getPlayerByCitizenId(bill.from_citizenid)
        if not recipient then
            return false, 'the sender is not online to receive payment'
        end

        local ok, err = exports['som-core']:transferMoney(
            source, recipient.source, 'bank', bill.amount, ('bill:%d'):format(bill.id))
        if not ok then return false, err or 'transfer failed' end

        TriggerClientEvent('som:client:notify', recipient.source,
            ('Bill paid: $%s'):format(bill.amount), 'success')
        TriggerClientEvent('som-phone:client:refresh', recipient.source)
    end

    MySQL.update.await(
        'UPDATE som_phone_bills SET status = ?, settled_at = CURRENT_TIMESTAMP WHERE id = ?',
        { 'paid', bill.id })

    return true
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

---@param source number
---@param accountNo string
---@param amount number
---@return boolean success, string|nil err
function Bank.Transfer(source, accountNo, amount)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'not loaded' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, 'invalid amount' end

    local target = MySQL.single.await(
        'SELECT owner FROM som_bank_accounts WHERE account_no = ? AND type = ?',
        { accountNo, 'personal' })

    if not target or not target.owner then return false, 'no such account' end
    if target.owner == player.citizenid then return false, 'cannot transfer to yourself' end

    local recipient = exports['som-core']:getPlayerByCitizenId(target.owner)
    if not recipient then return false, 'they are not online' end

    local ok, err = exports['som-core']:transferMoney(
        source, recipient.source, 'bank', amount, 'phone-transfer')
    if not ok then return false, err or 'transfer failed' end

    TriggerClientEvent('som:client:notify', recipient.source,
        ('Received $%s from %s %s'):format(amount, player.charinfo.firstname, player.charinfo.lastname),
        'success')
    TriggerClientEvent('som-phone:client:refresh', recipient.source)

    return true
end
