--- The public feed (Chirp) and Pages. Both are apps on the pipeline. What a
--- post says, who it is from and what it links to are decided here: a client
--- sends text and ids, never a handle, a business or a number.

local core = exports['som-core']

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

local function log(text)
    local url = GetConvar('som_phone_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
end

---An https image URL on a configured host, or nil.
---@param url any
---@return string|nil
local function imageUrl(url)
    if type(url) ~= 'string' or #url > 255 or url:find('[%s"\'<>]') then return nil end

    local host = url:match('^https://([%w%.%-]+)/')
    if not host then return nil end

    for _, allowed in ipairs(Config.Social.imageHosts) do
        if host == allowed then return url end
    end
end

---The business a character may speak for right now, or nil.
---@param player table
---@return string|nil name, string|nil label
local function speaksFor(player)
    if not (player.job and player.job.isboss and player.job.onduty) then return nil end

    local def = core:getJobs()[player.job.name]
    local name = def and def.business
    if not name then return nil end

    local row = exports['som-economy']:getBusiness(name)
    return name, row and row.label or name
end

-- ---------------------------------------------------------------------------
-- Handles
-- ---------------------------------------------------------------------------

local function reserved(handle)
    for _, word in ipairs(Config.Social.reserved) do
        if handle == word or handle:sub(1, #word) == word then return true end
    end
    return false
end

---The character's handle, made from their name on first use.
---@param player table
---@return table row { handle, colour }
local function handleOf(player)
    local row = MySQL.single.await('SELECT handle, colour FROM som_phone_handles WHERE citizenid = ?', { player.citizenid })
    if row then return row end

    local base = (player.charinfo.firstname .. player.charinfo.lastname):lower():gsub('[^a-z]', ''):sub(1, 12)
    if #base < 3 then base = 'user' end

    for _ = 1, 20 do
        local handle = base .. math.random(10, 99)
        local ok, id = pcall(MySQL.insert.await,
            'INSERT INTO som_phone_handles (citizenid, handle) VALUES (?, ?)', { player.citizenid, handle })
        if ok and id ~= nil then return { handle = handle } end
    end

    error('could not allocate a handle')
end

-- ---------------------------------------------------------------------------
-- Chirp
-- ---------------------------------------------------------------------------

---@param rows table[]
---@param player table
local function decorate(rows, player)
    for _, row in ipairs(rows) do
        row.mine = row.citizenid == player.citizenid
        row.liked = MySQL.scalar.await('SELECT 1 FROM som_phone_likes WHERE post_id = ? AND citizenid = ?', { row.id, player.citizenid }) ~= nil
        row.citizenid = nil
    end
    return rows
end

Phone.Register({
    id = 'chirp', label = 'Chirp', icon = 'twitter', colour = '#1da1f2', order = 25,
    actions = {
        feed = { fn = function(_, _, player)
            local rows = MySQL.query.await([[
                SELECT p.id, p.citizenid, h.handle, h.colour, p.business, p.body, p.image, p.likes, p.reply_to, p.created_at,
                       (SELECT COUNT(*) FROM som_phone_posts r WHERE r.reply_to = p.id AND r.removed = 0) AS replies
                FROM som_phone_posts p JOIN som_phone_handles h ON h.citizenid = p.citizenid
                WHERE p.removed = 0 AND p.reply_to IS NULL ORDER BY p.id DESC LIMIT ?
            ]], { Config.Social.feedSize }) or {}

            local me = handleOf(player)
            local _, business = speaksFor(player)
            return { posts = decorate(rows, player), me = { handle = me.handle, colour = me.colour, business = business } }
        end },
        thread = { fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            if id < 1 then return done(false, 'no such post') end

            local rows = MySQL.query.await([[
                SELECT p.id, p.citizenid, h.handle, h.colour, p.business, p.body, p.image, p.likes, p.reply_to, p.created_at, 0 AS replies
                FROM som_phone_posts p JOIN som_phone_handles h ON h.citizenid = p.citizenid
                WHERE p.removed = 0 AND (p.id = ? OR p.reply_to = ?) ORDER BY p.id LIMIT ?
            ]], { id, id, Config.Social.replySize }) or {}

            if #rows == 0 then return done(false, 'no such post') end
            return { posts = decorate(rows, player) }
        end },
        post = { writes = true, fn = function(_, payload, player)
            local body = clean(payload.body, Config.Social.postLength)
            if not body then return done(false, 'write something first') end

            local image
            if payload.image ~= nil and payload.image ~= '' then
                image = imageUrl(payload.image)
                if not image then return done(false, 'that image cannot be used') end
            end

            local replyTo
            if payload.replyTo ~= nil then
                replyTo = math.floor(tonumber(payload.replyTo) or 0)
                local parent = MySQL.scalar.await('SELECT id FROM som_phone_posts WHERE id = ? AND removed = 0 AND reply_to IS NULL', { replyTo })
                if not parent then return done(false, 'that post is gone') end
            end

            local recent = MySQL.single.await(
                'SELECT COUNT(*) AS day, COALESCE(MAX(UNIX_TIMESTAMP(created_at)), 0) AS last FROM som_phone_posts WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)',
                { player.citizenid }) or { day = 0, last = 0 }
            if (tonumber(recent.day) or 0) >= Config.Social.postsPerDay then return done(false, 'you have posted enough for today') end
            if os.time() - (tonumber(recent.last) or 0) < Config.Social.postGapSeconds then return done(false, 'slow down') end

            handleOf(player)

            local business
            if payload.asBusiness == true then
                local _, label = speaksFor(player)
                if not label then return done(false, 'you cannot post for a business right now') end
                business = label
            end

            local id = MySQL.insert.await(
                'INSERT INTO som_phone_posts (citizenid, business, body, image, reply_to) VALUES (?, ?, ?, ?, ?)',
                { player.citizenid, business, body, image, replyTo })

            return { id = id }
        end },
        like = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            if not MySQL.scalar.await('SELECT id FROM som_phone_posts WHERE id = ? AND removed = 0', { id }) then
                return done(false, 'that post is gone')
            end

            if MySQL.update.await('INSERT IGNORE INTO som_phone_likes (post_id, citizenid) VALUES (?, ?)', { id, player.citizenid }) == 1 then
                MySQL.update.await('UPDATE som_phone_posts SET likes = likes + 1 WHERE id = ?', { id })
                return { liked = true }
            end

            if MySQL.update.await('DELETE FROM som_phone_likes WHERE post_id = ? AND citizenid = ?', { id, player.citizenid }) == 1 then
                MySQL.update.await('UPDATE som_phone_posts SET likes = GREATEST(likes - 1, 0) WHERE id = ?', { id })
            end
            return { liked = false }
        end },
        remove = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            local gone = MySQL.update.await(
                'UPDATE som_phone_posts SET removed = 1 WHERE id = ? AND citizenid = ? AND removed = 0', { id, player.citizenid })
            return gone == 1 and { success = true } or done(false, 'that is not your post')
        end },
        report = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            local post = MySQL.single.await('SELECT citizenid, body FROM som_phone_posts WHERE id = ? AND removed = 0', { id })
            if not post then return done(false, 'that post is gone') end
            if post.citizenid == player.citizenid then return done(false, 'you cannot report your own post') end

            local reason = clean(payload.reason, 120) or 'no reason given'
            local fresh = MySQL.update.await(
                'INSERT IGNORE INTO som_phone_reports (post_id, citizenid, reason) VALUES (?, ?, ?)', { id, player.citizenid, reason })

            if fresh == 1 then log(('chirp report on post #%d: %s | %s'):format(id, reason, post.body)) end
            return { success = true }
        end },
        setHandle = { writes = true, fn = function(source, payload, player)
            if not core:hasPerk(source, 'twitterHandle') then return done(false, 'custom handles are a supporter perk') end

            local handle = type(payload.handle) == 'string' and payload.handle:lower() or ''
            if not handle:match('^[a-z0-9_]+$') or #handle < 3 or #handle > 16 then
                return done(false, 'use 3 to 16 letters, numbers or underscores')
            end
            if reserved(handle) then return done(false, 'that handle is reserved') end

            handleOf(player)

            local recently = MySQL.scalar.await(
                'SELECT 1 FROM som_phone_handles WHERE citizenid = ? AND changed_at > DATE_SUB(NOW(), INTERVAL ? HOUR)',
                { player.citizenid, Config.Social.handleChangeHours })
            if recently then return done(false, 'you changed your handle recently') end

            local ok, rows = pcall(MySQL.update.await,
                'UPDATE som_phone_handles SET handle = ?, changed_at = NOW() WHERE citizenid = ?', { handle, player.citizenid })
            return ok and rows == 1 and { success = true } or done(false, 'that handle is taken')
        end },
        setColour = { writes = true, fn = function(source, payload, player)
            local allowed = tonumber(core:hasPerk(source, 'twitterColour')) or 0
            local colour = type(payload.colour) == 'string' and payload.colour or nil

            if colour ~= nil then
                local ok = false
                for i = 1, math.min(allowed, #Config.Social.colours) do
                    if Config.Social.colours[i] == colour then ok = true end
                end
                if not ok then return done(false, 'that colour is not unlocked') end
            end

            handleOf(player)
            MySQL.update.await('UPDATE som_phone_handles SET colour = ? WHERE citizenid = ?', { colour, player.citizenid })
            return { success = true }
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Pages: adverts and the white pages
-- ---------------------------------------------------------------------------

local function category(value)
    for _, c in ipairs(Config.Pages.categories) do
        if c == value then return c end
    end
end

Phone.Register({
    id = 'pages', label = 'Pages', icon = 'inbox', colour = '#f2c94c', order = 28,
    actions = {
        adverts = { fn = function(_, payload, player)
            local cat = payload.category ~= nil and category(payload.category) or nil
            local rows = MySQL.query.await([[
                SELECT a.id, a.citizenid, a.category, a.title, a.body, a.price, a.show_number, a.business, a.created_at, h.handle
                FROM som_phone_adverts a JOIN som_phone_handles h ON h.citizenid = a.citizenid
                WHERE a.status = 'active' AND a.expires_at > NOW() AND (? IS NULL OR a.category = ?)
                ORDER BY a.id DESC LIMIT ?
            ]], { cat, cat, Config.Pages.feedSize }) or {}

            for _, row in ipairs(rows) do
                row.mine = row.citizenid == player.citizenid
                row.number = row.show_number == 1 and MySQL.scalar.await('SELECT phone FROM som_characters WHERE citizenid = ?', { row.citizenid }) or nil
                row.citizenid, row.show_number = nil, nil
            end

            local _, business = speaksFor(player)
            return { adverts = rows, categories = Config.Pages.categories, business = business }
        end },
        post = { writes = true, fn = function(_, payload, player)
            local cat = category(payload.category)
            local title = clean(payload.title, Config.Pages.titleLength)
            local body = clean(payload.body, Config.Pages.bodyLength)
            if not cat or not title or not body then return done(false, 'a category, a title and a description are needed') end

            local price = clean(payload.price, Config.Pages.priceLength)

            local active = MySQL.single.await(
                "SELECT COUNT(*) AS total, SUM(category = ?) AS here FROM som_phone_adverts WHERE citizenid = ? AND status = 'active' AND expires_at > NOW()",
                { cat, player.citizenid }) or { total = 0, here = 0 }
            if (tonumber(active.total) or 0) >= Config.Pages.maxActive then return done(false, 'you already have the most adverts allowed') end
            if (tonumber(active.here) or 0) >= 1 then return done(false, 'you already have an advert in that category') end

            local business
            if payload.asBusiness == true then
                local _, label = speaksFor(player)
                if not label then return done(false, 'you cannot advertise for a business right now') end
                business = label
            end

            handleOf(player)

            local id = MySQL.insert.await([[
                INSERT INTO som_phone_adverts (citizenid, category, title, body, price, show_number, business, expires_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
            ]], { player.citizenid, cat, title, body, price, payload.showNumber == true and 1 or 0, business, Config.Pages.expireHours })

            return { id = id }
        end },
        remove = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            local gone = MySQL.update.await(
                "UPDATE som_phone_adverts SET status = 'removed' WHERE id = ? AND citizenid = ? AND status = 'active'", { id, player.citizenid })
            return gone == 1 and { success = true } or done(false, 'that is not your advert')
        end },
        --- A message to the poster that does not reveal their number: the poster
        --- sees the sender's number, as with any message.
        contact = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            local body = clean(payload.body, Config.Messages.maxLength)
            if not body then return done(false, 'write a message first') end

            local ad = MySQL.single.await(
                "SELECT a.citizenid, a.title, c.phone FROM som_phone_adverts a JOIN som_characters c ON c.citizenid = a.citizenid WHERE a.id = ? AND a.status = 'active' AND a.expires_at > NOW()",
                { id })
            if not ad then return done(false, 'that advert is gone') end
            if ad.citizenid == player.citizenid then return done(false, 'that is your own advert') end

            local me = player.charinfo.phone
            MySQL.insert.await('INSERT INTO som_phone_messages (from_number, to_number, body) VALUES (?, ?, ?)',
                { me, ad.phone, ('[%s] %s'):format(ad.title, body):sub(1, Config.Messages.maxLength) })

            local poster = core:getPlayerByCitizenId(ad.citizenid)
            if poster then
                exports['som-phone']:notifyApp(poster.source, 'messages', ('%s: [%s]'):format(me, ad.title))
                TriggerClientEvent('som-phone:client:refresh', poster.source)
            end

            return { success = true }
        end },
        listing = { fn = function(_, _, player)
            return { listed = MySQL.scalar.await('SELECT listed FROM som_phone_pages_optin WHERE citizenid = ?', { player.citizenid }) == 1 }
        end },
        list = { writes = true, fn = function(_, payload, player)
            local listed = payload.listed == true and 1 or 0
            MySQL.insert.await([[
                INSERT INTO som_phone_pages_optin (citizenid, listed) VALUES (?, ?)
                ON DUPLICATE KEY UPDATE listed = VALUES(listed)
            ]], { player.citizenid, listed })
            return { listed = listed == 1 }
        end },
        search = { fn = function(_, payload)
            local q = clean(payload.q, 32)
            if not q or #q < Config.Pages.searchMin then
                return done(false, ('type at least %d letters'):format(Config.Pages.searchMin))
            end

            local pattern = '%' .. q:gsub('[%%_\\]', '\\%0') .. '%'
            return { people = MySQL.query.await([[
                SELECT c.firstname, c.lastname, c.phone FROM som_phone_pages_optin o
                JOIN som_characters c ON c.citizenid = o.citizenid
                WHERE o.listed = 1 AND c.slot IS NOT NULL AND CONCAT(c.firstname, ' ', c.lastname) LIKE ?
                ORDER BY c.lastname, c.firstname LIMIT ?
            ]], { pattern, Config.Pages.searchLimit }) or {} }
        end },
    },
})

-- Staff removal. Registered unrestricted and checked here, for the reason
-- documented on som-core's Permissions.AddCommand.
lib.addCommand('removepost', {
    help = 'Remove a Chirp post or a Pages advert',
    params = {
        { name = 'kind', type = 'string', help = 'post or advert' },
        { name = 'id', type = 'number' },
    },
}, function(source, args)
    local function say(text) if source ~= 0 then TriggerClientEvent('som:client:notify', source, text, 'inform') else print('[som-phone] ' .. text) end end

    if source ~= 0 and not core:hasPermission(source, 'som.mod') then return say('You do not have permission to do that') end

    local gone
    if args.kind == 'post' then
        gone = MySQL.update.await('UPDATE som_phone_posts SET removed = 1 WHERE id = ? AND removed = 0', { args.id })
    elseif args.kind == 'advert' then
        gone = MySQL.update.await("UPDATE som_phone_adverts SET status = 'removed' WHERE id = ? AND status = 'active'", { args.id })
    else
        return say('Use post or advert')
    end

    local staff = source ~= 0 and core:getPlayer(source) or nil
    MySQL.insert.await('INSERT INTO som_phone_audit (citizenid, app, action, ok) VALUES (?, ?, ?, ?)',
        { staff and staff.citizenid or 'console', 'moderation', ('remove %s %d'):format(args.kind, args.id), gone == 1 and 1 or 0 })

    say(gone == 1 and 'Removed' or 'Nothing to remove')
end)
