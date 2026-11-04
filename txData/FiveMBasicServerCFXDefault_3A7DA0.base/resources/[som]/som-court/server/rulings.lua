--- Hearings and their outcomes, plus the exports som-jail uses to carry a
--- ruling out. A court can lower a sentence, never raise it.

local core = exports['som-core']

local function fail(err) return { success = false, error = err } end

---@param source number
---@param caseId any
---@return table|nil judge, table|nil case, string|nil error
local function bench(source, caseId)
    local judge, err = Court.Actor(source, 'judge')
    if not judge then return nil, nil, err end
    if not Court.HasGrade(judge, Config.Grades.ruling) then return nil, nil, 'not permitted' end

    local case = Court.Get(caseId)
    if not case then return nil, nil, 'no such case' end

    -- Felonies need a more senior bench than everything else.
    if case.class == 'felony' and not Court.HasGrade(judge, Config.Grades.felony) then
        return nil, nil, 'a felony needs a more senior judge'
    end

    return judge, case
end

---@param value any
---@param ceiling number
---@return number|nil
local function amount(value, ceiling)
    local n = math.floor(tonumber(value) or -1)
    if n < 0 or n > ceiling then return nil end
    return n
end

lib.callback.register('som-court:server:rule', function(source, data)
    if type(data) ~= 'table' then return fail('bad request') end

    local judge, case, err = bench(source, data.id)
    if not judge then return fail(err) end

    local caps = Config.Classes[case.class]
    local notes = type(data.notes) == 'string' and data.notes:sub(1, 500) or nil

    if data.guilty ~= true then
        local won = MySQL.update.await([[
            UPDATE som_court_cases SET status = 'acquitted', ruled_at = NOW(), judge_cid = ?, notes = ?
            WHERE id = ? AND status = 'scheduled' AND hearing_at <= NOW()
        ]], { judge.citizenid, notes, case.id })
        if won ~= 1 then return fail('this case is not ready for a ruling') end

        Court.Event(case.id, judge.citizenid, 'acquitted')
        return { success = true }
    end

    local months, fine = amount(data.months, caps.maxMonths), amount(data.fine, caps.maxFine)
    local tasks = amount(data.tasks or 0, caps.maxTasks)
    if not months or not fine or not tasks then return fail('outside what this charge allows') end
    if months > 0 and tasks > 0 then return fail('choose custody or community service, not both') end

    local bail
    if data.bail ~= nil then
        if case.class ~= 'felony' then return fail('only a felony carries bail') end
        bail = amount(data.bail, Config.Bail.max)
        if not bail or bail < Config.Bail.min then return fail('bail is outside the allowed range') end
    end

    local defendant = fine > 0 and core:getPlayerByCitizenId(case.defendant_cid) or nil
    if fine > 0 and not defendant then return fail('the defendant must be present to be fined') end

    local won = MySQL.update.await([[
        UPDATE som_court_cases
        SET status = ?, ruled_at = NOW(), judge_cid = ?, sentence_months = ?, service_tasks = ?, fine = ?, bail_amount = ?, notes = ?
        WHERE id = ? AND status = 'scheduled' AND hearing_at <= NOW()
    ]], { (months > 0 or tasks > 0) and 'convicted' or 'sentenced', judge.citizenid, months, tasks, fine, bail, notes, case.id })
    if won ~= 1 then return fail('this case is not ready for a ruling') end

    if fine > 0 then
        local ok = exports['som-economy']:issueFine(source, defendant.source, fine, ('Court case #%d'):format(case.id))
        if not ok then
            MySQL.update.await([[
                UPDATE som_court_cases SET status = 'scheduled', ruled_at = NULL
                WHERE id = ? AND status IN ('convicted','sentenced')
            ]], { case.id })
            return fail('the fine could not be issued')
        end
    end

    Court.Event(case.id, judge.citizenid, 'convicted', ('%d mo, %d tasks, $%d'):format(months, tasks, fine))
    return { success = true }
end)

lib.callback.register('som-court:server:dismiss', function(source, id)
    local judge, case, err = bench(source, id)
    if not judge then return fail(err) end

    local won = MySQL.update.await([[
        UPDATE som_court_cases SET status = 'dismissed', judge_cid = ?
        WHERE id = ? AND status IN ('filed','accepted','scheduled','convicted')
    ]], { judge.citizenid, case.id })
    if won ~= 1 then return fail('that case cannot be dismissed') end

    Court.Event(case.id, judge.citizenid, 'dismissed')
    return { success = true }
end)

