-- Business register.
--
-- Every business, private or government, owns a real bank account. Wages,
-- equipment and vehicles are paid out of it, and revenue pays into it. Nothing
-- appears from nowhere, which is what makes the sink and faucet figures mean
-- something.
--
-- Three funding models:
--   sales     a shop or garage: revenue from what it sells, taxed
--   fines     a police department: revenue from penalties, never from the
--             officer who wrote them
--   treasury  EMS: funded by the city, sells nothing, because charging for
--             medical care turns treatment into a paywall

Business = {}

local cache = {}

function Business.Load()
    cache = {}

    local rows = MySQL.query.await([[
        SELECT b.*, a.balance, a.account_no
        FROM som_businesses b
        LEFT JOIN som_bank_accounts a ON a.id = b.account_id
    ]]) or {}

    for _, row in ipairs(rows) do
        cache[row.name] = row
    end

    print(('[som-economy] business register loaded, %d entries'):format(#rows))
end

---@param name string
---@return table|nil
function Business.Get(name)
    return cache[name]
end

---@return table[]
function Business.GetAll()
    local list = {}
    for _, row in pairs(cache) do list[#list + 1] = row end
    return list
end

---@param name string
---@return number
function Business.GetBalance(name)
    local row = cache[name]
    if not row or not row.account_id then return 0 end

    return MySQL.scalar.await('SELECT balance FROM som_bank_accounts WHERE id = ?',
        { row.account_id }) or 0
end

---Records revenue and takes the treasury's cut off the top.
---
---Tax is charged on business revenue rather than on player wages, because
---income tax is invisible and feels punitive, while a business paying tax is
---something the city can visibly spend.
---@param name string
---@param gross number
---@return boolean success, number net
function Business.RecordRevenue(name, gross)
    local row = cache[name]
    if not row then return false, 0 end

    gross = math.floor(tonumber(gross) or 0)
    if gross < 1 then return false, 0 end

    local rate = tonumber(row.treasury_cut) or Config.Tax.default
    if rate < 0 then rate = 0 end
    if rate > Config.Tax.maximum then rate = Config.Tax.maximum end

    local tax = math.floor(gross * rate)
    local net = gross - tax

    if net > 0 then
        exports['som-core']:businessTransact(name, net, 'revenue')
    end
    if tax > 0 then
        exports['som-core']:taxToTreasury(tax, ('tax:%s'):format(name))
    end

    MySQL.update.await('UPDATE som_businesses SET revenue_total = revenue_total + ? WHERE name = ?',
        { gross, name })

    return true, net
end

---Spends from a business account. Used for wages, equipment and vehicles.
---@param name string
---@param amount number positive
---@param reason string
---@return boolean success, string|nil err
function Business.Spend(name, amount, reason)
    local row = cache[name]
    if not row then return false, 'unknown business' end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, 'invalid amount' end

    if Business.GetBalance(name) < amount then
        return false, 'insufficient business funds'
    end

    return exports['som-core']:businessTransact(name, -amount, reason or 'expense')
end

---Tops a treasury-funded department up from the city budget.
---
---Placeholder allocation until the mayor system on the roadmap decides
---budgets. Deliberately capped, so a department cannot silently drain the
---treasury by existing.
---@param name string
---@param amount number
---@return boolean
function Business.FundFromTreasury(name, amount)
    local row = cache[name]
    if not row or row.funding ~= 'treasury' then return false end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false end

    -- Signed treasury path: taxToTreasury only accepts positives, so spending
    -- has to go through treasuryTransact or it silently fails.
    local reason = ('budget:%s'):format(name)
    local ok = exports['som-core']:treasuryTransact(-amount, reason)
    if not ok then return false end

    local called, credited = pcall(function()
        return exports['som-core']:businessTransact(name, amount, 'city-budget')
    end)
    if not called or not credited then
        exports['som-core']:treasuryTransact(amount, reason .. ':refund')
        return false
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Armoury
--
-- Split on purpose. Protective equipment is issued by the department, because
-- an officer who cannot afford armour is a safety problem and charging for it
-- pushes people to work unprotected. Weapons and ammunition are personal, so
-- there is a real cost to spraying rounds around.
-- ---------------------------------------------------------------------------

---What an officer personally pays for an item, or 0 if the department issues
---it. Shops show a price before charging it, so this has to be readable
---without attempting a purchase.
---@param item string
---@return number|nil price, boolean isDepartmentIssue
function Business.ArmouryPrice(item)
    if Config.Armoury.departmentIssue[item] ~= nil then return 0, true end

    local price = Config.Armoury.personal[item]
    if not price then return nil, false end

    local subsidy = math.floor(price * (Config.Armoury.departmentSubsidy or 0.0))
    return price - subsidy, false
end

---@param source number
---@param department string
---@param item string
---@param account string|nil what the officer pays with, for personal items.
---       Defaults to bank. Validated by som-core, never trusted from here.
---@return boolean success, string|nil err
function Business.IssueEquipment(source, department, item, account)
    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'player not found' end

    local row = cache[department]
    -- oxmysql returns TINYINT(1) as a boolean rather than 1, so an equality
    -- check against the number rejects every active department.
    if not row or not (row.active == true or row.active == 1) then
        return false, 'department not active'
    end

    -- Server side job check. The armoury UI showing an item grants nothing.
    if row.job and player.job.name ~= row.job then
        return false, 'not employed by this department'
    end

    local departmentCost = Config.Armoury.departmentIssue[item]
    if departmentCost ~= nil then
        -- Free to the officer. The department pays, even if that is zero.
        if departmentCost > 0 then
            local ok, err = Business.Spend(department, departmentCost,
                ('issue:%s'):format(item))
            if not ok then return false, err end
        end
        return true
    end

    local price = Config.Armoury.personal[item]
    if not price then return false, 'item not stocked' end

    local subsidy = math.floor(price * (Config.Armoury.departmentSubsidy or 0.0))
    local officerPays = price - subsidy

    if subsidy > 0 then
        local ok = Business.Spend(department, subsidy, ('subsidy:%s'):format(item))
        if not ok then return false, 'department cannot cover its share' end
    end

    if officerPays > 0 then
        -- payWith rather than a hardcoded bank debit, so the armoury offers the
        -- same cash-or-card choice every other shop does. som-core rejects any
        -- account that is not payable, so naming 'dirty' here buys nothing.
        local paid, payError = exports['som-core']:payWith(source, account or 'bank',
            officerPays, ('armoury:%s'):format(item))

        if not paid then return false, payError or 'you cannot afford that' end
    end

    return true
end

---Pays an employee their share of a sale they personally made.
---
---This is where a player-owned job actually earns. Base wages are deliberately
---low, so serving customers has to be worth more than standing on the clock.
---
---Commission is a labour cost paid OUT of the business account, not minted, so
---a shop that sells nothing cannot pay anyone.
---@param source number
---@param businessName string
---@param gross number the sale value before tax
---@return number paid
function Business.PayCommission(source, businessName, gross)
    local player = exports['som-core']:getPlayer(source)
    if not player then return 0 end

    local jobDef = exports['som-core']:getJobs()[player.job.name]
    if not jobDef or not jobDef.commission then return 0 end

    -- Only pay commission for the business the employee actually works for.
    -- Without this an employee of one shop would earn from selling at another.
    if jobDef.business ~= businessName then return 0 end

    local amount = math.floor((tonumber(gross) or 0) * jobDef.commission)
    if amount < 1 then return 0 end

    local ok = Business.Spend(businessName, amount,
        ('commission:%s'):format(player.citizenid))
    if not ok then return 0 end

    exports['som-core']:addMoney(source, 'bank', amount,
        ('commission:%s'):format(businessName))

    return amount
end

exports('payCommission', Business.PayCommission)
exports('getBusiness', Business.Get)
exports('getBusinesses', Business.GetAll)
exports('getBusinessBalance', Business.GetBalance)
exports('recordBusinessRevenue', Business.RecordRevenue)
exports('businessSpend', Business.Spend)
exports('fundFromTreasury', Business.FundFromTreasury)
exports('issueEquipment', Business.IssueEquipment)
exports('armouryPrice', Business.ArmouryPrice)
