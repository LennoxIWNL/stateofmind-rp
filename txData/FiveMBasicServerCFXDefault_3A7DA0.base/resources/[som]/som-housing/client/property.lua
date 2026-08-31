--- Doors, and what you can do at one.
---
--- Every option here is a UI FILTER ONLY, the same rule som-garage states about
--- its zones. The server re-checks the key, the distance and the price on every
--- call, so hiding a button is a courtesy and never a control.

local core = exports['som-core']

-- ---------------------------------------------------------------------------
-- Entering and leaving
-- ---------------------------------------------------------------------------

local busy = false

---@param slug string
local function enter(slug)
    if busy then return end
    busy = true

    local res = lib.callback.await('som-housing:server:enter', false, slug)

    if not res or not res.success then
        busy = false
        return TriggerEvent('som:client:notify', res and res.error or 'Could not go in', 'error')
    end

    if not Interior.Build(res) then
        -- The server has already moved the bucket, so a failed build would
        -- leave the player in an empty instance. Ask to be let back out.
        lib.callback.await('som-housing:server:leave', false)
    end

    busy = false
end

local function leave()
    if busy then return end
    local inside = Interior.Current()
    if not inside then return end

    busy = true

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    local res = lib.callback.await('som-housing:server:leave', false)

    -- Torn down whatever the server said. If it refused, the player is still
    -- in the bucket and keeping the shell would be the only thing making that
    -- survivable, but a stuck player who can see the world is easier to rescue
    -- than one who cannot.
    Interior.Tear()

    if res and res.success then
        local ped = PlayerPedId()
        SetEntityCoords(ped, res.coords.x, res.coords.y, res.coords.z, false, false, false, false)

        local waited = 0
        while not HasCollisionLoadedAroundEntity(ped) and waited < 3000 do
            Wait(50)
            waited = waited + 50
        end
    end

    DoScreenFadeIn(600)
    busy = false
end

-- ---------------------------------------------------------------------------
-- Looking, and buying
-- ---------------------------------------------------------------------------

--- DEFINED ABOVE THE ZONE THREAD ON PURPOSE.
---
--- The zone options close over this name. A local declared after that block
--- would not be in scope when the closure is built, so the closure would
--- capture a global that never gets assigned and calling it would be a nil
--- call at the door rather than an error at load.
---@param slug string
local function inspect(slug)
    local res = lib.callback.await('som-housing:server:inspect', false, slug)

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Nothing to see', 'error')
    end

    -- Owned, sold, or agent-only. All three are just something to read.
    if not res.forSale then
        return TriggerEvent('som:client:notify', res.text, res.owned and 'inform' or 'error')
    end

    if not res.accounts or #res.accounts == 0 then
        return TriggerEvent('som:client:notify', 'You have no account to pay from', 'error')
    end

    local options = {}
    for i = 1, #res.accounts do
        local account = res.accounts[i]
        options[i] = { value = account.account, label = ('%s'):format(account.label) }
    end

    local answer = lib.inputDialog(res.label, {
        { type = 'select', label = 'Pay with', options = options, required = true },
    })

    if not answer or not answer[1] then return end

    local bought = lib.callback.await('som-housing:server:buy', false, {
        slug = slug,
        -- A NAME, not a balance and not a price. The server re-reads both.
        account = answer[1],
    })

    if not bought or not bought.success then
        return TriggerEvent('som:client:notify', bought and bought.error or 'Sale failed', 'error')
    end

    TriggerEvent('som:client:notify', ('%s is yours'):format(bought.label), 'success')
end

-- ---------------------------------------------------------------------------
-- Door zones
-- ---------------------------------------------------------------------------

--- Built from Config, which is shared, so the client already knows every door
--- without asking. Nothing sensitive is in it: a door coordinate and a price
--- are public facts, and the ownership that decides what happens at one is not
--- here at all.
CreateThread(function()
    -- After som-interact has registered its own exports.
    Wait(1000)

    for _, property in ipairs(Config.Properties) do
        exports['som-interact']:addBoxZone({
            name = ('property:%s'):format(property.slug),
            coords = vec3(property.door.x, property.door.y, property.door.z),
            size = vec3(1.6, 1.6, 2.4),
            rotation = property.door.w,
            options = {
                {
                    name = ('property:%s:enter'):format(property.slug),
                    icon = 'fa-solid fa-door-open',
                    label = ('Enter %s'):format(property.label),
                    distance = 2.0,
                    onSelect = function() enter(property.slug) end,
                },
                {
                    name = ('property:%s:view'):format(property.slug),
                    icon = 'fa-solid fa-house-circle-check',
                    label = ('View %s'):format(property.label),
                    distance = 2.0,
                    onSelect = function() inspect(property.slug) end,
                },
            },
        })
    end
end)

-- ---------------------------------------------------------------------------
-- Inside
-- ---------------------------------------------------------------------------

--- The way out, and the stash.
---
--- Registered as a GLOBAL OBJECT option rather than a zone because the shell is
--- spawned at coordinates that change per property, so there is no fixed place
--- to put a zone. som-interact's README notes ox_target draws its indicator for
--- zones only, which is why the exit also has a key press behind it below.
CreateThread(function()
    Wait(1000)

    exports['som-interact']:addGlobalObject({
        {
            name = 'property:stash',
            icon = 'fa-solid fa-box-archive',
            label = 'Storage',
            distance = 1.8,
            canInteract = function()
                return Interior.Current() ~= nil
            end,
            onSelect = function()
                local inside = Interior.Current()
                if not inside or not inside.stash then return end
                exports.ox_inventory:openInventory('stash', inside.stash)
            end,
        },
    })
end)

--- Leaving on a key rather than only on a target option.
---
--- A shell has no door prop to aim at, so without this the only way out would
--- be finding the one spot the exit option resolves at. E is the same key every
--- other interaction on this server uses.
CreateThread(function()
    while true do
        local wait = 500

        if Interior.Current() then
            wait = 0
            exports['som-interact']:showTextUI('Leave', { key = 'E' })

            if IsControlJustReleased(0, 38) then
                exports['som-interact']:hideTextUI()
                leave()
            end
        elseif exports['som-interact']:isTextUIOpen() then
            exports['som-interact']:hideTextUI()
        end

        Wait(wait)
    end
end)
