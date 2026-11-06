--- Selling a car you own, out in the world, to the person next to you. The
--- server finds the car from its entity and plate, re-checks everything when the
--- buyer agrees, claims the ownership change first, then moves the money, and
--- undoes the claim if any money step fails.

local core = exports['som-core']

local offers = {} -- buyer source -> offer
local lastOffer = {} -- seller source -> game ms

local function done(ok, err, extra)
    local r = extra or {}
    r.success, r.error = ok == true, (not ok) and err or nil
    return r
end

local function plateOf(entity)
    local text = GetVehicleNumberPlateText(entity)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    return text ~= '' and text or nil
end

local function within(a, b, limit)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= limit
end

local function taxOf(price) return math.ceil(price * Config.taxRate) end

---The car as the database sees it, or why it cannot be sold by this seller now.
---@return table|nil row, string|nil err
local function sellable(seller, netId, expectedPlate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return nil, 'no such vehicle'
    end

    local plate = plateOf(entity)
    if not plate or (expectedPlate and plate ~= expectedPlate) then return nil, 'that is not the same vehicle' end

    local ped = GetPlayerPed(seller.source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > Config.vehicleDistance then
        return nil, 'you are not at that vehicle'
    end

    local row = MySQL.single.await([[
        SELECT id, citizenid, plate, model, state, owner_group, group_restricted, assigned_to, purchase_price
        FROM som_vehicles WHERE plate = ?
    ]], { plate })
    if not row or row.citizenid ~= seller.citizenid then return nil, 'that is not your vehicle' end
    if row.state ~= 'out' then return nil, 'take it out of the garage first' end
    if row.owner_group or row.group_restricted == 1 or row.group_restricted == true or row.assigned_to then
        return nil, 'a business, gang or department vehicle cannot be sold'
    end

    local key = plate:upper():gsub('%s+', '')
    local flags = MySQL.single.await([[
        SELECT
          (SELECT COUNT(*) FROM som_police_plates WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND cleared_at IS NULL) AS flagged,
          (SELECT COUNT(*) FROM mdt_vehicleinfo WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND stolen = 1) AS stolen
    ]], { key, key })
    if flags and (flags.flagged > 0 or flags.stolen > 0) then return nil, 'the police have a hold on that vehicle' end

    return row
end

lib.callback.register('som-carsales:server:offer', function(source, netId, targetId, price)
    local seller = core:getPlayer(source)
    if not seller then return done(false, 'not loaded') end

    if math.type(netId) ~= 'integer' or math.type(targetId) ~= 'integer' or math.type(price) ~= 'integer' then
        return done(false, 'bad request')
    end
    if price < Config.minPrice or price > Config.maxPrice then
        return done(false, ('the price must be $%d to $%d'):format(Config.minPrice, Config.maxPrice))
    end

    local now = GetGameTimer()
    if lastOffer[source] and now - lastOffer[source] < Config.offerCooldownSeconds * 1000 then return done(false, 'one moment') end
    lastOffer[source] = now

    local buyer = targetId ~= source and core:getPlayer(targetId)
    if not buyer or buyer.citizenid == seller.citizenid then return done(false, 'pick somebody to sell to') end
    if not within(source, targetId, Config.distance) then return done(false, 'they need to be standing with you') end

    local row, err = sellable(seller, netId)
    if not row then return done(false, err) end

    offers[targetId] = {
        seller = source, sellerCid = seller.citizenid, buyerCid = buyer.citizenid,
        netId = netId, plate = row.plate, price = price,
        expires = GetGameTimer() + Config.offerSeconds * 1000,
    }

    TriggerClientEvent('som-carsales:client:offer', targetId, {
        model = row.model, plate = row.plate, price = price, tax = taxOf(price),
        seller = ('%s %s'):format(seller.charinfo.firstname, seller.charinfo.lastname),
    })
    return done(true)
end)

local function call(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res == true
end

lib.callback.register('som-carsales:server:answer', function(source, accepted)
    local buyer = core:getPlayer(source)
    local offer = buyer and offers[source]
    if not offer then return done(false, 'no offer') end
    offers[source] = nil

    local function tell(text, kind)
        if core:getPlayer(offer.seller) then TriggerClientEvent('som:client:notify', offer.seller, text, kind) end
    end

    if accepted ~= true then
        tell('They turned down the offer', 'error')
        return done(false, 'declined')
    end
    if offer.expires < GetGameTimer() then return done(false, 'the offer ran out') end
    if buyer.citizenid ~= offer.buyerCid then return done(false, 'no offer') end

    local seller = core:getPlayer(offer.seller)
    if not seller or seller.citizenid ~= offer.sellerCid then return done(false, 'the seller is no longer here') end
    if not within(offer.seller, source, Config.distance) then return done(false, 'you have to be standing with the seller') end

    local row, err = sellable(seller, offer.netId, offer.plate)
    if not row then return done(false, err) end

    local price, tax = offer.price, taxOf(offer.price)
    local claimed = MySQL.update.await([[
        UPDATE som_vehicles SET citizenid = ?, purchase_price = ?
        WHERE id = ? AND citizenid = ? AND state = 'out' AND owner_group IS NULL AND group_restricted = 0 AND assigned_to IS NULL
    ]], { buyer.citizenid, price, row.id, seller.citizenid })
    if (claimed or 0) < 1 then return done(false, 'the vehicle is no longer for sale') end

    local function undo()
        MySQL.update.await('UPDATE som_vehicles SET citizenid = ?, purchase_price = ? WHERE id = ? AND citizenid = ?',
            { seller.citizenid, row.purchase_price or 0, row.id, buyer.citizenid })
    end
    local function refund() pcall(core.addMoney, core, source, 'bank', price, 'carsale:refund', { counterparty = seller.citizenid, flow = 'transfer' }) end

    if not call(core.removeMoney, core, source, 'bank', price, 'carsale:buy', { counterparty = seller.citizenid, flow = 'transfer' }) then
        undo()
        return done(false, ('you need $%d in the bank'):format(price))
    end

    if not call(core.taxToTreasury, core, tax, 'carsale:tax') then
        refund(); undo()
        return done(false, 'the sale could not be completed, nothing was charged')
    end

    local ok, paid = pcall(core.addMoney, core, offer.seller, 'bank', price - tax, 'carsale:sell', { counterparty = buyer.citizenid, flow = 'transfer' })
    if not (ok and paid) then
        pcall(core.treasuryTransact, core, -tax, 'carsale:tax_refund')
        refund(); undo()
        return done(false, 'the sale could not be completed, nothing was charged')
    end

    local logged, why = pcall(MySQL.insert.await, 'INSERT INTO som_vehicle_sales (vehicle_id, plate, seller, buyer, price, tax) VALUES (?, ?, ?, ?, ?, ?)',
        { row.id, row.plate, seller.citizenid, buyer.citizenid, price, tax })
    if not logged then print(('[som-carsales] audit row failed for %s: %s'):format(row.plate, tostring(why))) end

    tell(('Sold %s for $%d, you received $%d after tax. Empty the glovebox and boot if you have not'):format(row.plate, price, price - tax), 'success')
    return done(true, nil, { plate = row.plate, price = price })
end)

AddEventHandler('playerDropped', function() offers[source] = nil; lastOffer[source] = nil end)
