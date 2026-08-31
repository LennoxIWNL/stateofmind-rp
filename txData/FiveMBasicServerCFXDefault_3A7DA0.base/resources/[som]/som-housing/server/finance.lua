--- Mortgages, arrears and repossession.
---
--- A MORTGAGE REQUIRES AN ONLINE REALTOR. Buying outright requires nobody. That
--- asymmetry is the whole design: the fast path never depends on another player
--- being around, and the cheaper path costs a conversation.
---
--- THE INSTALMENTS ARE REAL BILLS. Each cycle raises a som_phone_bills row with
--- auto_collect set, so som-phone's existing sweep collects it and this file
--- only owns the contract. Building a second collector beside the one that
--- already works is how two systems end up disagreeing about what is owed.

local core = exports['som-core']
local phone = exports['som-phone']

Finance = {}


---The active contract on a property, or nil.
---@param propertyId number
---@return table|nil
function Finance.For(propertyId)
    propertyId = tonumber(propertyId)
    if not propertyId then return nil end

    return MySQL.single.await(
        "SELECT * FROM som_property_finance WHERE property_id = ? AND status = 'active'",
        { propertyId })
end

---Every active contract a citizen is paying.
---@param citizenid string
---@return table
function Finance.ListFor(citizenid)
    if type(citizenid) ~= 'string' then return {} end

    return MySQL.query.await([[
        SELECT f.*, p.label, p.slug
        FROM som_property_finance f
        JOIN som_properties p ON p.id = f.property_id
        WHERE f.citizenid = ? AND f.status = 'active'
        ORDER BY f.next_due ASC
    ]], { citizenid }) or {}
end

-- ---------------------------------------------------------------------------
-- Writing a mortgage
-- ---------------------------------------------------------------------------


--- Signing.
---
--- Called by the REALTOR, not by the buyer. The realtor is the one with the
--- authority here, so they are the one the server validates, and the buyer is
--- an argument. That also means a buyer cannot write themselves a mortgage by
--- calling this with their own id.
lib.callback.register('som-housing:server:mortgage', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'bad request' } end

    local realtor = core:getPlayer(source)
    if not realtor then return { success = false, error = 'not loaded' } end

    -- READ OFF THE PLAYER, not through core:hasJob. That export is CLIENT ONLY;
    -- there is no server half, so calling it here would be a nil call. Same
    -- class as GetSlot and FreezeEntityPosition, which AUDIT records as having
    -- cost time four separate times: an export existing is not the same as it
    -- existing on the side you are calling it from.
    local job = realtor.job
    if not job or job.name ~= Config.Finance.job or not job.onduty then
        return { success = false, error = 'only an estate agent on duty can write a mortgage' }
    end

    local buyerSource = tonumber(data.buyer)
    if not buyerSource then return { success = false, error = 'no buyer' } end

    local buyer = core:getPlayer(buyerSource)
    if not buyer then return { success = false, error = 'that buyer is not here' } end

    if buyer.citizenid == realtor.citizenid then
        return { success = false, error = 'you cannot sell to yourself' }
    end

    local property = Properties.BySlug(data.slug)
    if not property then return { success = false, error = 'no such property' } end
    if property.for_sale ~= 1 then return { success = false, error = 'not for sale' } end
    if Ownership.OwnerOf(property.id) then return { success = false, error = 'already sold' } end

    if Ownership.OwnedCount(buyer.citizenid) >= Config.Purchase.maxOwned then
        return { success = false, error = 'the buyer already owns too many properties' }
    end

    local cycles = math.floor(tonumber(data.cycles) or 0)
    if cycles < Config.Finance.minCycles or cycles > Config.Finance.maxCycles then
        return { success = false, error = ('between %d and %d payments'):format(
            Config.Finance.minCycles, Config.Finance.maxCycles) }
    end

    -- BOTH PARTIES MUST BE AT THE PROPERTY. Measured server side, from each
    -- ped, so a realtor cannot write a contract on a house neither of them has
    -- seen and a buyer cannot be signed up from across the map.
    local door = vec3(property.door_x, property.door_y, property.door_z)

    for _, src in ipairs({ source, buyerSource }) do
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return { success = false, error = 'no ped' } end
        if #(GetEntityCoords(ped) - door) > Config.Purchase.distance then
            return { success = false, error = 'both of you must be at the property' }
        end
    end

    local deposit = math.floor(property.price * Config.Finance.depositRate)
    local financed = property.price - deposit
    local total = math.floor(financed * (1.0 + Config.Finance.interestRate))
    local instalment = math.ceil(total / cycles)

    -- The BUYER pays the deposit, from an account they chose.
    local paid, payErr = core:payWith(buyerSource, data.account, deposit,
        ('property-deposit:%s'):format(property.slug))

    if not paid then
        return { success = false, error = payErr or 'the buyer could not pay the deposit' }
    end

    if not Ownership.Grant(property.id, buyer.citizenid, 'owner', realtor.citizenid) then
        core:addMoney(buyerSource, data.account, deposit, 'property-deposit-refund')
        return { success = false, error = 'could not register the sale' }
    end

    MySQL.update.await('UPDATE som_properties SET for_sale = 0 WHERE id = ?', { property.id })

    MySQL.insert.await([[
        INSERT INTO som_property_finance
            (property_id, citizenid, principal, remaining, instalment,
             interval_days, next_due, realtor_citizenid, status)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY), ?, 'active')
    ]], {
        property.id, buyer.citizenid, total, total, instalment,
        Config.Finance.intervalDays, Config.Finance.intervalDays, realtor.citizenid,
    })

    -- Commission comes out of the deposit rather than out of the bank, so the
    -- money in play is money a player actually handed over.
    local commission = math.floor(deposit * Config.Finance.commission)
    if commission > 0 then
        core:addMoney(source, 'bank', commission, ('property-commission:%s'):format(property.slug))
    end

    Finance.RaiseNext(property.id)

    return {
        success = true,
        label = property.label,
        deposit = deposit,
        instalment = instalment,
        cycles = cycles,
        commission = commission,
    }
