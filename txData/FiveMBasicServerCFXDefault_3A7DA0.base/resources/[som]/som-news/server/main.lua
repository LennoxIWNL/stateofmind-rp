--- Weazel News. Reporters publish through the phone app; the server decides who
--- may, who the author is and what is paid. A story pays out of the city
--- treasury under an hourly cap recorded in som_news_payouts, so a restart
--- cannot reset it. Debit the treasury first, credit the reporter second,
--- refund if the credit fails.

local core = exports['som-core']

local busy = false

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function clean(value, maxLength)
    if type(value) ~= 'string' then return nil end

    local text = value:gsub('[<>]', ''):gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
    if text == '' then return nil end

    return text:sub(1, maxLength)
end

local function isReporter(player)
    return player.job and player.job.name == Config.job and player.job.onduty == true
end

---Pays for one story, or returns 0. Never raises money from nowhere: the
---treasury is debited first and put back if anything after it fails.
local function pay(source, player, storyId)
    local p = Config.pay
    if busy then return 0 end
    busy = true

    local state = { debited = 0, paid = 0 }
    local ok, err = pcall(function()
        local spent = tonumber(MySQL.scalar.await(
            'SELECT COALESCE(SUM(amount), 0) FROM som_news_payouts WHERE created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)')) or 0
        local mine = tonumber(MySQL.scalar.await(
            'SELECT COALESCE(SUM(amount), 0) FROM som_news_payouts WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)',
            { player.citizenid })) or 0

        local amount = math.min(p.perStory, p.hourlyCap - spent, p.perReporterHourly - mine)
        if amount < 1 then return end

        state.reason = 'news:story:' .. storyId
        if not core:treasuryTransact(-amount, state.reason) then return end
        state.debited = amount

        -- The caps read these rows, so the record exists before the money does.
        state.payoutId = MySQL.insert.await(
            'INSERT INTO som_news_payouts (citizenid, amount) VALUES (?, ?)', { player.citizenid, amount })

        if not core:addMoney(source, 'bank', amount, state.reason) then return end
        state.paid = amount
        MySQL.update.await('UPDATE som_news_stories SET paid = ? WHERE id = ?', { amount, storyId })
    end)

    if state.paid == 0 then
        if state.payoutId then pcall(MySQL.update.await, 'DELETE FROM som_news_payouts WHERE id = ?', { state.payoutId }) end
        if state.debited > 0 then core:treasuryTransact(state.debited, state.reason .. ':refund') end
    end
    busy = false

    if not ok then print(('[som-news] payout for story %s failed: %s'):format(storyId, tostring(err))) end
    return state.paid
end

local function age(minutes)
    minutes = tonumber(minutes) or 0
    if minutes < 1 then return 'just now' end
    if minutes < 60 then return ('%d min ago'):format(minutes) end
    if minutes < 1440 then return ('%d h ago'):format(minutes // 60) end
    return ('%d d ago'):format(minutes // 1440)
end

local actions = {}

function actions.view(_, _, player)
    local rows = MySQL.query.await([[
        SELECT id, author, kind, headline, body, TIMESTAMPDIFF(MINUTE, created_at, NOW()) AS age
        FROM som_news_stories WHERE status = 'live' ORDER BY id DESC LIMIT ?
    ]], { Config.feedSize }) or {}

    local breaking, latest = {}, {}
    for _, row in ipairs(rows) do
        local entry = { title = row.headline, sub = ('%s (%s, %s)'):format(row.body, row.author, age(row.age)) }
        local fresh = row.kind == 'breaking' and (tonumber(row.age) or 0) <= Config.breakingWindowMinutes
        local list = fresh and breaking or latest
        list[#list + 1] = entry
    end

    local view = {
        sections = {
            { title = 'Breaking', rows = breaking },
            { title = 'Latest', rows = latest },
        },
        empty = 'No news right now',
    }

    if Config.enabled and isReporter(player) then
        local prompt = { field = 'text', label = 'Headline | story', maxLength = Config.headline.max + Config.body.max + 3 }
        view.buttons = {
            { label = 'Publish story', action = 'publish', payload = { kind = 'story' }, prompt = prompt },
            { label = 'Breaking alert', action = 'publish', payload = { kind = 'breaking' }, prompt = prompt },
        }
    end

    return { success = true, view = view }
end

function actions.publish(source, payload, player)
    if not Config.enabled then return done(false, 'the newsroom is closed') end
    if not isReporter(player) then return done(false, 'only reporters on duty can publish') end

    local kind = payload.kind
    if kind ~= 'story' and kind ~= 'breaking' then return done(false, 'bad request') end

    -- shortcut: the phone prompt takes one line, so headline and story share it split at the first bar. Upgrade when the host view gets multi field prompts.
    local text = clean(payload.text, Config.headline.max + Config.body.max + 3)
    local headline, body = (text or ''):match('^(.-)%s*|%s*(.+)$')
    if not headline then return done(false, 'write it as: headline | story') end
    headline, body = clean(headline, Config.headline.max), clean(body, Config.body.max)
    if not headline or #headline < Config.headline.min then return done(false, 'the headline is too short') end
    if not body or #body < Config.body.min then return done(false, 'a story needs more than that') end

    local last = MySQL.single.await(
        'SELECT headline, body FROM som_news_stories WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { player.citizenid })
    if last and last.headline:lower() == headline:lower() and last.body:lower() == body:lower() then
        return done(false, 'you already published that')
    end

    local author = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
    local id = MySQL.insert.await([[
        INSERT INTO som_news_stories (citizenid, author, kind, headline, body)
        SELECT ?, ?, ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (
            SELECT 1 FROM som_news_stories WHERE citizenid = ? AND kind = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)
        )
    ]], { player.citizenid, author, kind, headline, body, player.citizenid, kind, Config.gapSeconds[kind] })
    if not id or id < 1 then return done(false, 'slow down') end

    local paid = kind == 'story' and pay(source, player, id) or 0

    if kind == 'breaking' then
        for _, other in ipairs(core:getPlayers()) do
            exports['som-phone']:notifyApp(other.source, 'news', headline)
        end
    end

    return done(true, nil, { id = id, paid = paid })
end

exports['som-phone']:registerApp({
    id = 'news', label = 'Weazel News', icon = 'briefcase', colour = '#d62828', order = 27,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end

        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

-- Registered unrestricted and checked inside, as /removepost is.
lib.addCommand('removestory', {
    help = 'Remove a Weazel News story',
    params = { { name = 'id', type = 'number' } },
}, function(source, args)
    local function say(text)
        if source ~= 0 then TriggerClientEvent('som:client:notify', source, text, 'inform') else print('[som-news] ' .. text) end
    end

    if source ~= 0 and not core:hasPermission(source, 'som.mod') then return say('You do not have permission to do that') end

    local gone = MySQL.update.await("UPDATE som_news_stories SET status = 'removed' WHERE id = ? AND status = 'live'", { args.id })

    local staff = source ~= 0 and core:getPlayer(source) or nil
    MySQL.insert.await('INSERT INTO som_phone_audit (citizenid, app, action, ok) VALUES (?, ?, ?, ?)',
        { staff and staff.citizenid or 'console', 'moderation', ('remove story %d'):format(args.id), gone == 1 and 1 or 0 })

    say(gone == 1 and 'Removed' or 'Nothing to remove')
end)
