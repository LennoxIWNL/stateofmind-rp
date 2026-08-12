-- /sethud: the layout editor.
--
-- THE ONLY INBOUND SURFACE IN THIS RESOURCE, and it is deliberately narrow.
-- It accepts LAYOUT ONLY: positions, scales, which panels are on, and which
-- variant each uses. It never accepts a VALUE. A player editing their own HUD
-- has moved their own numbers around the screen and changed nothing about what
-- those numbers say.
--
-- That is why there is no server half here and no validation of the layout
-- beyond it being a table: there is nothing to gain by lying. The worst a
-- crafted layout achieves is a HUD that looks wrong to the person who crafted
-- it.
--
-- PERSISTENCE IS KVP, not the database, and that is a trade rather than an
-- oversight. KVP is per machine rather than per character, so a player moving
-- to another PC starts from the default. The alternative is a column on
-- som_characters and a round trip on every spawn, for a preference that is
-- genuinely per screen: a layout tuned for an ultrawide is wrong on a laptop.
-- Export and import cover moving one deliberately.

local KVP = 'som_hud_layout'
local editing = false

local function loadLayout()
    local raw = GetResourceKvpString(KVP)
    if not raw then return nil end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil end

    return decoded
end

local function saveLayout(layout)
    if type(layout) ~= 'table' then return end
    SetResourceKvp(KVP, json.encode(layout))
end

--- Pushes the stored layout to the page. Sent on start and after every change,
--- so the page never keeps its own copy as the source of truth.
function PushLayout()
    SendNUIMessage({ action = 'hud:layout', layout = loadLayout() or false })
end

local function setEditing(state)
    if editing == state then return end
    editing = state

    SetNuiFocus(editing, editing)
    SendNUIMessage({ action = 'hud:edit', editing = editing })
end

local function openEditor()
    -- Says why rather than returning silently. A command that does nothing and
    -- explains nothing is indistinguishable from one that is not registered,
    -- which is exactly how this was reported.
    if not exports['som-core']:isPlayerLoaded() then
        return TriggerEvent('som:client:notify', 'Load a character first', 'error')
    end

    setEditing(true)
end

RegisterCommand('sethud', openEditor, false)

-- Alias. /hud is what people actually type, and it cost one line to accept it.
RegisterCommand('hud', openEditor, false)

RegisterNUICallback('hudSaveLayout', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.layout) ~= 'table' then return end

    saveLayout(data.layout)
    setEditing(false)
end)

RegisterNUICallback('hudResetLayout', function(_, cb)
    cb(1)
    DeleteResourceKvp(KVP)
    PushLayout()
end)

RegisterNUICallback('hudCloseEditor', function(_, cb)
    cb(1)
    setEditing(false)
    -- Re-push, so abandoning the editor restores the saved layout rather than
    -- leaving whatever was being dragged when Escape was pressed.
    PushLayout()
end)

--- Export hands the layout back as text for the player to copy. It goes through
--- the page rather than the clipboard because NUI has no clipboard access
--- worth relying on.
RegisterNUICallback('hudExportLayout', function(_, cb)
    cb({ layout = loadLayout() or false })
end)

RegisterNUICallback('hudImportLayout', function(data, cb)
    if type(data) ~= 'table' or type(data.raw) ~= 'string' then return cb({ ok = false }) end

    local ok, decoded = pcall(json.decode, data.raw)
    if not ok or type(decoded) ~= 'table' then return cb({ ok = false }) end

    saveLayout(decoded)
    PushLayout()
    cb({ ok = true })
end)

CreateThread(function()
    -- After a beat, so the page has mounted and its listener exists. A layout
    -- pushed before that is dropped and the HUD renders at defaults with a
    -- saved layout sitting in KVP, which reads as the save having failed.
    Wait(1500)
    PushLayout()
end)

AddEventHandler('som:client:onPlayerLoaded', PushLayout)
