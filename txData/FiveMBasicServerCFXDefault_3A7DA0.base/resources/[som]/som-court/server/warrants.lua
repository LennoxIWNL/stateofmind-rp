--- Warrants. Expiry is `expires_at` against NOW() at read time; the sweep only
--- tidies the status column.

Warrants = {}

---@param citizenid string
---@param caseId number|nil
---@param reason string
---@param issuedBy string citizenid
---@return boolean issued
function Warrants.Issue(citizenid, caseId, reason, issuedBy)
    if caseId and MySQL.scalar.await(
        "SELECT id FROM som_court_warrants WHERE case_id = ? AND status = 'active' AND expires_at > NOW()",
        { caseId }) then
        return false
    end

    MySQL.insert.await([[
        INSERT INTO som_court_warrants (citizenid, case_id, reason, issued_by, expires_at)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], { citizenid, caseId, reason:sub(1, 255), issuedBy, Config.WarrantHours })

    return true
end

---@param citizenid string
---@return table[]
function Warrants.Active(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    return MySQL.query.await(
        "SELECT * FROM som_court_warrants WHERE citizenid = ? AND status = 'active' AND expires_at > NOW()",
        { citizenid }) or {}
end

---Booking someone is how a warrant is served.
---@param citizenid string
---@return number served
function Warrants.Serve(citizenid)
    if type(citizenid) ~= 'string' then return 0 end
    return MySQL.update.await(
        "UPDATE som_court_warrants SET status = 'served' WHERE citizenid = ? AND status = 'active' AND expires_at > NOW()",
        { citizenid })
end

function Warrants.Sweep()
    MySQL.update.await(
        "UPDATE som_court_warrants SET status = 'expired' WHERE status = 'active' AND expires_at <= NOW()")
end

exports('activeWarrants', Warrants.Active)
exports('serveWarrants', Warrants.Serve)

CreateThread(function()
    Wait(7000)

    while true do
        Wait(300000)
        pcall(Warrants.Sweep)
    end
end)
