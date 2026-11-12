--- The server owns the game clock: the hour is derived from os.time and a rate, never counted.
--- Staff changes live in memory only, so a restart returns to Config.Clock (or the convar freeze).

local C = Config.Clock
local state = { dayMinutes = C.dayMinutes, offset = C.startHour * 3600, frozen = nil }

local function parse(text)
    local h, m = tostring(text):match('^(%d%d?):(%d%d)$')
    h, m = tonumber(h), tonumber(m)
    if h and h < 24 and m < 60 then return h * 3600 + m * 60 end
end

local function publish() GlobalState.somClock = state end

local function seconds() return SomClock.Seconds(os.time(), state) end

---Shifts the offset so the clock reads `target` game seconds right now.
local function moveTo(target)
    local running = { dayMinutes = state.dayMinutes, offset = 0 }
    state.offset = (target - SomClock.Seconds(os.time(), running)) % 86400
end

local function format(s) return ('%02d:%02d'):format(s // 3600, s % 3600 // 60) end

local freeze = GetConvar('som_clock_freeze', '')
if freeze ~= '' then
    state.frozen = parse(freeze)
    if not state.frozen then print(('[som-core] som_clock_freeze "%s" is not HH:MM, the clock runs'):format(freeze)) end
end
publish()

exports('getGameTime', function()
    local h, m = SomClock.Time(os.time(), state)
    return h, m
end)

exports('getGameHour', function() return (SomClock.Time(os.time(), state)) end)

---Reads an hour and optional minute from command arguments, or nil when they are not whole and in range.
local function target(args)
    local hour, minute = args.hour, args.minute or 0
    if type(hour) ~= 'number' or hour % 1 ~= 0 or hour < 0 or hour > 23 then return nil end
    if type(minute) ~= 'number' or minute % 1 ~= 0 or minute < 0 or minute > 59 then return nil end
    return hour * 3600 + minute * 60
end

local function say(source, text, kind)
    if source == 0 then print('[som-core] ' .. text) else TriggerClientEvent('som:client:notify', source, text, kind or 'inform') end
end

local timeParams = {
    { name = 'hour', type = 'number', optional = true },
    { name = 'minute', type = 'number', optional = true },
}

Permissions.AddCommand('settime', { help = 'Set the game time: /settime <hour> [minute]', params = timeParams }, Config.Permissions.admin, function(source, args)
    local at = target(args)
    if not at then return say(source, 'Use /settime <hour 0-23> [minute 0-59]', 'error') end

    if state.frozen then state.frozen = at else moveTo(at) end
    publish()
    print(('[som-core] game time set to %s by %s'):format(format(at), source == 0 and 'the console' or GetPlayerName(source)))
    say(source, ('Game time is now %s'):format(format(at)), 'success')
end)

Permissions.AddCommand('freezetime', { help = 'Freeze or unfreeze the game time: /freezetime [hour] [minute]', params = timeParams }, Config.Permissions.admin, function(source, args)
    if state.frozen then
        local held = state.frozen
        state.frozen = nil
        moveTo(held)
        publish()
        return say(source, 'Game time runs again', 'success')
    end

    local at = (args.hour == nil and args.minute == nil) and seconds() or target(args)
    if not at then return say(source, 'Use /freezetime [hour 0-23] [minute 0-59]', 'error') end

    state.frozen = at
    publish()
    print(('[som-core] game time frozen at %s by %s'):format(format(at), source == 0 and 'the console' or GetPlayerName(source)))
    say(source, ('Game time is frozen at %s'):format(format(at)), 'success')
end)

Permissions.AddCommand('gametime', { help = 'Show the game time' }, Config.Permissions.mod, function(source)
    say(source, ('Game time %s%s'):format(format(seconds()), state.frozen and ' (frozen)' or ''))
end)
