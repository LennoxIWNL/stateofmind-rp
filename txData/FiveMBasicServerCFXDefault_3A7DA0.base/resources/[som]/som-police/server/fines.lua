-- Fines.
--
-- THE OFFICER RECEIVES NOTHING. som-economy owns the split (70% department,
-- 30% treasury, 0% officer) and this file never touches it.
--
-- What this adds is DELIVERY. som-economy records the debt; a fine that sits in
-- a database until the person chooses to open a menu is a fine you can ignore
-- forever. So the ticket also arrives as a phone bill that settles itself after
-- Config.Fines.dueDays. That is exactly what som_phone_bills.auto_collect and
-- due_at were added for.

local core = exports['som-core']

lib.callback.register('som-police:server:finePresets', function(source)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    return { success = true, presets = Config.Fines.presets }
end)

lib.callback.register('som-police:server:issueFine', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local targetId = tonumber(data.target) or 0
    local target = core:getPlayer(targetId)
    if not target then return { success = false, error = 'they are not around' } end

    -- Fining somebody across the map is not policing. The distance is generous
    -- compared with the custody verbs because a ticket does not need contact.
    if not Police.InRange(source, targetId, 8.0) then
        return { success = false, error = 'too far away' }
    end

    -- The amount is re-derived from the preset the officer named, so a client
    -- cannot invent a figure. A free-text fine still has to fall inside the
    -- min and max som-economy enforces.
    local amount, reason

    if data.preset then
        local preset = Config.Fines.presets[tonumber(data.preset) or 0]
        if not preset then return { success = false, error = 'no such offence' } end

        amount, reason = preset.amount, preset.label
    else
        amount = math.floor(tonumber(data.amount) or 0)
        reason = type(data.reason) == 'string' and data.reason or ''

        if #reason < 3 then return { success = false, error = 'a reason is required' } end
    end

    -- som-economy validates the range, the department and that the officer is
    -- not fining themselves, then records the debt.
    local ok, result = exports['som-economy']:issueFine(source, targetId, amount, reason)
    if not ok then return { success = false, error = result } end

    -- Delivery. The debt already exists; this is what makes it unavoidable.
    if GetResourceState('som-phone') == 'started' then
        local issuer = ('%s %s'):format(officer.charinfo.firstname, officer.charinfo.lastname)

        local billed = exports['som-phone']:billCitizen(
            target.citizenid, Config.Business, amount,
            ('LSPD fine: %s'):format(reason), {
                dueDays = Config.Fines.dueDays,
                issuerCitizenid = officer.citizenid,
                fromName = ('LSPD (%s)'):format(issuer),
            })

        if not billed then
            -- The fine still stands, it just has to be paid deliberately. Worth
            -- saying out loud rather than pretending the ticket was delivered.
            TriggerClientEvent('som:client:notify', source,
                'Fine recorded, but the bill could not be sent', 'inform')
        end
    end

    TriggerClientEvent('som:client:notify', targetId,
        ('Fine issued: $%s. It will be collected in %d days if unpaid.')
            :format(amount, Config.Fines.dueDays), 'error', 12000)

    return { success = true, amount = amount, id = result }
end)

-- ---------------------------------------------------------------------------
-- Supervisory
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:voidFine', function(source, fineId)
    local officer, err = Police.Officer(source, false)
    if not officer then return { success = false, error = err } end

    if officer.job.grade < Config.SupervisorGrade
        and not core:hasPermission(source, 'som.admin') then
        return { success = false, error = 'only command staff may void a fine' }
    end

    local ok, voidError = exports['som-economy']:voidFine(source, tonumber(fineId) or 0)
    if not ok then return { success = false, error = voidError } end

    return { success = true }
end)
