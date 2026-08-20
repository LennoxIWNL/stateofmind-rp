-- The dealerships.
--
-- Built on the purchase flow in fleet.lua, which was already correct and is the
-- reason this file is short: the client sends a MODEL NAME and nothing else,
-- the server re-resolves the entry from config, distance is checked here,
-- payWith moves the money with a ledger reason, a failed row write refunds in
-- full, and the selling business is credited so a sale MOVES money rather than
-- minting it.
--
-- Two shop types, per Config.Shops:
--
--   free     the client asks and the server sells, within a price cap
--   managed  a player with the dealer job offers a car to a named nearby
--            player, who confirms it. Neither half is trusted: the offer is
--            re-checked against the dealer's job and the buyer's distance at
--            the moment the buyer accepts, not at the moment it was made
--
-- Nothing in here spawns a car. A purchase writes a row and parks it in a real
-- garage; a test drive is the one exception and it is despawned by this file.

local core = exports['som-core']

-- ---------------------------------------------------------------------------
-- Resolving a shop
-- ---------------------------------------------------------------------------

---@param source number
---@param shopId any
---@return table|nil shop, string|nil error
local function resolveShop(source, shopId)
    if type(shopId) ~= 'string' then return nil, 'unknown shop' end

    local shop = Config.Shops[shopId]
    if not shop then return nil, 'unknown shop' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 'unknown shop' end

    if #(GetEntityCoords(ped) - shop.coords) > (Config.Dealership.distance or 20.0) then
        return nil, 'you are not at that dealership'
    end

    return shop
end

---Whether a model is on sale at a given shop.
---
---A price CAP rather than a model list, so the free lot and the managed
---showroom can never disagree about what they sell: raising a car's price in
---the catalogue takes it off the cheap lot on its own.
---@param shop table
---@param model any
---@return table|nil entry, string|nil error
local function shopEntry(shop, model)
    local entry = Catalogue.Entry(model)
    if not entry then return nil, 'not sold here' end
    if not entry.price or entry.price <= 0 then return nil, 'that is not for sale' end

    if shop.maxPrice and entry.price > shop.maxPrice then
        return nil, 'that is sold at the showroom, not here'
    end

    if not Catalogue.IsStreamed(entry.model) then
        return nil, 'that is not in stock'
    end

    return entry
end

---Whether a player is a dealer who may sell at this shop.
---
---Job only, never a client flag, and re-read from the live player rather than
---from anything the caller sent.
---@param player table
---@param shop table
---@return boolean
local function isDealer(player, shop)
    if shop.type ~= 'managed' then return false end
    if not shop.job then return false end

    local job = player.job
    return job ~= nil and job.name == shop.job and job.onduty == true
end

-- ---------------------------------------------------------------------------
-- The catalogue
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:shopList', function(source, shopId)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local shop, err = resolveShop(source, shopId)
    if not shop then return { success = false, error = err } end

    local dealer = isDealer(player, shop)

    -- A managed shop is BROWSABLE by anyone and only BUYABLE through a dealer.
    -- Owner's direction: cars are looked at before they are bought, and a
    -- showroom that shows nothing when the staff are off shift is a showroom
    -- nobody ever walks into.
    local catalogue = {}

    for _, entry in ipairs(Catalogue.Vehicles) do
        if shopEntry(shop, entry.model) then
            catalogue[#catalogue + 1] = {
                model = entry.model,
                label = entry.label,
                price = entry.price,
                category = entry.category,
                categoryLabel = Catalogue.CategoryLabel(entry.category),
            }
        end
    end

    local garage = Config.Garages[shop.deliverTo]

    return {
        success = true,
        mode = 'shop',
        shop = shopId,
        label = shop.label,
        shopType = shop.type,
        dealer = dealer,
        -- What the panel says under the Buy button, so the player knows where
        -- the car will be before they pay rather than after.
        deliverLabel = garage and garage.label or 'your garage',
        -- A shop has no owned vehicles. The panel opens on the Buy tab.
        vehicles = {},
        catalogue = catalogue,
        previewAt = {
            x = shop.preview.x, y = shop.preview.y,
            z = shop.preview.z, w = shop.preview.w,
        },
        testDrive = {
            allowed = true,
            seconds = Config.Dealership.testDrive.seconds,
            maxPrice = Config.Dealership.testDrive.maxPrice,
        },
        payment = core:paymentOptions(source),
    }
end)

-- ---------------------------------------------------------------------------
-- Selling
--
-- One function does the money and the row for both shop types, so a managed
-- sale and a self-serve one cannot drift apart. `buyer` is the source paying,
-- which is not always the source that asked.
-- ---------------------------------------------------------------------------

