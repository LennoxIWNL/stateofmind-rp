-- TextUI. Replaces the three overlapping implementations catalogued in
-- AUDIT.md section 7.4 (som-textui, som-text, pa-textui-2) with one.
--
-- No per-frame loop: the NUI is a DOM element that is shown and hidden by
-- message, so there is nothing to redraw each tick.

local shown = false
local currentKey = nil
local currentLabel = nil

---@param label string text to display
---@param options table|nil { key = 'E' }
local function showTextUI(label, options)
    if type(label) ~= 'string' then return end

    options = options or {}
    local key = options.key

    -- Re-sending an identical payload restarts the CSS transition and makes the
    -- panel flicker, so skip when nothing changed.
    if shown and currentKey == key and currentLabel == label then return end

    SendNUIMessage({
        action = 'showTextUI',
        label = label,
        key = key,
    })

    shown = true
    currentKey = key
    currentLabel = label
end

local function hideTextUI()
    if not shown then return end

    SendNUIMessage({ action = 'hideTextUI' })
    shown = false
    currentKey = nil
    currentLabel = nil
end

---@return boolean
local function isTextUIOpen()
    return shown
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hideTextUI()
end)

exports('showTextUI', showTextUI)
exports('hideTextUI', hideTextUI)
exports('isTextUIOpen', isTextUIOpen)
