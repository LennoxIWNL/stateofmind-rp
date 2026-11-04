--- The staff menu and spectate. Nothing here is trusted: every action goes
--- back to the server, which checks permission again.

local spectating = false

local function stopSpectate()
    if spectating then NetworkSetInSpectatorMode(false, PlayerPedId()) end
    spectating = false
end

RegisterNetEvent('som-staff:client:spectate', function(target)
    if not target then return stopSpectate() end
    local player = GetPlayerFromServerId(target)
    if player == -1 then return end
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    spectating = true
end)

RegisterCommand('reports', function()
    local rows = lib.callback.await('som-staff:server:reports', false)
    if type(rows) ~= 'table' then return end

    local options = {}
    for _, r in ipairs(rows) do
        options[#options + 1] = {
            title = ('#%d %s'):format(r.id, r.name),
            description = r.message,
            metadata = { { label = 'Status', value = r.status } },
            onSelect = function()
                lib.registerContext({
                    id = 'som_staff_report', title = ('Report #%d'):format(r.id),
                    options = {
                        { title = 'Claim', onSelect = function() lib.callback.await('som-staff:server:reportAction', false, r.id, 'claim') end },
                        { title = 'Close', onSelect = function() lib.callback.await('som-staff:server:reportAction', false, r.id, 'close') end },
                    },
                })
                lib.showContext('som_staff_report')
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'No open reports' } end
    lib.registerContext({ id = 'som_staff_reports', title = 'Reports', options = options })
    lib.showContext('som_staff_reports')
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then stopSpectate() end
end)
