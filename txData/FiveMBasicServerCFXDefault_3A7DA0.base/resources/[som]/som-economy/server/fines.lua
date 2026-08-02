-- Fines.
--
-- THE OFFICER RECEIVES NOTHING. Config.Fines.officerShare is zero and this
-- file never pays the issuer, by design rather than by omission.
--
-- If writing tickets paid an officer personally, the incentive would be to
-- fine as much and as often as possible. Routing the money to the department
-- instead means the reason to issue a fine is to fund the department and
-- enforce the law, and an officer choosing to let someone off costs them
-- nothing. That is the behaviour worth rewarding.
--
-- The split is department and treasury only.

Fines = {}

---@param source number issuing officer
---@param targetId number player being fined
---@param amount number
---@param reason string
---@return boolean success, string|number err or fine id
function Fines.Issue(source, targetId, amount, reason)
    local officer = exports['som-core']:getPlayer(source)
    if not officer then return false, 'officer not found' end

    local target = exports['som-core']:getPlayer(targetId)
    if not target then return false, 'target not found' end
    if officer.citizenid == target.citizenid then return false, 'cannot fine yourself' end

    local jobDef = exports['som-core']:getJobs()[officer.job.name]
    local department = jobDef and jobDef.business
    if not department then return false, 'not employed by a department' end

    local row = Business.Get(department)
    if not row or row.funding ~= 'fines' then
        return false, 'this department cannot issue fines'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Fines.minimum or amount > Config.Fines.maximum then
        return false, ('amount must be between %d and %d')
            :format(Config.Fines.minimum, Config.Fines.maximum)
    end

    if type(reason) ~= 'string' or #reason < 3 or #reason > 128 then
        return false, 'a reason is required'
    end

    local id = MySQL.insert.await([[
        INSERT INTO som_fines (citizenid, issued_by, department, reason, amount)
        VALUES (?, ?, ?, ?, ?)
    ]], { target.citizenid, officer.citizenid, department, reason, amount })

    TriggerClientEvent('som:client:notify', targetId,
        ('You have been fined $%s: %s'):format(amount, reason), 'error', 10000)
    TriggerClientEvent('som:client:notify', source,
        ('Fine issued: $%s'):format(amount), 'success')

    TriggerEvent('som:server:fineIssued', id, target.citizenid, officer.citizenid, amount)

    return true, id
end

---@param source number the person paying
---@param fineId number
---@return boolean success, string|nil err
function Fines.Pay(source, fineId)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'player not found' end

    local fine = MySQL.single.await(
        'SELECT * FROM som_fines WHERE id = ? AND status = ?', { fineId, 'unpaid' })
    if not fine then return false, 'no such unpaid fine' end

    -- Re-derived from the source, so a client cannot pay somebody else's fine
    -- or claim one that is not theirs.
    if fine.citizenid ~= player.citizenid then return false, 'not your fine' end

    local paid = exports['som-core']:removeMoney(source, 'bank', fine.amount,
        ('fine:%d'):format(fine.id))
    if not paid then return false, 'insufficient funds' end

    -- Split. The officer is deliberately absent from this calculation.
    local treasuryCut = math.floor(fine.amount * Config.Fines.treasuryShare)
    local departmentCut = fine.amount - treasuryCut

    if departmentCut > 0 then
        exports['som-core']:businessTransact(fine.department, departmentCut,
            ('fine-revenue:%d'):format(fine.id))
    end
    if treasuryCut > 0 then
        exports['som-core']:taxToTreasury(treasuryCut, ('fine-tax:%d'):format(fine.id))
    end

    MySQL.update.await(
        'UPDATE som_fines SET status = ?, paid_at = CURRENT_TIMESTAMP WHERE id = ?',
        { 'paid', fine.id })

    return true
end

---Voids a fine. Supervisory action, so it is logged with who did it.
---@param source number
---@param fineId number
---@return boolean success, string|nil err
function Fines.Void(source, fineId)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'player not found' end

    if not player.job.isboss and not exports['som-core']:hasPermission(source, 'som.admin') then
        return false, 'not authorised' end

    local updated = MySQL.update.await(
        'UPDATE som_fines SET status = ?, voided_by = ? WHERE id = ? AND status = ?',
        { 'void', player.citizenid, fineId, 'unpaid' })

    if updated < 1 then return false, 'no such unpaid fine' end
    return true
end

---@param citizenid string
---@return table[] unpaid fines
function Fines.GetUnpaid(citizenid)
    return MySQL.query.await(
        'SELECT * FROM som_fines WHERE citizenid = ? AND status = ? ORDER BY created_at',
        { citizenid, 'unpaid' }) or {}
end

exports('issueFine', Fines.Issue)
exports('payFine', Fines.Pay)
exports('voidFine', Fines.Void)
exports('getUnpaidFines', Fines.GetUnpaid)

lib.callback.register('som-economy:server:getMyFines', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return {} end
    return Fines.GetUnpaid(player.citizenid)
end)

lib.callback.register('som-economy:server:payFine', function(source, fineId)
    local ok, err = Fines.Pay(source, tonumber(fineId) or 0)
    return { success = ok, error = err }
end)
