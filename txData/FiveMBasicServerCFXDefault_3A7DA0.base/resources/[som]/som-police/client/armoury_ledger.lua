--- The armoury ledger menu: sign out, return, and for supervisors who holds
--- what. A menu of requests; the server decides every one of them.

Ledger = {}

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function call(name, ...)
    local ok, res = pcall(lib.callback.await, name, false, ...)
    if not ok or not res then say('The armoury did not answer', 'error') return nil end
    if not res.success then say(res.error or 'Failed', 'error') return nil end
    return res
end

local function audit()
    local res = call('som-police:server:ledgerAudit')
    if not res then return end

    local options = {}
    for _, row in ipairs(res.rows) do
        local flagged = row.status == 'missing'
        options[#options + 1] = {
            title = ('%s %s'):format(row.label, row.serial or ''),
            description = ('%s, out %dh%s'):format(row.officer, row.hours, flagged and ', MISSING' or ''),
            disabled = flagged,
            onSelect = function()
                local sure = lib.alertDialog({ header = 'Flag missing', content = ('Report %s %s as missing? This calls dispatch.'):format(row.label, row.serial or ''), centered = true, cancel = true })
                if sure ~= 'confirm' then return end
                if call('som-police:server:flagMissing', row.id) then say('Reported to dispatch', 'success') end
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Nothing is signed out', disabled = true } end

    lib.registerContext({ id = 'som_police_ledger_audit', title = 'Who holds what', menu = 'som_police_ledger', options = options })
    lib.showContext('som_police_ledger_audit')
end

function Ledger.Open()
    local res = call('som-police:server:ledger')
    if not res then return end

    local options = {}
    for _, loan in ipairs(res.loans) do
        options[#options + 1] = {
            title = ('Sign out: %s'):format(loan.label),
            onSelect = function()
                local out = call('som-police:server:signOut', loan.item)
                if out then say(('%s signed out, serial %s'):format(out.label, out.serial), 'success') end
            end,
        }
    end
    for _, held in ipairs(res.mine) do
        options[#options + 1] = {
            title = ('Return: %s %s'):format(held.label, held.serial or ''),
            description = held.status == 'missing' and 'Flagged missing' or nil,
            onSelect = function()
                if call('som-police:server:returnWeapon', held.item) then say('Weapon returned', 'success') end
            end,
        }
    end
    if res.supervisor then options[#options + 1] = { title = 'Who holds what', onSelect = audit } end
    if #options == 0 then options[1] = { title = 'Nothing to sign out or return', disabled = true } end

    lib.registerContext({ id = 'som_police_ledger', title = 'Armoury ledger', options = options })
    lib.showContext('som_police_ledger')
end
