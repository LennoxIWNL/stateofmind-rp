--- Hourly checks and a daily digest (the sink to faucet ratio is judged in the digest, a single hour is too noisy) over som_transactions. Read only: it moves
--- no money and changes nothing. A message names a citizenid, an amount and a
--- reason and never anything else about a player.

local core = exports['som-core']

Watch = {}

local lastAlert = {}

local function num(value) return tonumber(value) or 0 end

local function post(text)
    print('[som-economy] ' .. text:gsub('\n', '\n[som-economy] '))

    local url = GetConvar('som_economy_webhook', '')
    if url == '' then return end

    PerformHttpRequest(url, function() end, 'POST',
        json.encode({ content = text:sub(1, 1900), allowed_mentions = { parse = {} } }),
        { ['Content-Type'] = 'application/json' })
end

---Reasons are composed by our own resources; this keeps a stray mention, control character or line break out anyway.
local function plain(value)
    return (tostring(value or ''):gsub('[^%w%s%p]', ''):gsub('[@<>\96]', ''):gsub('%s+', ' '):sub(1, 64))
end

local function totals(minutes)
    local out = { faucet = 0, sink = 0 }
    local rows = MySQL.query.await(
        "SELECT flow, COALESCE(SUM(amount), 0) AS total FROM som_transactions WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND citizenid IS NOT NULL AND flow IN ('faucet', 'sink') GROUP BY flow",
        { minutes }) or {}
    for _, row in ipairs(rows) do out[row.flow] = num(row.total) end
    return out
end

