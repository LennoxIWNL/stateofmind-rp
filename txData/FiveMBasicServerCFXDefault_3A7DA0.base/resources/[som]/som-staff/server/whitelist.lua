--- Connection whitelist. A player may connect only if one of their identifiers
--- has a row in som_whitelist. Rows are added by staff with /whitelist, from
--- the server console (so a Discord bot can drive it over RCON), or by the bot
--- writing the table directly. The gate itself is the server's: it runs in
--- playerConnecting before the player is given a slot.

local core = exports['som-core']

Whitelist = {}

local function enabled()
    local v = GetConvar(Config.whitelistConvar, 'false')
    return v == '1' or v == 'true'
end

---@return string|nil identifier, string|nil error
function Whitelist.Normalise(identifier)
    if type(identifier) ~= 'string' then return nil, 'bad identifier' end
    local kind, value = identifier:lower():match('^(%a+%d?):(%w+)$')
    if not kind or not Config.identifierKinds[kind] then return nil, 'bad identifier' end
    return kind .. ':' .. value
end

function Whitelist.Add(identifier, note, addedBy)
    local id, err = Whitelist.Normalise(identifier)
    if not id then return false, err end
    local n = MySQL.update.await(
        'INSERT IGNORE INTO som_whitelist (identifier, note, added_by) VALUES (?, ?, ?)',
        { id, tostring(note or ''):sub(1, 120), tostring(addedBy or 'console'):sub(1, 64) })
    return (n or 0) > 0, (n or 0) > 0 and nil or 'already on the list'
end

function Whitelist.Remove(identifier)
    local id, err = Whitelist.Normalise(identifier)
    if not id then return false, err end
    local n = MySQL.update.await('DELETE FROM som_whitelist WHERE identifier = ?', { id })
    return (n or 0) > 0, (n or 0) > 0 and nil or 'not on the list'
end

---@param identifiers string[]
function Whitelist.Allows(identifiers)
    for _, raw in ipairs(identifiers) do
        local id = Whitelist.Normalise(raw)
        if id and MySQL.scalar.await('SELECT 1 FROM som_whitelist WHERE identifier = ?', { id }) then return true end
    end
    return false
end

---Whether any identifier has an active ban. Returns the message to show.
---@param identifiers string[]
---@return string|nil message
function Whitelist.Banned(identifiers)
    for _, raw in ipairs(identifiers) do
        local id = Whitelist.Normalise(raw)
        local ban = id and MySQL.single.await(
            'SELECT reason, expires_at IS NULL AS permanent FROM som_bans WHERE identifier = ? AND revoked = 0 AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1',
            { id })
        if ban then
            return ('You are banned: %s%s'):format(ban.reason, ban.permanent == 1 and ' (permanent)' or '')
        end
    end
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do ids[#ids + 1] = GetPlayerIdentifier(src, i) end

    local ok, banned = pcall(Whitelist.Banned, ids)
    if not ok then return deferrals.done('The server could not check your ban status. Try again.') end
    if banned then return deferrals.done(banned) end

    if not enabled() then return deferrals.done() end

    local good, allowed = pcall(Whitelist.Allows, ids)
    if good and allowed then return deferrals.done() end
    deferrals.done(Config.deniedMessage)
end)

local function reply(source, text)
    if source == 0 then print('[som-staff] ' .. text) else TriggerClientEvent('som:client:notify', source, text, 'inform') end
end

lib.addCommand('whitelist', {
    help = 'Whitelist: add <identifier> [note], remove <identifier>, check <identifier>',
    params = {
        { name = 'action', type = 'string' },
        { name = 'identifier', type = 'string' },
        { name = 'note', type = 'string', optional = true },
    },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    end

    local who = source == 0 and 'console' or ('%d'):format(source)
    if args.action == 'add' then
        local ok, err = Whitelist.Add(args.identifier, args.note, who)
        reply(source, ok and 'Added' or ('Not added: ' .. tostring(err)))
    elseif args.action == 'remove' then
        local ok, err = Whitelist.Remove(args.identifier)
        reply(source, ok and 'Removed' or ('Not removed: ' .. tostring(err)))
    elseif args.action == 'check' then
        reply(source, Whitelist.Allows({ args.identifier }) and 'Listed' or 'Not listed')
    else
        reply(source, 'Use add, remove or check')
    end
end)

exports('addWhitelist', function(identifier, note, addedBy) return Whitelist.Add(identifier, note, addedBy) end)
