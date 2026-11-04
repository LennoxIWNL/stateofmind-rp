--- Court menus. These only choose what to offer; every action is checked again
--- on the server against the caller's job, grade and the case's state.

Menus = {}

local function notify(message, kind)
    TriggerEvent('som:client:notify', message, kind or 'inform')
end

---Runs a callback and reports the result, then reopens the docket.
local function act(name, ...)
    local res = lib.callback.await(name, false, ...)
    notify(res and (res.success and 'Done' or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
    Menus.Docket()
end

local function caseTitle(case)
    return ('#%d %s: %s'):format(case.id, Config.Classes[case.class].label, case.charges:sub(1, 50))
end

local function hearingChoices()
    local out = {}
    for slot, minutes in ipairs(Config.HearingOffsets) do
        out[#out + 1] = { value = slot, label = ('In %d minutes'):format(minutes) }
    end
    return out
end

local function ruleDialog(case)
    local caps = Config.Classes[case.class]
    local rows = {
        { type = 'select', label = 'Verdict', required = true, default = 'guilty',
          options = { { value = 'guilty', label = 'Guilty' }, { value = 'not', label = 'Not guilty' } } },
        { type = 'number', label = 'Months', min = 0, max = caps.maxMonths, default = 0 },
        { type = 'number', label = 'Community service tasks', min = 0, max = caps.maxTasks, default = 0 },
        { type = 'number', label = 'Fine', min = 0, max = caps.maxFine, default = 0 },
        { type = 'input', label = 'Notes', required = false },
    }
    if case.class == 'felony' then
        rows[#rows + 1] = { type = 'number', label = 'Bail (0 for none)', min = 0, max = Config.Bail.max, default = 0 }
    end

    local answer = lib.inputDialog(('Rule on case #%d'):format(case.id), rows)
    if not answer then return end

    act('som-court:server:rule', {
        id = case.id,
        guilty = answer[1] == 'guilty',
        months = answer[2],
        tasks = answer[3],
        fine = answer[4],
        notes = answer[5],
        bail = (answer[6] or 0) > 0 and answer[6] or nil,
    })
end

local function actionsFor(role, case)
    local out = {}
    local function add(label, fn) out[#out + 1] = { title = label, onSelect = fn } end

    if role == 'prosecutor' then
        if case.status == 'filed' then add('Accept', function() act('som-court:server:accept', case.id) end) end
        add('Drop', function() act('som-court:server:drop', case.id) end)
    elseif role == 'judge' then
        if case.status == 'accepted' then
            add('Schedule hearing', function()
                local answer = lib.inputDialog('Schedule', {
                    { type = 'select', label = 'When', options = hearingChoices(), required = true },
                })
                if answer then act('som-court:server:schedule', case.id, tonumber(answer[1])) end
            end)
        end
        if case.status == 'scheduled' then
            add('Rule', function() ruleDialog(case) end)
            add('Failure to appear', function() act('som-court:server:failureToAppear', case.id) end)
        end
        if case.class == 'felony' and (case.status == 'accepted' or case.status == 'scheduled') then
            add('Set bail', function()
                local answer = lib.inputDialog('Bail', {
                    { type = 'number', label = 'Amount', min = Config.Bail.min, max = Config.Bail.max, required = true },
                })
                if answer then act('som-court:server:setBail', case.id, answer[1]) end
            end)
        end
        if case.status == 'convicted' then
            add('Lower sentence', function()
                local answer = lib.inputDialog('Lower sentence', {
                    { type = 'number', label = 'Months', min = 0, max = case.sentence_months, required = true },
                })
                if answer then act('som-court:server:amend', case.id, answer[1]) end
            end)
        end
        add('Dismiss', function() act('som-court:server:dismiss', case.id) end)
    elseif role == 'defender' then
        add('Take the case', function() act('som-court:server:defend', case.id) end)
    end

    return out
end

local function showCase(role, case)
    local options = actionsFor(role, case)
    options[#options + 1] = {
        title = 'Back', icon = 'fa-solid fa-arrow-left', onSelect = function() Menus.Docket() end,
    }

    lib.registerContext({
        id = 'court_case',
        title = caseTitle(case),
        options = options,
    })
    lib.showContext('court_case')
end

function Menus.Docket()
    local res = lib.callback.await('som-court:server:docket', false)
    if not res or not res.success then
        return notify(res and res.error or 'Request failed', 'error')
    end

    local options = {}
    for _, case in ipairs(res.cases) do
        options[#options + 1] = {
            title = caseTitle(case),
            description = ('%s, defendant %s'):format(case.status, case.defendant_cid),
            onSelect = function() showCase(res.role, case) end,
        }
    end
    if #options == 0 then options[1] = { title = 'No cases', disabled = true } end

    lib.registerContext({ id = 'court_docket', title = 'Docket', options = options })
    lib.showContext('court_docket')
end

function Menus.MyCases()
    local res = lib.callback.await('som-court:server:myCases', false)
    if not res or not res.success then
        return notify(res and res.error or 'Request failed', 'error')
    end

    local options = {}
    for _, case in ipairs(res.cases) do
        options[#options + 1] = {
            title = caseTitle(case),
            description = case.status,
            disabled = true,
        }
    end
    if #options == 0 then options[1] = { title = 'No cases', disabled = true } end

    lib.registerContext({ id = 'court_mine', title = 'My cases', options = options })
    lib.showContext('court_mine')
end

function Menus.File(target)
    local choices = {}
    for key, class in pairs(Config.Classes) do
        choices[#choices + 1] = { value = key, label = class.label }
    end

    local answer = lib.inputDialog('File a court case', {
        { type = 'select', label = 'Class', options = choices, required = true },
        { type = 'input', label = 'Charges', required = true },
        { type = 'number', label = 'Incident number (optional)', min = 0 },
    })
    if not answer then return end

    local res = lib.callback.await('som-court:server:file', false, {
        target = target,
        class = answer[1],
        charges = answer[2],
        incidentId = answer[3],
    })

    notify(res and (res.success and ('Case #%d filed'):format(res.id) or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
end