--- Months only. A fine is billed the moment it is ruled, so it cannot be amended.
lib.callback.register('som-court:server:amend', function(source, id, months)
    local judge, case, err = bench(source, id)
    if not judge then return fail(err) end

    months = amount(months, Config.Classes[case.class].maxMonths)
    if not months then return fail('outside what this charge allows') end

    local won = MySQL.update.await([[
        UPDATE som_court_cases SET sentence_months = ?
        WHERE id = ? AND status = 'convicted' AND sentence_months >= ?
    ]], { months, case.id, months })
    if won ~= 1 then return fail('a sentence can only be lowered') end

    Court.Event(case.id, judge.citizenid, 'amended', ('%d mo'):format(months))
    return { success = true }
end)

lib.callback.register('som-court:server:setBail', function(source, id, value)
    local judge, case, err = bench(source, id)
    if not judge then return fail(err) end

    local bail = amount(value, Config.Bail.max)
    if not bail or bail < Config.Bail.min then return fail('bail is outside the allowed range') end

    local won = MySQL.update.await([[
        UPDATE som_court_cases SET bail_amount = ?
        WHERE id = ? AND class = 'felony' AND status IN ('accepted','scheduled')
    ]], { bail, case.id })
    if won ~= 1 then return fail('bail can only be set on an open felony') end

    Court.Event(case.id, judge.citizenid, 'bail set', ('$%d'):format(bail))
    return { success = true }
end)

--- A hearing came and went with nobody in the chair, so the defendant is wanted.
lib.callback.register('som-court:server:failureToAppear', function(source, id)
    local judge, case, err = bench(source, id)
    if not judge then return fail(err) end

    local late = MySQL.update.await([[
        UPDATE som_court_cases SET notes = 'failure to appear'
        WHERE id = ? AND status = 'scheduled' AND hearing_at <= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { case.id, Config.FailureGraceMinutes })
    if late ~= 1 then return fail('the hearing is not yet overdue') end

    if not Warrants.Issue(case.defendant_cid, case.id, ('Failure to appear, case #%d'):format(case.id), judge.citizenid) then
        return fail('there is already a warrant for this case')
    end

    Court.Event(case.id, judge.citizenid, 'failure to appear')
    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- What som-jail needs from the court
-- ---------------------------------------------------------------------------

---Cases an officer may act on for this person: custody sentences to carry out and open
---cases a suspect can be held on.
---@param citizenid string
---@return table[]
exports('casesFor', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    return MySQL.query.await(
        "SELECT id, class, status, charges, sentence_months, service_tasks, bail_amount FROM som_court_cases "
        .. "WHERE defendant_cid = ? AND (status IN ('filed','accepted','scheduled') OR (status = 'convicted' AND (sentence_months > 0 OR service_tasks > 0))) "
        .. "ORDER BY id DESC LIMIT 10",
        { citizenid }) or {}
end)

---Atomically turns a conviction into a carried-out sentence. Whoever gets the row owns it.
---@param caseId any
---@param citizenid string
---@param officer string citizenid
---@return table|nil case
exports('claimForSentence', function(caseId, citizenid, officer)
    caseId = tonumber(caseId)
    if not caseId or type(citizenid) ~= 'string' then return nil end

    local won = MySQL.update.await(
        "UPDATE som_court_cases SET status = 'sentenced' WHERE id = ? AND defendant_cid = ? AND status = 'convicted' AND (sentence_months > 0 OR service_tasks > 0)",
        { caseId, citizenid })
    if won ~= 1 then return nil end

    Court.Event(caseId, tostring(officer), 'sentenced')
    return Court.Get(caseId)
end)

---Undoes claimForSentence when the sentence row could not be written.
---@param caseId any
exports('unclaimSentence', function(caseId)
    MySQL.update.await(
        "UPDATE som_court_cases SET status = 'convicted' WHERE id = ? AND status = 'sentenced'",
        { tonumber(caseId) })
end)

---An open case this person may be held on before trial, or nil.
---@param caseId any
---@param citizenid string
---@return table|nil
exports('openCase', function(caseId, citizenid)
    local case = Court.Get(caseId)
    if not case or case.defendant_cid ~= citizenid then return nil end
    if case.status ~= 'filed' and case.status ~= 'accepted' and case.status ~= 'scheduled' then return nil end
    return case
end)

---@param caseId any
---@return table|nil
exports('bailTerms', function(caseId)
    local case = Court.Get(caseId)
    if not case then return nil end
    return { class = case.class, status = case.status, bail_amount = case.bail_amount }
end)
