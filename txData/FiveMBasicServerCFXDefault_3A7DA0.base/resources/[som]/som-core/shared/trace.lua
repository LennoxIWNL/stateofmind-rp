--- Optional trace of server callbacks, switched on with `set som_debug 1`.
--- Every lib.callback.register in a resource that loads this file logs one line
--- per call: name, source, result and time, and a failing handler logs its error
--- before it is raised again. Off by default and free when off. Made by Lennox.

if not IsDuplicityVersion() or GetConvar('som_debug', '0') ~= '1' then return end
if not lib or not lib.callback or not lib.callback.register then return end

local resource = GetCurrentResourceName()
local register = lib.callback.register

local function summary(value)
    if type(value) ~= 'table' then return tostring(value) end
    if value.success ~= nil then
        return value.success and 'ok' or ('refused: ' .. tostring(value.error))
    end
    return 'table'
end

lib.callback.register = function(name, handler)
    return register(name, function(source, ...)
        local started = GetGameTimer()
        local ok, result = pcall(handler, source, ...)
        local took = GetGameTimer() - started
        if not ok then
            print(('^1[som-trace] %s %s src=%s ERROR %s^7'):format(resource, name, tostring(source), tostring(result)))
            error(result, 0)
        end
        print(('[som-trace] %s %s src=%s %s (%dms)'):format(resource, name, tostring(source), summary(result), took))
        return result
    end)
end
