--- The officer side: "Book into jail" on a cuffed player. The server
--- re-validates duty, distance and cuffed state.

local function serverIdOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'jail:book',
            icon = 'fa-solid fa-building-shield',
            label = 'Book into jail',
            distance = 3.0,
            onSelect = function(data)
                local target = serverIdOf(data.entity)
                if not target then return end

                local opts = lib.callback.await('som-jail:server:bookOptions', false, target)
                if not opts or not opts.success then
                    return TriggerEvent('som:client:notify', opts and opts.error or 'could not load their cases', 'error')
                end

                local choices = { { value = 0, label = ('No case (up to %d months)'):format(opts.directMax) } }
                for _, case in ipairs(opts.cases) do
                    local custody = case.status == 'convicted'
                    choices[#choices + 1] = {
                        value = case.id,
                        label = ('#%d %s: %s (%s)'):format(case.id, case.class, case.charges:sub(1, 40),
                            custody and (case.sentence_months .. ' mo, carry out') or 'hold pending trial'),
                    }
                end

                local answer = lib.inputDialog(opts.warrants > 0 and 'Book (ACTIVE WARRANT)' or 'Book into jail', {
                    { type = 'select', label = 'Case', options = choices, default = 0, required = true },
                    { type = 'number', label = 'Months (no case only)', min = 1, max = opts.directMax, default = 1 },
                    { type = 'input', label = 'Charges', required = false },
                })
                if not answer then return end

                local res = lib.callback.await('som-jail:server:book', false, {
                    target = target,
                    caseId = tonumber(answer[1]) or 0,
                    months = answer[2],
                    charges = answer[3],
                })

                if res and res.success then
                    TriggerEvent('som:client:notify',
                        res.remand and 'Held pending trial' or ('Booked for %d month(s)'):format(res.months), 'success')
                else
                    TriggerEvent('som:client:notify',
                        res and res.error or 'could not book them', 'error')
                end
            end,
        },
    })
end)
