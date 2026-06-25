local cfg = NUIBlocker.Config

local States       = {}  -- src -> { [key] = true }
local ActionLog    = {}  -- src -> { head = int, stamps = {int...} }
local ViolationLog = {}  -- src -> int (count of blocked attempts)

-- =========================================================================
--  Helpers
-- =========================================================================
local function hasAnyOpen(src)
    local s = States[src]
    if not s then return false end
    return next(s) ~= nil
end

local function isRateLimited(src)
    local now = GetGameTimer()
    if not ActionLog[src] then
        ActionLog[src] = { head = 1, stamps = {} }
    end
    local entry = ActionLog[src]
    local stamps = entry.stamps

    local head = entry.head
    while head <= #stamps and (now - stamps[head]) > cfg.RateLimitWindow do
        head = head + 1
    end
    entry.head = head

    local active = #stamps - head + 1
    if active >= cfg.RateLimitMax then return true end

    stamps[#stamps + 1] = now
    return false
end

local function logViolation(src, reason, details)
    ViolationLog[src] = (ViolationLog[src] or 0) + 1
    local name = GetPlayerName(src) or 'Unknown'
    local ids  = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end

    local msg = ('[%s] %s (id: %s) — %s | %s'):format(
        cfg.LogSource, name, src, reason, details or ''
    )
    print('^1' .. msg .. '^7')

    if cfg.UseDiscordLogs and cfg.DiscordWebhook ~= '' then
        PerformHttpRequest(cfg.DiscordWebhook, function() end, 'POST',
            json.encode({
                embeds = { {
                    title       = cfg.LogSource .. ' — ' .. reason,
                    description = ('**Player:** %s (id: %s)\n**Identifiers:** %s\n**Details:** %s\n**Violations:** %d')
                        :format(name, src, table.concat(ids, ', '), details or 'N/A', ViolationLog[src]),
                    color       = 16711680,
                    footer      = { text = os.date('%Y-%m-%d %H:%M:%S') },
                } }
            }), { ['Content-Type'] = 'application/json' })
    end

    TriggerEvent('qb-log:server:CreateLog', 'anticheat',
        cfg.LogSource .. ': ' .. reason, 'red',
        ('**%s** (id: *%s*) %s — %s'):format(name, src, reason, details or ''))

    if cfg.BanOnThreshold and ViolationLog[src] >= cfg.BanThreshold then
        DropPlayer(src, cfg.BanMessage)
    end
end

-- =========================================================================
--  State management (called by other resources via exports or events)
-- =========================================================================
local function setNuiState(src, key, state)
    if type(src) ~= 'number' and type(src) ~= 'string' then return end
    src = tonumber(src)
    if not src then return end
    key = tostring(key or 'default')

    if not States[src] then States[src] = {} end
    if state then
        States[src][key] = true
    else
        States[src][key] = nil
    end
end

local function isNuiOpen(src, key)
    src = tonumber(src)
    if not src then return false end
    if key then
        local s = States[src]
        return s and s[tostring(key)] == true or false
    end
    return hasAnyOpen(src)
end

local function checkAction(src)
    src = tonumber(src)
    if not src then return false end
    if not hasAnyOpen(src) then
        logViolation(src, 'NUI Exploit Blocked', 'Action attempted with no NUI open')
        return false
    end
    if isRateLimited(src) then
        logViolation(src, 'Rate Limited', 'Exceeded ' .. cfg.RateLimitMax .. ' actions in ' .. cfg.RateLimitWindow .. 'ms')
        return false
    end
    return true
end

-- =========================================================================
--  Exports
-- =========================================================================
exports('SetNuiState', function(src, key, state)
    setNuiState(src, key, state)
end)

exports('IsNuiOpen', function(src, key)
    return isNuiOpen(src, key)
end)

exports('HasAnyOpen', function(src)
    return hasAnyOpen(tonumber(src))
end)

exports('CheckAction', function(src)
    return checkAction(src)
end)

exports('IsRateLimited', function(src)
    return isRateLimited(tonumber(src))
end)

exports('GetViolationCount', function(src)
    return ViolationLog[tonumber(src)] or 0
end)

exports('ResetViolations', function(src)
    ViolationLog[tonumber(src)] = nil
end)

-- =========================================================================
--  Net events (for resources that prefer events over exports)
-- =========================================================================
RegisterNetEvent('Lennox-NUIBlocker:server:setState', function(key, state)
    local src = source
    setNuiState(src, key, state)
end)

RegisterNetEvent('Lennox-NUIBlocker:server:checkAction', function()
    local src = source
    if not checkAction(src) then return end
end)

-- =========================================================================
--  Cleanup
-- =========================================================================
AddEventHandler('playerDropped', function()
    local src = source
    States[src]       = nil
    ActionLog[src]    = nil
    ViolationLog[src] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    print(('^2[%s]^7 NUI Blocker active — rate limit: %d/%dms'):format(
        cfg.LogSource, cfg.RateLimitMax, cfg.RateLimitWindow))
end)