end)

-- ---------------------------------------------------------------------------
-- Billing a cycle
-- ---------------------------------------------------------------------------

---Raises the next instalment as a real, auto-collecting bill.
---
---`business` is set so som-phone's collector takes the branch that removes
---money and books revenue rather than the citizen-to-citizen transfer, which
---would need the lender to be a person who is online.
---@param propertyId number
---@return boolean
function Finance.RaiseNext(propertyId)
    local contract = Finance.For(propertyId)
    if not contract then return false end

    local property = Properties.ById(propertyId)
    if not property then return false end

    local amount = math.min(contract.instalment, contract.remaining)
    if amount < 1 then return false end

    local id = phone:billCitizen(
        contract.citizenid,
        'property-finance',
        amount,
        ('Mortgage: %s'):format(property.label),
        { dueDays = contract.interval_days }
    )

    return id ~= nil
end

-- ---------------------------------------------------------------------------
-- The sweep
-- ---------------------------------------------------------------------------

--- Contracts whose payment is due, and what to do about them.
---
--- THE HOLE THIS EXISTS TO CLOSE. som-phone's CollectOverdue resolves debtors
--- through its in-memory player registry, so a bill against somebody who is
--- logged out is skipped and retried forever, silently. Left alone, staying
--- offline would be a way to keep a house without paying for it.
---
--- So this counts the miss instead. A cycle that passes without the debt
--- shrinking increments missed_cycles, and Settle below clears the arrears the
--- moment they next log in. Enough misses and the property is repossessed.
local function sweep()
    local due = MySQL.query.await([[
        SELECT * FROM som_property_finance
        WHERE status = 'active' AND next_due <= NOW()
    ]]) or {}

    for _, contract in ipairs(due) do
        local online = core:getPlayerByCitizenId(contract.citizenid)

        if online then
            -- They are here, so the phone's own collector will take it on its
            -- next pass. Just move the clock on.
            Finance.RaiseNext(contract.property_id)

            MySQL.update.await([[
                UPDATE som_property_finance
                SET next_due = DATE_ADD(next_due, INTERVAL interval_days DAY)
                WHERE id = ?
            ]], { contract.id })
        else
            local missed = contract.missed_cycles + 1

            MySQL.update.await([[
                UPDATE som_property_finance
                SET missed_cycles = ?,
                    next_due = DATE_ADD(next_due, INTERVAL interval_days DAY)
                WHERE id = ?
            ]], { missed, contract.id })

            if missed >= Config.Finance.repossessAfterMissed then
                Finance.Repossess(contract.id)
            end
        end
    end
