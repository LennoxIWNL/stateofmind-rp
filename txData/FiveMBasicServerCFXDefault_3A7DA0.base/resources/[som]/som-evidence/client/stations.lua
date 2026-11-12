--- The locker and the lab. Both are menus over what the server lists for the
--- station; nothing here names a stash or trusts a state.

local function notify(res)
    TriggerEvent('som:client:notify', res and (res.success and 'Done' or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
end

local function title(row)
    return ('#%d %s%s'):format(row.id, Config.Kinds[row.kind].label, row.case_id and (' (case ' .. row.case_id .. ')') or '')
end

local Menu

local function call(name, stationKey, point, ...)
    notify(lib.callback.await(name, false, stationKey, ...))
    Menu(stationKey, point)
end

local function linkDialog(stationKey, point, row)
    local answer = lib.inputDialog('Link to a court case', {
        { type = 'number', label = 'Case number', min = 1, required = true },
    })
    if answer then call('som-evidence:server:link', stationKey, point, row.id, answer[1]) end
end

local function resultDialog(stationKey, row)
    local res = lib.callback.await('som-evidence:server:result', false, stationKey, row.id)
    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Request failed', 'error')
    end

    local r = res.result
    local text = r.match and ('Matches citizen %s'):format(r.match)
        or r.profile and ('Unknown profile %s, no match on file'):format(r.profile)
        or r.serial and ('Weapon serial %s'):format(r.serial) or 'No identifying information'

    lib.alertDialog({ header = r.kind, content = text, centered = true })
end

Menu = function(stationKey, point)
    local res = lib.callback.await('som-evidence:server:locker', false, stationKey, point)
    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Request failed', 'error')
    end

    local options = {}

    for _, row in ipairs(res.held) do
        if point == 'locker' then
            options[#options + 1] = { title = 'Lock up ' .. title(row),
                onSelect = function() call('som-evidence:server:store', stationKey, point, row.id) end }
        else
            options[#options + 1] = { title = 'Analyse ' .. title(row),
                onSelect = function() call('som-evidence:server:analyse', stationKey, point, row.id) end }
        end
    end

    for _, row in ipairs(res.stored) do
        if point == 'locker' then
            options[#options + 1] = { title = 'Check out ' .. title(row),
                onSelect = function() call('som-evidence:server:checkout', stationKey, point, row.id) end }
            options[#options + 1] = { title = 'Link to case ' .. title(row),
                onSelect = function() linkDialog(stationKey, point, row) end }
        else
            options[#options + 1] = { title = 'Analyse ' .. title(row),
                onSelect = function() call('som-evidence:server:analyse', stationKey, point, row.id) end }
            if row.analysed_at then
                options[#options + 1] = { title = 'Read result ' .. title(row),
                    onSelect = function() resultDialog(stationKey, row) end }
            end
        end
    end

    if #options == 0 then options[1] = { title = 'Nothing here', disabled = true } end

    lib.registerContext({ id = 'evidence_' .. point, title = point == 'lab' and 'Lab' or 'Evidence locker', options = options })
    lib.showContext('evidence_' .. point)
end

CreateThread(function()
    for key, station in pairs(Config.Stations) do
        for _, point in ipairs({ 'locker', 'lab' }) do
            exports['som-interact']:addSphereZone({
                name = ('evidence:%s:%s'):format(key, point),
                coords = station[point],
                radius = station.range,
                options = {
                    {
                        name = ('evidence:%s:%s'):format(key, point),
                        icon = point == 'lab' and 'fa-solid fa-flask' or 'fa-solid fa-box-archive',
                        label = point == 'lab' and 'Evidence lab' or 'Evidence locker',
                        distance = station.range,
                        onSelect = function() Menu(key, point) end,
                    },
                },
            })
        end
    end
end)
