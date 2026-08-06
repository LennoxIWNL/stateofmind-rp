-- Context menus: the authoritative state, and the drawing.
--
-- Same split as progress, and for the same reason. This resource owns the one
-- on-screen menu and the NUI focus that comes with it; the shim that replaces
-- lib.registerContext lives in client/context.lua and is loaded BY consumers so
-- that it runs in their context, where their `lib` table and their onSelect
-- closures are.
--
-- The functions are the reason the split is not optional. A menu option's
-- onSelect is a Lua closure over the calling resource's locals, and a closure
-- cannot cross a resource boundary. So the shim keeps the real menu, including
-- its functions, and sends only a flattened, serialisable description here.
-- When a row is clicked this fires an event carrying the token and the row id,
-- and the shim that recognises the token is the one that runs the closure.
--
-- Unlike progress, this DOES take NUI focus. A menu is something you click.

local activeToken = nil
local nextToken = 0

-- What the current menu allows, held here rather than trusted from the NUI.
-- A page that has been edited must not be able to close a menu whose whole
-- purpose is that it cannot be dismissed.
local activeCanClose = true

---Shows a menu, replacing whatever was up.
---
---Always succeeds and always issues a NEW token. Opening the mod bay while the
---impound list is up is a thing a player did on purpose, so a menu takes the
---screen rather than queuing for it, and the previous owner simply finds its
---token stale. ox_lib behaves the same way, and it is what makes a submenu a
---plain second show rather than a stack to maintain.
---@param payload table flattened, function free menu description
---@return number token
local function open(payload)
    nextToken = nextToken + 1
    activeToken = nextToken
    activeCanClose = payload and payload.canClose ~= false

    -- Cursor on, game input off. The second argument to SetNuiFocus is the
    -- cursor; keeping game input alive as well would let the player drive while
    -- clicking a menu.
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'context:show',
        token = activeToken,
        data = payload,
    })

    return activeToken
end

---@param token number|nil nil closes whatever is open
local function close(token)
    if not activeToken then return end
    if token and token ~= activeToken then return end

    activeToken = nil
    activeCanClose = true

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'context:hide' })
end

---@param token number|nil
---@return boolean
local function isOpen(token)
    if not activeToken then return false end
    if token and token ~= activeToken then return false end

    return true
end

exports('contextOpen', open)
exports('contextClose', close)
exports('contextIsOpen', isOpen)

-- ---------------------------------------------------------------------------
-- Back from the NUI
--
-- Every callback answers cb() first and decides afterwards. A NUI callback that
-- throws before answering leaves the page waiting on a promise that never
-- settles, and the next click does nothing at all.
--
-- Nothing here acts on the row itself. It forwards the id to whichever resource
-- holds the token, because only that resource knows what the row means. The id
-- is echoed back untouched and is re-resolved against the real menu there, so a
-- page sending an id that was never rendered resolves to nothing.
-- ---------------------------------------------------------------------------

-- The sound half of a menu interaction, completing the 18.11 sweep for the
-- surface this file replaces. ox_lib's menus were silent, and a menu that makes
-- no noise when you pick something is the flatness that whole section is about.
--
-- Picking is `select`, leaving is `back`, and both are the frontend sounds the
-- player already associates with those actions in this game.
local SOUNDS = {
    select = 'select',
    back = 'back',
    close = 'back',
}

---@param action string
---@param id any
local function forward(action, id)
    local token = activeToken
    if not token then return end

    local sound = SOUNDS[action]
    if sound and Feedback then Feedback.play(sound) end

    TriggerEvent('som-ui:client:context', {
        token = token,
        action = action,
        id = id,
    })
end

RegisterNUICallback('context:select', function(data, cb)
    cb(1)
    forward('select', type(data) == 'table' and data.id or nil)
end)

RegisterNUICallback('context:back', function(_, cb)
    cb(1)
    forward('back')
end)

RegisterNUICallback('context:close', function(_, cb)
    cb(1)

    -- Refused HERE, not in the page. canClose is a rule about the menu and the
    -- page is the one thing that cannot be trusted to enforce it.
    if not activeCanClose then return end

    local token = activeToken

    -- Not through forward(), because the menu has to come down whether or not
    -- anything still holds the token, so the sound is played here instead.
    if token and Feedback then Feedback.play(SOUNDS.close) end

    -- Hidden before the owner is told, so focus is released even if the owner
    -- has been restarted and nothing is listening for the event.
    close(token)

    if token then
        TriggerEvent('som-ui:client:context', {
            token = token,
            action = 'close',
        })
    end
end)

-- A restart with a menu up would otherwise leave the cursor on screen and the
-- player unable to move, with no page left to click.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not activeToken then return end

    activeToken = nil
    SetNuiFocus(false, false)
end)
