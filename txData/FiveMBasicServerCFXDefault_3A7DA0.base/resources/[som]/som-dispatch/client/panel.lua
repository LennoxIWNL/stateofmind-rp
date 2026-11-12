--- The board: a menu of open calls and what the caller may do with each. It
--- only offers; the server checks the job, duty, grade and call on every action.

local function notify(res)
    TriggerEvent('som:client:notify', res and (res.success and 'Done' or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
end

local Board

local function act(name, ...)
    notify(lib.callback.await(name, false, ...))
    Board()
end

local function assignMenu(call)
    local res = lib.callback.await('som-dispatch:server:units', false, call.id)
    if not res or not res.success then return notify(res) end

    local options = {}
    for _, unit in ipairs(res.units) do
        options[#options + 1] = {
            title = unit.name,
            onSelect = function() act('som-dispatch:server:assign', call.id, unit.source) end,
        }
    end
    if #options == 0 then options[1] = { title = 'No free units', disabled = true } end

    lib.registerContext({ id = 'dispatch_assign', title = 'Assign a unit', options = options })
    lib.showContext('dispatch_assign')
end

local function callMenu(role, call)
    local options = {}
    local function add(title, fn) options[#options + 1] = { title = title, onSelect = fn } end

    if role ~= 'dispatcher' then
        if call.mine then
            add('Leave the call', function() act('som-dispatch:server:detach', call.id) end)
        else
            add('Respond', function() act('som-dispatch:server:attach', call.id) end)
        end
    end

    if role == 'dispatcher' or role == 'supervisor' then
        add('Assign a unit', function() assignMenu(call) end)
        add(call.major and 'Stand down major incident' or 'Declare major incident',
            function() act('som-dispatch:server:major', call.id, not call.major) end)
    end

    add('Close', function() act('som-dispatch:server:close', call.id) end)
    add('Back', function() Board() end)

    lib.registerContext({
        id = 'dispatch_call',
        title = ('%s %s'):format(call.code or '', call.label),
        options = options,
    })
    lib.showContext('dispatch_call')
end

Board = function()
    local res = lib.callback.await('som-dispatch:server:board', false)
    if not res or not res.success then return notify(res) end

    local options = {}
    for _, call in ipairs(res.calls) do
        local flags = {}
        if call.major then flags[#flags + 1] = 'MAJOR' end
        if call.unattended then flags[#flags + 1] = 'unattended' end
        if call.count > 1 then flags[#flags + 1] = ('x%d reports'):format(call.count) end

        options[#options + 1] = {
            title = ('P%d %s %s'):format(call.priority, call.code or '', call.label),
            description = ('%d unit(s)%s'):format(call.units, #flags > 0 and (', ' .. table.concat(flags, ', ')) or ''),
            onSelect = function() callMenu(res.role, call) end,
        }
    end
    if #options == 0 then options[1] = { title = 'No open calls', disabled = true } end

    lib.registerContext({ id = 'dispatch_board', title = 'Dispatch board', options = options })
    lib.showContext('dispatch_board')
end

RegisterCommand('dispatch', Board, false)
