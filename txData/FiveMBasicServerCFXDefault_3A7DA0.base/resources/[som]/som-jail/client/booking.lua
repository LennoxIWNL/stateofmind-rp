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

                local answer = lib.inputDialog('Book into jail', {
                    { type = 'number', label = 'Sentence (months)',
                      min = 1, max = Config.Cell.maxMonths, default = 1, required = true },
                    { type = 'input', label = 'Charges', required = false },
                })
                if not answer or not answer[1] then return end

                local res = lib.callback.await('som-jail:server:book', false, {
                    target = target,
                    months = answer[1],
                    charges = answer[2],
                })

                if res and res.success then
                    TriggerEvent('som:client:notify',
                        ('Booked for %d month(s)'):format(res.months), 'success')
                else
                    TriggerEvent('som:client:notify',
                        res and res.error or 'could not book them', 'error')
                end
            end,
        },
    })
end)
