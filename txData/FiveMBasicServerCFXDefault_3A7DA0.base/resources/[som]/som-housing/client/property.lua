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
---
--- INFORMATION ONLY. Buying moved into the Properties app on the phone, which
--- lists what is for sale within reach of wherever you are standing. The door
--- still tells you what the place is, because reading a For Sale sign should
--- not require taking your phone out.
---@param slug string
local function inspect(slug)
    local res = lib.callback.await('som-housing:server:inspect', false, slug)

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Nothing to see', 'error')
    end

    if res.forSale then
        return TriggerEvent('som:client:notify',
            ('%s Open Properties on your phone to buy it.'):format(res.text), 'inform')
    end

    TriggerEvent('som:client:notify', res.text, res.owned and 'inform' or 'error')
end

--- Forcing a door.
---
--- Loud, slow and always possible. The warrant is not checked here and does not
--- gate anything: the server records whether one existed, which is the
--- consequence. Deciding to go in without one is the interesting choice and
--- taking it away would be the wrong kind of safe.
---@param slug string
local function breach(slug)
    local options = {
        { value = 'ram', label = 'Battering ram (fast, loud)' },
        { value = 'lockpick', label = 'Lockpick (slow, quiet, can fail)' },
    }

    local answer = lib.inputDialog('Force entry', {
        { type = 'select', label = 'How', options = options, required = true },
    })

    if not answer or not answer[1] then return end

    local method = answer[1]
    local tool = Config.Raid[method]

    if not lib.progressBar({
        duration = tool.duration,
        label = method == 'ram' and 'Forcing the door' or 'Working the lock',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
    }) then
        return
    end

    -- The lockpick can fail. Rolled on the client because it costs nothing and
    -- decides nothing: a client that skipped the roll would still have to get
    -- past every check the server makes next.
    if method == 'lockpick' and math.random() < tool.failChance then
        return TriggerEvent('som:client:notify', 'The lock held', 'error')
    end

    local res = lib.callback.await('som-housing:server:breach', false, { slug = slug, method = method })

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'It did not give', 'error')
    end

    TriggerEvent('som:client:notify',
        res.lawful and ('Door forced. Warrant on file, %d minutes.'):format(res.minutes)
                    or ('Door forced. NO WARRANT ON FILE. %d minutes.'):format(res.minutes),
        res.lawful and 'success' or 'warning')
end

--- Writing a mortgage, from the estate agent's side.
---
--- The realtor calls this, not the buyer, which is why the buyer is an argument
--- and the caller is the one validated. A buyer cannot write themselves one.
---@param slug string
local function mortgage(slug)
    local nearby = lib.callback.await('som-housing:server:nearbyBuyers', false)

    if not nearby or not nearby.success or #nearby.players == 0 then
        return TriggerEvent('som:client:notify', 'Nobody is standing with you', 'error')
    end

    local people = {}
    for i, person in ipairs(nearby.players) do
        people[i] = { value = person.source, label = person.name }
    end

    local answer = lib.inputDialog('Sell on finance', {
        { type = 'select', label = 'Buyer', options = people, required = true },
        { type = 'number', label = 'Payments', min = Config.Finance.minCycles,
          max = Config.Finance.maxCycles, default = 8, required = true },
    })

    if not answer or not answer[1] then return end

    local res = lib.callback.await('som-housing:server:mortgage', false, {
        slug = slug,
        buyer = answer[1],
        cycles = answer[2],
        -- The BUYER's deposit comes off their bank. They agreed to the deal by
        -- standing here; picking the account is not a decision worth a second
        -- dialog on somebody else's screen.
        account = 'bank',
    })

    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Could not write it', 'error')
    end

    TriggerEvent('som:client:notify',
        ('%s sold. %d payments, your cut $%d.'):format(res.label, res.cycles, res.commission), 'success')
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
                    name = ('property:%s:breach'):format(property.slug),
                    icon = 'fa-solid fa-hammer',
                    label = ('Force the door'),
                    distance = 2.0,
                    -- A UI filter. The server re-checks the job, the duty, the
                    -- tool and the distance, and records the raid either way.
                    canInteract = function()
                        return core:hasJob(Config.Raid.job, nil, true)
                    end,
                    onSelect = function() breach(property.slug) end,
                },
                {
                    name = ('property:%s:mortgage'):format(property.slug),
                    icon = 'fa-solid fa-file-signature',
                    label = ('Sell on finance'),
                    distance = 2.0,
                    canInteract = function()
                        return core:hasJob(Config.Finance.job, nil, true)
                    end,
                    onSelect = function() mortgage(property.slug) end,
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
        {
            name = 'property:furnish',
            icon = 'fa-solid fa-couch',
            label = 'Furnish',
            distance = 1.8,
            canInteract = function()
                return Interior.Current() ~= nil
            end,
            onSelect = function() Furniture.Menu() end,
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
