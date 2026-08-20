-- The dealership, client half.
--
-- Thin, like the garage half it sits next to. It shows what the server sent and
-- posts back a model NAME. It never sees a price it is trusted on, never
-- decides who may buy, and never spawns anything: even a test drive car is
-- created and destroyed by the server.
--
-- The panel is som-garage's, shared through the `Panel` table in garage.lua.
-- See the comment there for why the dealership lives in this resource.

local core = exports['som-core']

Dealership = {}

local zones = {}
local blips = {}
local offer = nil
local drive = nil

local function handle(res, failure)
    if not res or not res.success then
        TriggerEvent('som:client:notify',
            (res and res.error) or failure or 'That did not work', 'error')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Opening
-- ---------------------------------------------------------------------------

---@param shopId string
local function open(shopId)
    if Panel.IsOpen() then return end

    local res = lib.callback.await('som-garage:server:shopList', false, shopId)
    if not handle(res) then return end

    Panel.Show(res, 'shop')
end

-- ---------------------------------------------------------------------------
-- Buying
--
-- Called by garage.lua's `buy` NUI callback when the panel is in shop mode, so
-- there is still exactly one handler for that action.
--
-- A managed shop refuses the self-serve path on the SERVER as well. This branch
-- is what makes the refusal legible rather than an error: at a managed shop the
-- button asks a dealer to sell, and only a dealer's own client reaches the
-- offer callback at all.
-- ---------------------------------------------------------------------------

---@param data table from the page
---@param cb function the NUI callback
function Dealership.Buy(data, cb)
    local shopId = Panel.shop
    local shop = shopId and Config.Shops[shopId]

    if not shop then return cb({ success = false, error = 'invalid request' }) end

    if shop.type == 'managed' then
        -- Only a dealer can turn the button into a sale, and only for somebody
        -- standing with them. Everybody else is told what to do instead.
        if not core:hasJob(shop.job, 0, true) then
            return cb({
                success = false,
                error = 'a member of staff has to sell you that',
            })
        end

        -- The buyer is whoever is standing with the dealer, rather than a
        -- server id typed into a box. That is the out of character step AUDIT
        -- 10.1 exists to remove, and the server checks the same distance again.
        --
        -- getClosestPlayer returns a LOCAL player index, not a server id.
        local nearby = lib.getClosestPlayer(GetEntityCoords(cache.ped),
            Config.Dealership.saleDistance or 8.0, false)

        if not nearby then
            return cb({ success = false, error = 'nobody is standing with you' })
        end

        local res = lib.callback.await('som-garage:server:offerVehicle', false, {
            shop = shopId,
            model = data.model,
            target = GetPlayerServerId(nearby),
        })

        cb(res or { success = false })

        if res and res.success then
            TriggerEvent('som:client:notify',
                ('Offered the %s. Waiting on them.'):format(res.label), 'info')
        end

        return
    end

    local res = lib.callback.await('som-garage:server:buyShopVehicle', false, {
        shop = shopId,
        model = data.model,
        account = data.account,
    })

    cb(res or { success = false })

    if res and res.success then
        TriggerEvent('som:client:notify',
            ('Bought. Plate %s, parked at %s.'):format(res.plate, res.garage), 'success')
        Panel.Close()
    end
end

-- ---------------------------------------------------------------------------
-- Being offered a car
--
-- The buyer sees the price and the seller's name and picks how to pay. The
-- server re-checks every part of this when the answer comes back, so nothing
-- here is a decision, only a question.
-- ---------------------------------------------------------------------------

RegisterNetEvent('som-garage:client:vehicleOffer', function(data)
    if type(data) ~= 'table' then return end

    offer = data

    CreateThread(function()
        -- Payment options come WITH the offer rather than from a second
        -- callback. One round trip, and the balances shown are the ones the
        -- server had when it made the offer.
        local payment = data.payment

        local rows = {
            {
                type = 'select',
                label = 'Pay with',
                required = true,
                options = (function()
                    local out = {}
                    for _, option in ipairs(payment or {}) do
                        out[#out + 1] = {
                            value = option.account,
                            label = ('%s ($%s)'):format(option.label, option.balance),
                        }
                    end
                    return out
                end)(),
            },
        }

        local picked = lib.inputDialog(
            ('%s: $%s'):format(data.vehicleLabel or data.model, data.price), rows)

        if not offer then return end

        if not picked or not picked[1] then
            lib.callback.await('som-garage:server:declineVehicle', false)
            offer = nil
            return
        end

        local res = lib.callback.await('som-garage:server:acceptVehicle', false, {
            account = picked[1],
        })

        offer = nil

        if not handle(res) then return end

        TriggerEvent('som:client:notify',
            ('Bought. Plate %s, parked at %s.'):format(res.plate, res.garage), 'success')
    end)
end)

