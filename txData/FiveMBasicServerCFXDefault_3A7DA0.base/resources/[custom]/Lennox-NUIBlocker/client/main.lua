local openKeys = {}

local function setNuiState(key, state)
    key = tostring(key or 'default')
    openKeys[key] = state and true or nil
    TriggerServerEvent('Lennox-NUIBlocker:server:setState', key, state and true or false)
end

local function isNuiOpen(key)
    if key then return openKeys[tostring(key)] == true end
    return next(openKeys) ~= nil
end

local function closeAll()
    for k in pairs(openKeys) do
        openKeys[k] = nil
    end
    TriggerServerEvent('Lennox-NUIBlocker:server:setState', 'default', false)
end

-- =========================================================================
--  Exports
-- =========================================================================
exports('SetNuiState', function(key, state)
    setNuiState(key, state)
end)

exports('IsNuiOpen', function(key)
    return isNuiOpen(key)
end)

exports('CloseAll', function()
    closeAll()
end)

-- =========================================================================
--  Override SetNUIFocus to auto-track
-- =========================================================================
local origSetNUIFocus = SetNUIFocus

local function trackedSetNUIFocus(hasFocus, hasCursor)
    origSetNUIFocus(hasFocus, hasCursor)

    local caller = GetInvokingResource() or 'unknown'
    if hasFocus then
        setNuiState(caller, true)
    else
        setNuiState(caller, false)
    end
end

SetNUIFocus = trackedSetNUIFocus

-- =========================================================================
--  Safety: clear state on resource stop
-- =========================================================================
AddEventHandler('onResourceStop', function(res)
    if openKeys[res] then
        openKeys[res] = nil
        TriggerServerEvent('Lennox-NUIBlocker:server:setState', res, false)
    end
end)

AddEventHandler('onClientResourceStop', function(res)
    if openKeys[res] then
        openKeys[res] = nil
        TriggerServerEvent('Lennox-NUIBlocker:server:setState', res, false)
    end
end)
