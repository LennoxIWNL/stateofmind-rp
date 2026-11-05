--- /somhealth: one command that says whether the server is wired up. It checks
--- that every own resource is started, the database answers, every table
--- setup.sql defines exists, every item the code uses exists, and the convars
--- the server needs are set. Run it first on every boot. Staff or the console
--- only. Made by Lennox.

local core = exports['som-core']

Health = {}

local REQUIRED_CONVARS = {
    { name = 'som_phone_pepper', level = 'FAIL', note = 'phone passcodes are hashed with this; set it in server.cfg' },
}
local OPTIONAL_CONVARS = {
    { name = 'som_phone_webhook', note = 'phone moderation log' },
    { name = 'som_heist_webhook', note = 'heist log' },
    { name = 'som_launder_webhook', note = 'launder log' },
    { name = 'lac_webhook_bans', note = 'anti-cheat ban log' },
}

---Pure: turns a snapshot of the server into result rows, so it can be tested.
---@param snap table { states, dbOk, tables (set), items (name -> bool), convars (name -> string), lists }
---@return table[] rows { level = 'PASS'|'WARN'|'FAIL', text }
function Health.Evaluate(snap)
    local rows = {}
    local function row(level, text) rows[#rows + 1] = { level = level, text = text } end

    local down = {}
    for _, name in ipairs(snap.lists.resources) do
        if snap.states[name] ~= 'started' then down[#down + 1] = ('%s (%s)'):format(name, snap.states[name] or 'missing') end
    end
    if #down == 0 then row('PASS', ('all %d resources are started'):format(#snap.lists.resources))
    else row('FAIL', 'not started: ' .. table.concat(down, ', ')) end

    if not snap.dbOk then
        row('FAIL', 'the database did not answer')
    else
        row('PASS', 'the database answers')
        local missing = {}
        for _, t in ipairs(snap.lists.tables) do if not snap.tables[t] then missing[#missing + 1] = t end end
        if #missing == 0 then row('PASS', ('all %d tables exist'):format(#snap.lists.tables))
        else row('FAIL', ('%d tables missing, import setup.sql: %s'):format(#missing, table.concat(missing, ', '))) end
    end

    local noItem = {}
    for _, name in ipairs(snap.lists.items) do if not snap.items[name] then noItem[#noItem + 1] = name end end
    if #noItem == 0 then row('PASS', ('all %d items exist'):format(#snap.lists.items))
    else row('FAIL', 'items missing from ox_inventory: ' .. table.concat(noItem, ', ')) end

    for _, c in ipairs(REQUIRED_CONVARS) do
        if (snap.convars[c.name] or '') == '' then row(c.level, ('%s is not set: %s'):format(c.name, c.note)) end
    end
    for _, c in ipairs(OPTIONAL_CONVARS) do
        if (snap.convars[c.name] or '') == '' then row('WARN', ('%s is not set (%s)'):format(c.name, c.note)) end
    end
    local wl = snap.convars.som_whitelist
    if wl == '1' or wl == 'true' then row('PASS', 'the whitelist is on')
    else row('WARN', 'the whitelist is OFF (set som_whitelist 1 before opening)') end

    return rows
end

function Health.Snapshot()
    local snap = { states = {}, tables = {}, items = {}, convars = {}, lists = HealthLists }
    for _, name in ipairs(HealthLists.resources) do snap.states[name] = GetResourceState(name) end

    local ok, one = pcall(MySQL.scalar.await, 'SELECT 1')
    snap.dbOk = ok and one == 1
    if snap.dbOk then
        for _, r in ipairs(MySQL.query.await(
            "SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name LIKE 'som\\_%'") or {}) do
            snap.tables[r.name:lower()] = true
        end
    end

    for _, name in ipairs(HealthLists.items) do
        local okItem, def = pcall(function() return exports.ox_inventory:Items(name) end)
        snap.items[name] = okItem and def ~= nil and def ~= false
    end
    for _, c in ipairs(REQUIRED_CONVARS) do snap.convars[c.name] = GetConvar(c.name, '') end
    for _, c in ipairs(OPTIONAL_CONVARS) do snap.convars[c.name] = GetConvar(c.name, '') end
    snap.convars.som_whitelist = GetConvar('som_whitelist', 'false')
    return snap
end

function Health.Run() return Health.Evaluate(Health.Snapshot()) end

local function print_rows(rows)
    local fails = 0
    for _, r in ipairs(rows) do
        if r.level == 'FAIL' then fails = fails + 1 end
        print(('[somhealth] %s %s'):format(r.level, r.text))
    end
    print(('[somhealth] %d problems that stop a launch'):format(fails))
    return fails
end

lib.addCommand('somhealth', { help = 'Check that the server is wired up (resources, database, tables, items, convars)' }, function(source)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    end
    local rows = Health.Run()
    local fails = print_rows(rows)
    if source ~= 0 then
        TriggerClientEvent('som:client:notify', source, fails == 0 and 'Health check passed, details in the server console' or ('%d problems, see the server console'):format(fails), fails == 0 and 'success' or 'error')
    end
end)

exports('health', function() return Health.Run() end)