end

---Settles what an owner owes, oldest first, now that they are back.
---
---Called on login. Raises one bill per missed cycle rather than one large one,
---so the phone shows what actually happened and each is refusable in the same
---way a single payment would have been.
---@param citizenid string
function Finance.Settle(citizenid)
    if type(citizenid) ~= 'string' then return end

    local owed = MySQL.query.await([[
        SELECT * FROM som_property_finance
        WHERE citizenid = ? AND status = 'active' AND missed_cycles > 0
        ORDER BY next_due ASC
    ]], { citizenid }) or {}

    for _, contract in ipairs(owed) do
        for _ = 1, contract.missed_cycles do
            Finance.RaiseNext(contract.property_id)
        end

        MySQL.update.await(
            'UPDATE som_property_finance SET missed_cycles = 0 WHERE id = ?',
            { contract.id })
    end
end

---Takes the property back.
---@param contractId number
function Finance.Repossess(contractId)
    local contract = MySQL.single.await(
        'SELECT * FROM som_property_finance WHERE id = ?', { contractId })

    if not contract or contract.status ~= 'active' then return end

    local paid = contract.principal - contract.remaining
    local refund = math.floor(paid * Config.Finance.repossessRefundRate)

    MySQL.update.await(
        "UPDATE som_property_finance SET status = 'repossessed' WHERE id = ?", { contractId })

    -- Every key goes, not only the owner's. A co-owner keeping access to a
    -- house the bank has taken back is the kind of hole that gets found.
    MySQL.update.await(
        'DELETE FROM som_property_owners WHERE property_id = ?', { contract.property_id })

    MySQL.update.await(
        'UPDATE som_properties SET for_sale = 1 WHERE id = ?', { contract.property_id })

    if refund > 0 then
        -- transferToCitizen reaches an offline recipient, which matters because
        -- being offline is precisely why this happened.
        core:addMoney(contract.citizenid, 'bank', refund,
            ('property-repossession-refund:%d'):format(contract.property_id))
    end

    local online = core:getPlayerByCitizenId(contract.citizenid)
    if online then
        phone:notifyApp(online.source, 'properties', 'Your property has been repossessed.')
    end
end

CreateThread(function()
    Wait(5000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_property_finance LIMIT 1')
    end)

    if not ok then
        print('[som-housing] som_property_finance is missing. Import setup.sql.')
        return
    end

    while true do
        Wait(Config.Finance.sweepMinutes * 60000)
        pcall(sweep)
    end
end)

--- (source, citizenid) with citizenid a STRING, type-guarded for the reason
--- som-medical records: indexing a string returns nil through the string
--- metatable rather than erroring, so a handler written for a table never runs
--- and never says so.
AddEventHandler('som:server:playerLoaded', function(source, citizenid)
    if type(citizenid) ~= 'string' then return end

    -- Deferred so it lands after som-phone has finished setting the player up,
    -- and so a login is not held on a database round trip.
    SetTimeout(10000, function()
        pcall(Finance.Settle, citizenid)
    end)
end)

exports('financeFor', Finance.For)
exports('financeListFor', Finance.ListFor)

---Who the realtor could actually sell to right now.
---
---RESOLVED SERVER SIDE from real positions, so the list a realtor picks from is
---people who are genuinely standing there. The mortgage call re-checks the
---distance anyway; this exists so the dialog does not offer somebody across the
---map and then refuse them.
lib.callback.register('som-housing:server:nearbyBuyers', function(source)
    local realtor = core:getPlayer(source)
    if not realtor then return { success = false, error = 'not loaded' } end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, error = 'no ped' } end

    local here = GetEntityCoords(ped)
    local out = {}

    for _, other in ipairs(core:getPlayers() or {}) do
        if other.source ~= source then
            local otherPed = GetPlayerPed(other.source)

            if otherPed and otherPed ~= 0
                and #(here - GetEntityCoords(otherPed)) <= Config.Purchase.distance then
                out[#out + 1] = {
                    source = other.source,
                    name = other.charinfo
                        and ('%s %s'):format(other.charinfo.firstname, other.charinfo.lastname)
                        or ('Citizen %s'):format(other.citizenid),
                }
            end
        end
    end

    return { success = true, players = out }
end)
