-- lib.registerContext, lib.showContext and lib.hideContext, replaced with
-- som-ui's.
--
-- NOT loaded by som-ui, and NOT in its client_scripts. Consumers load it
-- themselves, after ox_lib:
--
--     client_scripts {
--         '@som-ui/client/context.lua',
--         'client/whatever.lua',
--     }
--
-- For that include to resolve, this path is listed in som-ui's files{} block.
-- Read the header of client/progressbar.lua before changing any of that: the
-- three silent traps it documents (files{}, state in the wrong place,
-- shared_scripts instead of client_scripts) apply here identically.
--
-- WHY THIS EXISTS. ox_lib's UI is a compiled React bundle and cannot be
-- restyled, so every menu on the server looked like ox_lib. Doing context menus
-- alone removes stock UI from vehicle inspection, plate flags, the impound list
-- and the mod bay at once, and every menu written from here is SOM by default
-- rather than by remembering to.
--
-- SCOPE. Only resources that load this file are affected. jim-recycle and
-- cdn-fuel call ox_lib through `exports.ox_lib:registerContext` rather than
-- `lib.`, so they are untouched either way.
--
-- The MENU stays here, functions and all, because an onSelect closure cannot
-- cross a resource boundary. Only a flattened description is sent to som-ui,
-- and a click comes back as a token and a row id which is re-resolved against
-- the real menu in this file.

if not lib then return end

-- Kept so a stopped som-ui degrades to ox_lib's menus rather than taking the
-- mod bay, the impound list and every future menu down with it.
local oxRegisterContext = lib.registerContext
local oxShowContext = lib.showContext
local oxHideContext = lib.hideContext
local oxGetOpenContextMenu = lib.getOpenContextMenu

local ui = exports['som-ui']

local menus = {}
local openId = nil
local token = nil

local function uiReady()
    return GetResourceState('som-ui') == 'started'
end

-- ---------------------------------------------------------------------------
-- Flattening a menu for the page
-- ---------------------------------------------------------------------------