-- ---------------------------------------------------------------------------
-- Test drives
--
-- The server owns the timer and the deletion. This half puts the player in the
-- seat and shows them the clock, and if it is wrong about either of those the
-- car still goes back.
-- ---------------------------------------------------------------------------

---@param shopId string
---@param model string
local function testDrive(shopId, model)
    if drive then
        TriggerEvent('som:client:notify', 'You are already in one', 'error')
        return
    end

    local res = lib.callback.await('som-garage:server:testDrive', false, {
        shop = shopId,
        model = model,
    })

    if not handle(res) then return end

    Panel.Close()

    local deadline = GetGameTimer() + (res.seconds * 1000)
    drive = { netId = res.netId, deadline = deadline }

    -- The entity is not addressable the instant the server reports it.
    local entity
    local wait = GetGameTimer() + 5000

    while GetGameTimer() < wait do
        entity = NetworkDoesNetworkIdExist(res.netId)
            and NetToVeh(res.netId) or nil

        if entity and entity ~= 0 and DoesEntityExist(entity) then break end
        Wait(50)
    end

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetPedIntoVehicle(cache.ped, entity, -1)
    end

    TriggerEvent('som:client:notify',
        ('Test drive: %s, %d seconds.'):format(res.label, res.seconds), 'info')

    CreateThread(function()
        while drive and GetGameTimer() < drive.deadline do
            local left = math.ceil((drive.deadline - GetGameTimer()) / 1000)

            -- The clock only appears in the last ten seconds. A countdown
            -- running the whole time is a timer to watch rather than a car to
            -- drive, and the point of a test drive is the car.
            if left <= 10 then
                exports['som-interact']:showTextUI(
                    ('Test drive ends in %d'):format(left))
            end

            Wait(500)
        end

        exports['som-interact']:hideTextUI()
    end)
end

RegisterNetEvent('som-garage:client:testDriveOver', function()
    if not drive then return end

    drive = nil
    exports['som-interact']:hideTextUI()
    TriggerEvent('som:client:notify', 'Test drive over.', 'info')
end)

RegisterNUICallback('testDrive', function(data, cb)
    if not Panel.IsOpen() or Panel.mode ~= 'shop' or type(data) ~= 'table' then
        return cb({ success = false, error = 'invalid request' })
    end

    cb({ success = true })

    local shopId = Panel.shop

    -- Own thread: testDrive yields on a callback and on the entity arriving,
    -- and a NUI callback handler is not a context to assume that is legal in.
    CreateThread(function() testDrive(shopId, data.model) end)
end)

-- ---------------------------------------------------------------------------
-- Zones and blips
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not Config.Shops then return end

    for shopId, shop in pairs(Config.Shops) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = ('som_shop_%s'):format(shopId),
            coords = shop.coords,
            radius = 2.0,
            options = {
                {
                    name = 'som_shop_browse',
                    label = shop.type == 'managed' and 'Browse the showroom' or 'Browse the lot',
                    icon = 'fa-solid fa-car-side',
                    distance = 2.5,
                    canInteract = function()
                        return not cache.vehicle
                    end,
                    onSelect = function() open(shopId) end,
                },
            },
        })

        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)

            SetBlipSprite(blip, shop.blip.sprite)
            SetBlipColour(blip, shop.blip.colour)
            SetBlipScale(blip, shop.blip.scale)
            SetBlipAsShortRange(blip, true)
            SetBlipDisplay(blip, 4)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.label)
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #blips do RemoveBlip(blips[i]) end

    for i = 1, #zones do
        exports['som-interact']:removeZone(zones[i])
    end

    exports['som-interact']:hideTextUI()
end)