---@param buyer number source
---@param shopId string
---@param shop table
---@param entry table
---@param account any
---@return table result
local function sell(buyer, shopId, shop, entry, account)
    local player = core:getPlayer(buyer)
    if not player then return { success = false, error = 'buyer is not loaded' } end

    local paid, payError = core:payWith(buyer, account, entry.price,
        ('vehicle:%s'):format(entry.model))

    if not paid then return { success = false, error = payError or 'they cannot afford that' } end

    local created, createError = Vehicles.Create({
        citizenid = player.citizenid,
        model = entry.model,
        garage = shop.deliverTo,
        price = entry.price,
    })

    if not created then
        -- Refunded in full. Failing to write a row is not the buyer's fault.
        core:addMoney(buyer, account, entry.price, 'vehicle-refund')
        return { success = false, error = createError or 'could not register it' }
    end

    -- The dealership is paid for the car it just handed over, so a sale moves
    -- money rather than deleting it.
    if shop.business then
        core:businessTransact(shop.business, entry.price,
            ('vehicle-sale:%s'):format(created.plate))
    end

    local garage = Config.Garages[shop.deliverTo]

    return {
        success = true,
        plate = created.plate,
        model = entry.model,
        price = entry.price,
        garage = garage and garage.label or shop.deliverTo,
    }
end

-- ---------------------------------------------------------------------------
-- Free-use purchase
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:buyShopVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local shop, err = resolveShop(source, data.shop)
    if not shop then return { success = false, error = err } end

    -- A managed shop does not sell to itself. The path for that shop is an
    -- offer from a dealer, below, and refusing here is what stops a client
    -- calling the cheap path against the expensive stock.
    if shop.type ~= 'free' then
        return { success = false, error = 'a member of staff has to sell you that' }
    end

    local entry, entryError = shopEntry(shop, data.model)
    if not entry then return { success = false, error = entryError } end

    return sell(source, data.shop, shop, entry, data.account)
end)

-- ---------------------------------------------------------------------------
-- Managed sale
--
-- The dealer proposes; the buyer accepts; the server does both halves again at
-- the moment of acceptance. An offer is a message, not a promise: by the time
-- it is answered the dealer may have gone off duty, walked away, or quit the
-- job, and every one of those must void it.
-- ---------------------------------------------------------------------------

---Live offers, keyed by the BUYER's source. One at a time: a second offer to
---the same person replaces the first rather than queuing, so a buyer can never
---accept an offer they have forgotten about.
local offers = {}

local OFFER_SECONDS = 60

lib.callback.register('som-garage:server:offerVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local dealer = core:getPlayer(source)
    if not dealer then return { success = false, error = 'not loaded' } end

    local shop, err = resolveShop(source, data.shop)
    if not shop then return { success = false, error = err } end

    if not isDealer(dealer, shop) then
        return { success = false, error = 'you are not on duty here' }
    end

    local entry, entryError = shopEntry(shop, data.model)
    if not entry then return { success = false, error = entryError } end

    local target = tonumber(data.target)
    if not target or target == source then
        return { success = false, error = 'pick somebody to sell to' }
    end

    local buyer = core:getPlayer(target)
    if not buyer then return { success = false, error = 'they are not here' } end

    local dealerPed, buyerPed = GetPlayerPed(source), GetPlayerPed(target)
    if not buyerPed or buyerPed == 0 then return { success = false, error = 'they are not here' } end

    if #(GetEntityCoords(dealerPed) - GetEntityCoords(buyerPed))
        > (Config.Dealership.saleDistance or 8.0) then
        return { success = false, error = 'they need to be standing with you' }
    end

    offers[target] = {
        dealer = source,
        dealerCitizenid = dealer.citizenid,
        shop = data.shop,
        model = entry.model,
        expires = os.time() + OFFER_SECONDS,
    }

    TriggerClientEvent('som-garage:client:vehicleOffer', target, {
        shop = data.shop,
        label = shop.label,
        model = entry.model,
        vehicleLabel = entry.label,
        price = entry.price,
        seller = ('%s %s'):format(
            dealer.charinfo and dealer.charinfo.firstname or 'The',
            dealer.charinfo and dealer.charinfo.lastname or 'dealer'),
        seconds = OFFER_SECONDS,
        -- Sent with the offer so the buyer's dialog needs no second round trip.
        -- Resolved for the BUYER, not the dealer.
        payment = core:paymentOptions(target),
    })

    return { success = true, label = entry.label }
end)