---ox_lib accepts `options` either as an array of items carrying their own title,
---or as a map of key to item. The page is given one shape: an ordered list, each
---row carrying the id the click will come back as.
---
---Map keys are SORTED rather than iterated, because pairs() order is not stable
---and a menu whose rows move between openings is worse than one in an arbitrary
---but fixed order. ox_lib reaches the same place by encoding with sort_keys.
---@param options table
---@return table[] ordered, table lookup id -> item
local function order(options)
    local ordered, lookup = {}, {}

    if type(options) ~= 'table' then return ordered, lookup end

    -- An array if it has a first element. An options table is never sparse:
    -- ox_lib's own consumers build it with #options + 1.
    if options[1] ~= nil then
        for index = 1, #options do
            local id = tostring(index)
            ordered[#ordered + 1] = { id = id, item = options[index] }
            lookup[id] = options[index]
        end

        return ordered, lookup
    end

    local keys = {}
    for key in pairs(options) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)

    for _, key in ipairs(keys) do
        -- Read back through the original key, which may not be a string.
        local item = options[key]
        if item == nil then
            for realKey, value in pairs(options) do
                if tostring(realKey) == key then item = value break end
            end
        end

        ordered[#ordered + 1] = { id = key, item = item, fallbackTitle = key }
        lookup[key] = item
    end

    return ordered, lookup
end

---metadata is documented as a string, an array of strings, or a map. All three
---become a list of label and optional value, so the page renders one shape.
---@param metadata any
---@return table[]|nil
local function flattenMetadata(metadata)
    if metadata == nil then return nil end

    if type(metadata) == 'string' then
        return { { label = metadata } }
    end

    if type(metadata) ~= 'table' then return nil end

    local out = {}

    if metadata[1] ~= nil then
        for index = 1, #metadata do
            local entry = metadata[index]

            if type(entry) == 'table' then
                -- ox_lib also accepts { label = , value = } rows in the array.
                out[#out + 1] = {
                    label = tostring(entry.label or ''),
                    value = entry.value ~= nil and tostring(entry.value) or nil,
                }
            else
                out[#out + 1] = { label = tostring(entry) }
            end
        end

        return out
    end

    local keys = {}
    for key in pairs(metadata) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)

    for _, key in ipairs(keys) do
        out[#out + 1] = { label = key, value = tostring(metadata[key]) }
    end

    return out
end

---Whether clicking a row does anything at all.
---
---Read only rows are a real and used case: som-police's ID check and plate
---lookup are three facts each with nothing to press. They must render as
---information rather than as buttons that ignore you.
---@param item table
---@return boolean
local function selectable(item)
    if type(item) ~= 'table' then return false end
    if item.disabled or item.readOnly then return false end

    return item.menu ~= nil
        or item.onSelect ~= nil
        or item.event ~= nil
        or item.serverEvent ~= nil
end

---@param data table the registered menu
---@return table payload, table lookup
local function flatten(data)
    local ordered, lookup = order(data.options)
    local rows = {}

    for _, entry in ipairs(ordered) do
        local item = entry.item

        if type(item) == 'table' then
            rows[#rows + 1] = {
                id = entry.id,
                title = tostring(item.title or entry.fallbackTitle or ''),
                description = item.description and tostring(item.description) or nil,
                -- Passed through as a name, NOT resolved to a glyph. SOM has no
                -- licensed icon set yet and inventing one a name at a time is
                -- what produced the mixed set already on the server. The page
                -- puts it on a data attribute, so the day a real set lands it is
                -- one CSS rule rather than a sweep of every call site.
                icon = item.icon and tostring(item.icon) or nil,
                iconColor = item.iconColor and tostring(item.iconColor) or nil,
                image = item.image and tostring(item.image) or nil,
                progress = tonumber(item.progress) or nil,
                metadata = flattenMetadata(item.metadata),
                disabled = item.disabled == true,
                readOnly = item.readOnly == true,
                -- The page uses this to decide whether a row is a button. The
                -- real decision is made again on the way back, because a page
                -- can be edited and a click is an input.
                selectable = selectable(item),
                arrow = item.arrow == true or item.menu ~= nil,
            }
        end
    end

    return {
        title = tostring(data.title or ''),
        canClose = data.canClose ~= false,
        -- Presence of a parent is what draws the back control.
        back = data.menu ~= nil,
        options = rows,
    }, lookup
end

-- The lookup for the menu currently on screen, so a click resolves without
-- re-flattening.
local activeLookup = nil

-- ---------------------------------------------------------------------------
-- The ox_lib surface
-- ---------------------------------------------------------------------------

---@param context table single menu, or an array of them
function lib.registerContext(context)
    if type(context) ~= 'table' then return end

    -- ox_lib's own shape test, kept exactly: a numeric first key means an array
    -- of menus, anything else means one menu.
    for key, value in pairs(context) do
        if type(key) == 'number' then
            if type(value) == 'table' and value.id then menus[value.id] = value end
        else
            if context.id then menus[context.id] = context end
            break
        end
    end

    -- ox_lib is still given the menu as well.
    --
    -- Not belt and braces: lib.showContext falls back to ox_lib when som-ui is
    -- stopped, and ox_lib cannot show a menu it was never told about. Without
    -- this the fallback would error instead of degrading.
    if oxRegisterContext then pcall(oxRegisterContext, context) end
end

---@param id string
function lib.showContext(id)
    if not menus[id] then error(('No context menu of such id found: %s'):format(tostring(id))) end

    if not uiReady() then return oxShowContext(id) end

    local payload, lookup = flatten(menus[id])

    openId = id
    activeLookup = lookup
    token = ui:contextOpen(payload)
end

---@return string?
function lib.getOpenContextMenu()
    if not uiReady() then return oxGetOpenContextMenu and oxGetOpenContextMenu() end

    return openId
end

---Closes the menu. `onExit` fires only when asked for, matching ox_lib, because
---a submenu switching away is not an exit.
---@param onExit boolean|nil
function lib.hideContext(onExit)
    if not uiReady() then return oxHideContext(onExit) end

    local closing = openId

    openId = nil
    activeLookup = nil

    if token then
        ui:contextClose(token)
        token = nil
    end

    if onExit and closing and menus[closing] and menus[closing].onExit then
        menus[closing].onExit()
    end
end

-- ---------------------------------------------------------------------------
-- Clicks coming back
--
-- One handler per consuming resource. The token is what makes that safe: only
-- the resource whose menu is on screen holds the live token, so every other
-- copy of this handler returns on the first line.
-- ---------------------------------------------------------------------------

AddEventHandler('som-ui:client:context', function(msg)
    if type(msg) ~= 'table' then return end
    if not token or msg.token ~= token then return end

    local menu = openId and menus[openId]
    if not menu then return end

    if msg.action == 'close' then
        -- som-ui has already hidden it and released focus. Only the bookkeeping
        -- and the callback are left.
        openId = nil
        activeLookup = nil
        token = nil

        if menu.onExit then menu.onExit() end
        return
    end

    if msg.action == 'back' then
        if menu.onBack then menu.onBack() end
        if menu.menu then lib.showContext(menu.menu) end
        return
    end

    if msg.action ~= 'select' then return end

    local item = activeLookup and activeLookup[tostring(msg.id)]
    if not item then return end

    -- Checked again on the way in. The page was told which rows are selectable
    -- and a page is not a source of truth about anything.
    if not selectable(item) then return end

    if item.menu then
        -- A submenu replaces the menu on screen. Focus is never dropped, so
        -- there is no flicker between the two.
        return lib.showContext(item.menu)
    end

    -- Everything else closes first, so a callback that opens its own dialog is
    -- not fighting this menu for focus. lib.inputDialog immediately after a
    -- selection is the common case and it is the case that breaks otherwise.
    lib.hideContext(false)

    if item.onSelect then item.onSelect(item.args) end
    if item.event then TriggerEvent(item.event, item.args) end
    if item.serverEvent then TriggerServerEvent(item.serverEvent, item.args) end
end)

-- Restarting a consumer with its own menu up would strand the cursor on screen
-- with nothing left to click it.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not token then return end

    pcall(function() ui:contextClose(token) end)
    token = nil
end)