local function sources(minutes, flow)
    local parts = {}
    local rows = MySQL.query.await(
        "SELECT SUBSTRING_INDEX(reason, ':', 1) AS reason, COALESCE(SUM(amount), 0) AS total FROM som_transactions WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND citizenid IS NOT NULL AND flow = ? GROUP BY SUBSTRING_INDEX(reason, ':', 1) ORDER BY total DESC LIMIT ?",
        { minutes, flow, Config.Watch.top }) or {}
    for _, row in ipairs(rows) do parts[#parts + 1] = ('%s %d'):format(plain(row.reason), num(row.total)) end
    return #parts > 0 and table.concat(parts, ', ') or 'none'
end

---Characters who took in at least `least` through `flow` in the window, biggest first, with the reason that paid most.
---Two bounded queries: the top `limit` totals, then the reasons of just those characters.
local function earners(minutes, flow, least, limit)
    local out, byCitizen, marks = {}, {}, {}
    local top = MySQL.query.await(
        "SELECT citizenid, COALESCE(SUM(amount), 0) AS total FROM som_transactions WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND citizenid IS NOT NULL AND flow = ? AND direction = 'credit' GROUP BY citizenid HAVING total >= ? ORDER BY total DESC LIMIT ?",
        { minutes, flow, least, limit }) or {}
    if #top == 0 then return out end

    local params = { minutes, flow }
    for _, row in ipairs(top) do
        local e = { citizenid = plain(row.citizenid), total = num(row.total), best = -1 }
        out[#out + 1], byCitizen[row.citizenid] = e, e
        marks[#marks + 1] = '?'
        params[#params + 1] = row.citizenid
    end

    local parts = MySQL.query.await(
        "SELECT citizenid, SUBSTRING_INDEX(reason, ':', 1) AS reason, COALESCE(SUM(amount), 0) AS total FROM som_transactions WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND flow = ? AND direction = 'credit' AND citizenid IN (" .. table.concat(marks, ', ') .. ") GROUP BY citizenid, SUBSTRING_INDEX(reason, ':', 1)",
        params) or {}
    for _, row in ipairs(parts) do
        local e, part = byCitizen[row.citizenid], num(row.total)
        if e and part > e.best then e.best, e.reason = part, plain(row.reason) end
    end
    return out
end

local function alert(key, text)
    local now = GetGameTimer()
    if lastAlert[key] and now - lastAlert[key] < Config.Watch.alertCooldownMinutes * 60000 then return false end
    lastAlert[key] = now
    post('ALERT ' .. text)
    return true
end

---Looks at the last check window and raises an alert for anything outside the limits.
function Watch.Check()
    local W, minutes = Config.Watch, Config.Watch.checkMinutes
    local sent = 0
    local function raise(key, text) if alert(key, text) then sent = sent + 1 end end

    for _, e in ipairs(earners(minutes, 'faucet', W.citizenFaucetLimit, 5)) do
        raise('faucet:' .. e.citizenid, ('%s received %d from faucets in %d min, mostly %s'):format(e.citizenid, e.total, minutes, e.reason))
    end
    for _, e in ipairs(earners(minutes, 'transfer', W.citizenTransferInLimit, 5)) do
        raise('transfer:' .. e.citizenid, ('%s received %d in transfers in %d min, mostly %s'):format(e.citizenid, e.total, minutes, e.reason))
    end

    local big = MySQL.single.await(
        "SELECT citizenid, amount, reason FROM som_transactions WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) AND flow = 'faucet' AND amount >= ? ORDER BY amount DESC LIMIT 1",
        { minutes, W.singleRowLimit })
    if big then
        raise('row:' .. plain(big.citizenid or 'treasury'), ('one faucet payment of %d to %s for %s'):format(num(big.amount), plain(big.citizenid or 'treasury'), plain(big.reason)))
    end

    local balance = num(core:getTreasury())
    if W.treasuryFloor > 0 and balance < W.treasuryFloor then
        raise('treasury', ('the treasury holds %d, under the floor of %d'):format(balance, W.treasuryFloor))
    end

    return sent
end

---The faucet and sink picture for the last `hours` hours, as text.
function Watch.Digest(hours)
    local minutes = hours * 60
    local t = totals(minutes)
    local lines = { ('Economy, last %d h'):format(hours) }

    local ratio = t.faucet > 0 and ('%.2f'):format(t.sink / t.faucet) or 'n/a'
    lines[#lines + 1] = ('faucet %d, sink %d, ratio %s (target %.2f)'):format(t.faucet, t.sink, ratio, Config.Balance.targetSinkFaucetRatio)
    if t.faucet > 0 and math.abs(t.sink / t.faucet - Config.Balance.targetSinkFaucetRatio) > Config.Balance.warnDeviation then
        lines[#lines + 1] = 'WARNING: the ratio is outside the target band'
    end
    lines[#lines + 1] = ('treasury %d'):format(num(core:getTreasury()))
    lines[#lines + 1] = 'top faucets: ' .. sources(minutes, 'faucet')
    lines[#lines + 1] = 'top sinks: ' .. sources(minutes, 'sink')

    local top = {}
    for _, e in ipairs(earners(minutes, 'faucet', 1, 5)) do top[#top + 1] = ('%s %d (%s)'):format(e.citizenid, e.total, e.reason) end
    lines[#lines + 1] = 'top earners: ' .. (#top > 0 and table.concat(top, ', ') or 'none')

    return table.concat(lines, '\n')
end

lib.addCommand('economyreport', {
    help = 'Post the faucet and sink digest (hours, default 24)',
    params = { { name = 'hours', type = 'number', optional = true } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    end

    local hours = math.floor(tonumber(args.hours) or 24)
    if hours < 1 or hours > 168 then hours = 24 end
    post(Watch.Digest(hours))
end)

CreateThread(function()
    Wait(60000)
    local every = math.max(1, (Config.Watch.digestHours * 60) // Config.Watch.checkMinutes)
    local ticks = 0
    while true do
        Wait(Config.Watch.checkMinutes * 60000)
        local ok, err = pcall(Watch.Check)
        if not ok then print('[som-economy] watch check failed: ' .. tostring(err)) end

        ticks = ticks + 1
        if ticks % every == 0 then
            local done, failure = pcall(function() post(Watch.Digest(Config.Watch.digestHours)) end)
            if not done then print('[som-economy] watch digest failed: ' .. tostring(failure)) end
        end
    end
end)
