-- lib.inputDialog and lib.alertDialog, replaced with som-ui's.
--
-- NOT loaded by som-ui, and NOT in its client_scripts. Consumers load it
-- themselves, after ox_lib:
--
--     client_scripts {
--         '@som-ui/client/dialog.lua',
--         'client/whatever.lua',
--     }
--
-- For that include to resolve, this path is listed in som-ui's files{} block.
-- Read the header of client/progressbar.lua before changing any of that: the
-- three silent traps it documents apply here identically.
--
-- WHY BOTH IN ONE FILE. They are one panel and one focus in som-ui and they can
-- never both be up, so splitting them would only mean consumers remembering two
-- includes to replace one surface.
--
-- UNSUPPORTED ROW TYPES HAND THE WHOLE DIALOG BACK TO ox_lib. ox_lib's form has
-- eleven row types including date ranges, colour pickers and multi-select. Six
-- are implemented here, which is every type anything in this tree actually asks
-- for. A dialog containing anything else is passed to ox_lib intact rather than
-- rendered with the unknown row missing: a form that silently drops a field
-- returns a value the caller believes is real, which is worse than a dialog
-- that looks like ox_lib for one call.

if not lib then return end

-- Kept so a stopped som-ui degrades to ox_lib's dialogs rather than breaking
-- every fine, impound release and plate flag on the server.
local oxInputDialog = lib.inputDialog
local oxCloseInputDialog = lib.closeInputDialog
local oxAlertDialog = lib.alertDialog
local oxCloseAlertDialog = lib.closeAlertDialog

local ui = exports['som-ui']

local pending = nil
local token = nil
local activeRows = nil

local function uiReady()
    return GetResourceState('som-ui') == 'started'
end

local SUPPORTED = {
    input = true,
    number = true,
    textarea = true,
    checkbox = true,
    select = true,
    slider = true,
}

-- ---------------------------------------------------------------------------
-- Rows on the way out
-- ---------------------------------------------------------------------------

---ox_lib accepts a bare string as shorthand for a text row and normalises it
---before sending. Kept, because preserved resources use that form.
---@param row any
---@return table|nil
local function normalise(row)
    if type(row) == 'string' then return { type = 'input', label = row } end
    if type(row) ~= 'table' then return nil end
    return row
end

---@param rows table[]
---@return table[]|nil flattened, nil when a row type is not supported here
local function flatten(rows)
    local out = {}

    for index = 1, #rows do
        local row = normalise(rows[index])
        if not row then return nil end

        local kind = type(row.type) == 'string' and row.type or 'input'
        if not SUPPORTED[kind] then return nil end

        local entry = {
            index = index,
            type = kind,
            label = tostring(row.label or ''),
            description = row.description and tostring(row.description) or nil,
            -- Passed through as a NAME and never resolved to a glyph, the same
            -- decision the context menu shim records: SOM has no licensed icon
            -- set yet and the page holds the space on a data attribute.
            icon = row.icon and tostring(row.icon) or nil,
            placeholder = row.placeholder and tostring(row.placeholder) or nil,
            required = row.required == true,
            disabled = row.disabled == true,
            password = row.password == true,
        }

        if kind == 'number' or kind == 'slider' then
            entry.min = tonumber(row.min)
            entry.max = tonumber(row.max)
            entry.step = tonumber(row.step)
            entry.default = tonumber(row.default)
        elseif kind == 'checkbox' then
            entry.checked = row.checked == true
        elseif kind == 'select' then
            entry.options = {}

            for _, option in ipairs(type(row.options) == 'table' and row.options or {}) do
                if type(option) == 'table' and option.value ~= nil then
                    entry.options[#entry.options + 1] = {
                        value = tostring(option.value),
                        label = tostring(option.label or option.value),
                    }
                end
            end

            entry.default = row.default ~= nil and tostring(row.default) or nil
        else
            entry.default = row.default ~= nil and tostring(row.default) or nil
            entry.min = tonumber(row.minLength or row.min)
            entry.max = tonumber(row.maxLength or row.max)
        end

        out[index] = entry
    end

    return out
end

-- ---------------------------------------------------------------------------
-- Values on the way back
--
-- The page is told what each row is so it can render correctly. None of that is
-- trusted coming back: the row list here is the one the CALLER asked for, and
-- every value is coerced to the type that row promised and clamped to the
-- bounds it declared. A caller reading input[1] as a number must get a number
-- or nothing, never a string that happens to look like one.
-- ---------------------------------------------------------------------------

---@param row table
---@param raw any
---@return any value, boolean ok
local function coerce(row, raw)
    if row.type == 'checkbox' then
        return raw == true, true
    end

    if row.type == 'number' or row.type == 'slider' then
        local value = tonumber(raw)

        if not value or value ~= value then
            -- Blank is a legitimate answer for an optional number.
            return nil, not row.required
        end

        if row.min and value < row.min then value = row.min end
        if row.max and value > row.max then value = row.max end

        return value, true
    end

    if row.type == 'select' then
        local value = raw ~= nil and tostring(raw) or nil

        -- Re-resolved against the options actually offered, so a page sending a
        -- value that was never on the list resolves to nothing. This is the row
        -- type where that matters most: som-police pays an impound fee with it,
        -- and som-core validates the account again on the server after this.
        for _, option in ipairs(row.options or {}) do
            if option.value == value then return value, true end
        end

        return nil, not row.required
    end

    local value = raw ~= nil and tostring(raw) or ''

    if value == '' then return nil, not row.required end
    if row.max and #value > row.max then value = value:sub(1, row.max) end

    return value, true
