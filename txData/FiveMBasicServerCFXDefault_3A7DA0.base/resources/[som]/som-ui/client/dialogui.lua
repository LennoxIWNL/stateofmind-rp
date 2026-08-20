-- Dialogs: the authoritative state, and the drawing.
--
-- Two surfaces, one panel and one focus, because they can never both be up:
--
--   input  lib.inputDialog, a form that returns a list of values
--   alert  lib.alertDialog, a question that returns confirm or cancel
--
-- Same split as progress, context menus and skill checks. This resource owns
-- the panel and the NUI focus; the shim that replaces the ox_lib functions
-- lives in client/dialog.lua and is loaded BY consumers so that it runs where
-- their `lib` table is.
--
-- Unlike the skill check this takes a CURSOR as well as focus, because a form
-- is something you click into.
--
-- Nothing here interprets a row. It forwards what the page sent to whichever
-- resource holds the token, and that resource coerces and re-checks it against
-- the rows it actually asked for. A page is an input, not a source of truth.

local activeToken = nil
local nextToken = 0

---@param payload table
---@return number|nil token
local function open(payload)
    if type(payload) ~= 'table' then return end
    if payload.kind ~= 'input' and payload.kind ~= 'alert' then return end

    -- A second dialog while one is up is refused rather than allowed to take
    -- the screen. Two of these overlapping means two resources both blocked on
    -- a promise and only one of them ever answered.
    if activeToken then return end

    nextToken = nextToken + 1
    activeToken = nextToken

    -- Cursor on, game input off. A form is clicked into, and keeping game input
    -- alive would let the player drive while typing.
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'dialog:show',
        token = activeToken,
        data = payload,
    })

    return activeToken
end

---Closes the panel WITHOUT telling anyone, for the caller that closed it
---itself. The shim resolves its own promise in that case, so a second
---broadcast here would resolve it twice.
---@param token number|nil
local function close(token)
    if not activeToken then return end
    if token and token ~= activeToken then return end

    activeToken = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'dialog:hide' })
end

---@param token number|nil
---@return boolean
local function isActive(token)
    if not activeToken then return false end
    if token and token ~= activeToken then return false end
    return true
end

exports('dialogOpen', open)
exports('dialogClose', close)
exports('dialogActive', isActive)

-- ---------------------------------------------------------------------------
-- Back from the NUI
--
-- One callback, answered before anything is decided. A callback that throws
-- before cb() leaves the page waiting on a promise that never settles, and for
-- this surface that also means the focus it took never comes back.
--
-- No colon in the name: it becomes the path of the page's fetch.
-- ---------------------------------------------------------------------------

RegisterNUICallback('dialogSubmit', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local token = tonumber(data.token)
    if not token or token ~= activeToken then return end

    local cancelled = data.cancelled == true

    if Feedback then Feedback.play(cancelled and 'back' or 'select') end

    -- Hidden before the owner is told, so focus is released even if the owner
    -- has been restarted and nothing is listening for the event.
    close(token)

    TriggerEvent('som-ui:client:dialog', {
        token = token,
        cancelled = cancelled,
        -- Raw. The shim owns the rows and is the only thing that can say what
        -- any of this is supposed to be.
        values = data.values,
        choice = data.choice,
    })
end)

-- A restart with a dialog up would otherwise leave the cursor on screen and the
-- player unable to move, with no page left to click.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not activeToken then return end

    activeToken = nil
    SetNuiFocus(false, false)
end)