lib.callback.register('som-garage:server:acceptVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local offer = offers[source]
    if not offer then return { success = false, error = 'nothing to accept' } end

    -- Cleared before anything else can fail, so a refused acceptance cannot be
    -- retried against the same offer.
    offers[source] = nil

    if os.time() > offer.expires then return { success = false, error = 'that offer expired' } end

    local shop = Config.Shops[offer.shop]
    if not shop then return { success = false, error = 'unknown shop' } end

    -- EVERYTHING is re-checked here rather than trusted from the offer. The
    -- dealer may have gone off duty, changed job, disconnected or walked off in
    -- the meantime, and the buyer may have walked out of the showroom.
    local dealer = core:getPlayer(offer.dealer)
    if not dealer or dealer.citizenid ~= offer.dealerCitizenid then
        return { success = false, error = 'the seller is no longer here' }
    end

    if not isDealer(dealer, shop) then
        return { success = false, error = 'the seller is no longer on duty' }
    end

    local _, err = resolveShop(source, offer.shop)
    if err then return { success = false, error = err } end

    local dealerPed, buyerPed = GetPlayerPed(offer.dealer), GetPlayerPed(source)
    if not dealerPed or dealerPed == 0 then
        return { success = false, error = 'the seller is no longer here' }
    end

    if #(GetEntityCoords(dealerPed) - GetEntityCoords(buyerPed))
        > (Config.Dealership.saleDistance or 8.0) then
        return { success = false, error = 'you have to be standing with the seller' }
    end

    local entry, entryError = shopEntry(shop, offer.model)
    if not entry then return { success = false, error = entryError } end

    local result = sell(source, offer.shop, shop, entry, data.account)
    if not result.success then
        TriggerClientEvent('som:client:notify', offer.dealer,
            ('Sale failed: %s'):format(result.error or 'unknown'), 'error')
        return result
    end

    -- Commission comes OUT of the business, which was just credited the full
    -- sale price, rather than being minted alongside it. A dealer earns a cut
    -- of a real sale and the business keeps the rest.
    local rate = tonumber(Config.Dealership.commission) or 0
    local cut = math.floor(entry.price * rate)

    if cut > 0 and shop.business then
        local taken = core:businessTransact(shop.business, -cut,
            ('vehicle-commission:%s'):format(result.plate))

        if taken then
            core:addMoney(offer.dealer, 'bank', cut,
                ('commission:%s'):format(result.plate))
        end
    end

    TriggerClientEvent('som:client:notify', offer.dealer,
        ('Sold. %s, plate %s.'):format(entry.label, result.plate), 'success')

    return result
end)

lib.callback.register('som-garage:server:declineVehicle', function(source)
    local offer = offers[source]
    offers[source] = nil

    if offer then
        TriggerClientEvent('som:client:notify', offer.dealer,
            'They turned it down.', 'info')
    end

    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Test drives
--
-- The despawn is enforced HERE. Both reference scripts set a client timer and a
-- state bag and delete the vehicle client side, and a test drive a player can
-- keep is a free car.
--
-- The car is never given a som_vehicles row, so there is nothing to keep even
-- if the deletion somehow fails: it cannot be stored, insured, sold or
-- retrieved, and the next restart takes it.
-- ---------------------------------------------------------------------------

---Live test drives, keyed by source.
local drives = {}

---A test drive car is deliberately NOT a som_vehicles row and does not go
---through Vehicles.Spawn.
---
---That is the safety net behind the timer rather than a shortcut. With no row
---it cannot be stored, insured, sold, impounded or retrieved, and ox_inventory
---gives it no glovebox or boot, because all of that keys off the `vehicleid`
---statebag this deliberately never sets. So even if the deletion failed
---outright, the worst outcome is a car in the street until the next restart
---rather than a free vehicle somebody owns.
---@param model string
---@param at vector4
---@return number|nil netId
local function spawnTestCar(model, at)
    local entity = CreateVehicle(joaat(model), at.x, at.y, at.z, at.w, true, true)

    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end

    if not DoesEntityExist(entity) then return nil end

    SetVehicleNumberPlateText(entity, 'TESTDRV')
    Entity(entity).state:set('som:testDrive', true, true)

    return NetworkGetNetworkIdFromEntity(entity)
end

---@param source number
local function endDrive(source)
    local drive = drives[source]
    if not drive then return end

    drives[source] = nil

    local entity = NetworkGetEntityFromNetworkId(drive.netId)

    -- DeleteEntity is server side here on purpose. Asking the client to delete
    -- it is asking the thing that wants to keep the car to give it back.
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    TriggerClientEvent('som-garage:client:testDriveOver', source)
end

lib.callback.register('som-garage:server:testDrive', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local shop, err = resolveShop(source, data.shop)
    if not shop then return { success = false, error = err } end

    if drives[source] then return { success = false, error = 'you are already in one' } end

    local entry, entryError = shopEntry(shop, data.model)
    if not entry then return { success = false, error = entryError } end

    local settings = Config.Dealership.testDrive

    if settings.maxPrice and entry.price > settings.maxPrice then
        return { success = false, error = 'that one is for looking at' }
    end

    local spawned = spawnTestCar(entry.model, shop.preview)
    if not spawned then return { success = false, error = 'could not bring it round' } end

    drives[source] = {
        netId = spawned,
        model = entry.model,
        endsAt = GetGameTimer() + (settings.seconds * 1000),
    }

    -- The timer is the server's. A client that never reports back still loses
    -- the car when this fires.
    SetTimeout(settings.seconds * 1000, function() endDrive(source) end)

    return {
        success = true,
        netId = spawned,
        seconds = settings.seconds,
        label = entry.label,
    }
end)

---Handing it back early. Ends the same drive the timer would have, and the
---timer finding nothing left is harmless.
RegisterNetEvent('som-garage:server:endTestDrive', function()
    endDrive(source)
end)

-- A test drive is not something that survives a disconnect. Without this the
-- car sits in the street until the timer fires against a source id that has
-- since been recycled onto somebody else.
AddEventHandler('playerDropped', function()
    local source = source
    offers[source] = nil

    for buyer, offer in pairs(offers) do
        if offer.dealer == source then offers[buyer] = nil end
    end

    endDrive(source)
end)