end

---@param values any
---@return table|nil nil when a required row came back empty
local function resolve(values)
    if not activeRows then return nil end
    if type(values) ~= 'table' then values = {} end

    local out = {}

    for index = 1, #activeRows do
        local value, ok = coerce(activeRows[index], values[index])
        if not ok then return nil end
        out[index] = value
    end

    -- Returned as a table with holes where optional rows were left blank, which
    -- is what ox_lib does and what callers index by position.
    return out
end

---Answers the waiting call, exactly once.
---
---The state is cleared BEFORE the promise is resolved, for two reasons. A
---promise that is already settled raises when resolved again, and there are two
---paths that can reach here in the same tick: the player answering, and an
---alert's timeout firing. Citizen.Await does not resume until the next tick, so
---between the first resolve and the awaiting coroutine waking, `pending` would
---still look live to the second.
---
---It also means the awaiting call must NOT clear this state when it wakes: by
---then the same resource may already have opened another dialog, and clearing
---would strand it.
---@param value any
local function settle(value)
    local p = pending
    if not p then return end

    pending = nil
    token = nil
    activeRows = nil

    p:resolve(value)
end

-- ---------------------------------------------------------------------------
-- The ox_lib surface
-- ---------------------------------------------------------------------------

---@param heading string
---@param rows string[]|table[]
---@param options table|nil accepted and ignored, see below
---@return table|nil
function lib.inputDialog(heading, rows, options)
    if not uiReady() then return oxInputDialog(heading, rows, options) end
    if type(rows) ~= 'table' then return end

    -- ox_lib returns nil rather than erroring when one is already open, and
    -- callers written against it check for that.
    if pending then return end

    local flat = flatten(rows)

    -- An unsupported row type. The whole call goes to ox_lib rather than
    -- rendering the form without that field.
    if not flat then return oxInputDialog(heading, rows, options) end

    -- options.size and options.allowCancel are deliberately not carried across.
    -- size is a five step ox_lib scale that means nothing to a panel with one
    -- width, and a dialog that cannot be cancelled is a player stuck with a
    -- cursor if the caller never answers. Escape always works here.
    local claimed = ui:dialogOpen({
        kind = 'input',
        heading = tostring(heading or ''),
        rows = flat,
    })

    if not claimed then return end

    token = claimed
    activeRows = flat
    pending = promise.new()

    -- settle() has already cleared the state by the time this wakes.
    return Citizen.Await(pending)
end

function lib.closeInputDialog()
    if not uiReady() then return oxCloseInputDialog() end
    if not pending then return end

    ui:dialogClose(token)

    -- Answered here rather than by waiting for a broadcast, because dialogClose
    -- is the silent path: it takes the panel down without telling anyone,
    -- precisely so that this cannot answer the same call twice.
    settle(nil)
end

---@param data table
---@param timeout number|nil
---@return string|nil 'confirm' or 'cancel'
function lib.alertDialog(data, timeout)
    if not uiReady() then return oxAlertDialog(data, timeout) end
    if type(data) ~= 'table' then return end
    if pending then return end

    local labels = type(data.labels) == 'table' and data.labels or {}

    local claimed = ui:dialogOpen({
        kind = 'alert',
        heading = tostring(data.header or ''),
        content = tostring(data.content or ''),
        -- ox_lib's default is confirm only; a cancel button appears when asked
        -- for. Kept, because a caller that offers no way out meant to.
        cancel = data.cancel == true,
        labels = {
            cancel = tostring(labels.cancel or 'Cancel'),
            confirm = tostring(labels.confirm or 'Confirm'),
        },
    })

    if not claimed then return end

    token = claimed
    activeRows = nil
    pending = promise.new()

    if timeout then
        local expiring = claimed

        SetTimeout(timeout, function()
            -- Only if it is still the same dialog. A timeout that fires after
            -- the player already answered would close whatever is up now.
            if token == expiring and pending then lib.closeAlertDialog() end
        end)
    end

    return Citizen.Await(pending)
end

---ox_lib's version takes a reason and REJECTS the promise with it. That is not
---carried across: a rejection inside Citizen.Await surfaces as an error in the
---calling resource rather than as a closed dialog, and no caller in this tree
---passes a reason. Closing resolves to nil, which is what every caller already
---treats as "they did not answer".
function lib.closeAlertDialog()
    if not uiReady() then return oxCloseAlertDialog() end
    if not pending then return end

    ui:dialogClose(token)
    settle(nil)
end

-- ---------------------------------------------------------------------------
-- The result coming back
--
-- One handler per consuming resource, resolved by token, exactly as the context
-- menu and skill check shims do: som-ui broadcasts and only the resource
-- holding the live token acts on it.
-- ---------------------------------------------------------------------------

AddEventHandler('som-ui:client:dialog', function(msg)
    if type(msg) ~= 'table' then return end
    if not pending or not token or msg.token ~= token then return end

    local value

    if msg.cancelled then
        value = nil
    elseif not activeRows then
        -- No rows means it was an alert.
        value = msg.choice == 'confirm' and 'confirm' or 'cancel'
    else
        -- Read before settle(), which clears activeRows.
        value = resolve(msg.values)
    end

    settle(value)
end)
