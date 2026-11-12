--- Estate agent sales. An on duty agent shows a property to a buyer standing at the door; once the buyer
--- has accepted the viewing (which also lets both of them through the door for a few minutes) the agent
--- offers the sale, and the buyer's answer completes it. The price goes from the buyer to the agency's
--- business account, and the commission is paid out of that account, only after its debit succeeded.
--- This is the only way to buy a realtor_only property outright. Made by Lennox.

local core = exports['som-core']

Agent = {}

-- Keyed by the buyer's citizenid. stage is 'viewing' (offered), 'viewed' (accepted) or 'selling' (priced offer out).
local offers = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function whole(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

local function nameOf(player)
    local info = player.charinfo
    return info and ('%s %s'):format(info.firstname, info.lastname) or 'An agent'
end

local function validAgent(player)
    local job = player and player.job
    return job and job.name == Config.Finance.job and job.onduty == true
end

local function atDoor(source, property)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local door = vec3(property.door_x, property.door_y, property.door_z)
    return #(GetEntityCoords(ped) - door) <= Config.Purchase.distance
end

---Whether the property can still be sold by an agent right now.
local function sellable(property)
    return property and property.for_sale == 1 and not Ownership.OwnerOf(property.id)
end

---A viewed property lets the buyer and the agent in until the offer runs out, or until somebody owns it.
---@return boolean
function Agent.IsViewing(citizenid, propertyId)
    if Ownership.OwnerOf(propertyId) then return false end

    local now = os.time()
    for buyer, offer in pairs(offers) do
        if offer.property == propertyId and offer.stage ~= 'viewing' and offer.expires >= now
            and (buyer == citizenid or offer.agent == citizenid) then
            return true
        end
    end
    return false
end

---Gives the buyer their money back. A refund that fails is logged for staff, never retried into a loop.
local function refundBuyer(source, citizenid, price, slug)
    if not core:addMoney(source, 'bank', price, 'property-refund') then
        print(('[som-housing] agent sale of %s: could not refund %s, refund $%d by hand'):format(slug, citizenid, price))
    end
end

---Reads the agent, the property and the buyer shared by both agent steps. Returns the failure otherwise.
local function resolveSale(source, data)
    if type(data) ~= 'table' then return nil, done(false, 'bad request') end

    local agent = core:getPlayer(source)
    if not validAgent(agent) then return nil, done(false, 'only an estate agent on duty can do this') end

    local property = type(data.slug) == 'string' and Properties.BySlug(data.slug)
    if not property then return nil, done(false, 'no such property') end
    if not sellable(property) then return nil, done(false, 'not for sale') end

    local buyerSource = whole(data.buyer, 1, 65535)
    local buyer = buyerSource and buyerSource ~= source and core:getPlayer(buyerSource)
    if not buyer then return nil, done(false, 'that buyer is not here') end
    if buyer.citizenid == agent.citizenid then return nil, done(false, 'you cannot sell to yourself') end

    if not (atDoor(source, property) and atDoor(buyerSource, property)) then
        return nil, done(false, 'both of you must be at the property')
    end

    return { agent = agent, property = property, buyer = buyer, buyerSource = buyerSource }
end

lib.callback.register('som-housing:server:agentShow', function(source, data)
    local sale, failure = resolveSale(source, data)
    if not sale then return failure end

    -- Another agent's live offer is not wiped by a second agent showing the same buyer something.
    local live = offers[sale.buyer.citizenid]
    if live and live.agent ~= sale.agent.citizenid and live.expires >= os.time() then
        return done(false, 'they are already talking to another agent')
    end

    offers[sale.buyer.citizenid] = {
        property = sale.property.id, agent = sale.agent.citizenid, agentSource = source,
        stage = 'viewing', expires = os.time() + Config.Agent.offerSeconds,
    }
    TriggerClientEvent('som-housing:client:agentViewing', sale.buyerSource, sale.property.label, sale.property.price, nameOf(sale.agent))
    return done(true)
end)

lib.callback.register('som-housing:server:agentViewAnswer', function(source, accept)
    local buyer = core:getPlayer(source)
    if not buyer or type(accept) ~= 'boolean' then return done(false, 'not available') end

    local offer = offers[buyer.citizenid]
    if not offer or offer.stage ~= 'viewing' or offer.expires < os.time() then
        offers[buyer.citizenid] = nil
        return done(false, 'that offer is gone')
    end

    if not accept then
        offers[buyer.citizenid] = nil
        return done(true)
    end

    offer.stage = 'viewed'
    offer.expires = os.time() + Config.Agent.saleWindowMinutes * 60
    return done(true)
end)

lib.callback.register('som-housing:server:agentSell', function(source, data)
    local sale, failure = resolveSale(source, data)
    if not sale then return failure end

    -- The grade gate is a single threshold, for the tier that only an agent can sell.
    if sale.property.realtor_only == 1 and (sale.agent.job.grade or 0) < Config.Agent.approveGrade then
        return done(false, 'a more senior agent has to close this one')
    end

    local offer = offers[sale.buyer.citizenid]
    if not offer or offer.agent ~= sale.agent.citizenid or offer.property ~= sale.property.id
        or offer.stage ~= 'viewed' or offer.expires < os.time() then
        return done(false, 'show them the property first')
    end

    offer.stage = 'selling'
    offer.expires = os.time() + Config.Agent.offerSeconds
    TriggerClientEvent('som-housing:client:agentSale', sale.buyerSource, sale.property.label, sale.property.price, nameOf(sale.agent))
    return done(true)
end)

lib.callback.register('som-housing:server:agentSellAnswer', function(source, accept)
    local buyer = core:getPlayer(source)
    if not buyer or type(accept) ~= 'boolean' then return done(false, 'not available') end

    local offer = offers[buyer.citizenid]
    if not offer or offer.stage ~= 'selling' or offer.expires < os.time() then
        offers[buyer.citizenid] = nil
        return done(false, 'that offer is gone')
    end
    offers[buyer.citizenid] = nil
    if not accept then return done(true) end

    -- Everything is read again: the agent may have gone off duty and the property may have been sold.
    local agent = core:getPlayer(offer.agentSource)
    if not agent or agent.citizenid ~= offer.agent or not validAgent(agent) then return done(false, 'the agent is no longer here') end

    local property = Properties.ById(offer.property)
    if not sellable(property) then return done(false, 'not for sale') end
    if property.realtor_only == 1 and (agent.job.grade or 0) < Config.Agent.approveGrade then return done(false, 'a more senior agent has to close this one') end
    if not (atDoor(source, property) and atDoor(offer.agentSource, property)) then return done(false, 'both of you must be at the property') end
    if Ownership.OwnedCount(buyer.citizenid) >= Config.Purchase.maxOwned then
        return done(false, ('you already own %d properties'):format(Config.Purchase.maxOwned))
    end

    if not Properties.Claim(property.id) then return done(false, 'somebody already bought it') end

    local price = property.price
    local reason = ('property:%s'):format(property.slug)
    local paid, payErr = core:payWith(source, 'bank', price, reason)
    if not paid then
        Properties.Release(property.id)
        return done(false, payErr or 'could not pay')
    end

    if not core:businessTransact(Config.Finance.business, price, reason) then
        refundBuyer(source, buyer.citizenid, price, property.slug)
        Properties.Release(property.id)
        return done(false, 'could not register the sale')
    end

    if not Ownership.Grant(property.id, buyer.citizenid, 'owner', agent.citizenid) then
        -- Only refunded from money the agency still holds; otherwise staff have to settle it by hand.
        if core:businessTransact(Config.Finance.business, -price, 'property-refund') then
            refundBuyer(source, buyer.citizenid, price, property.slug)
        else
            print(('[som-housing] agent sale of %s failed after payment and the agency could not refund %s, refund $%d by hand'):format(property.slug, buyer.citizenid, price))
        end
        Properties.Release(property.id)
        return done(false, 'could not register the sale')
    end

    -- Paid out of the agency's account, and only if that debit worked.
    local commission = math.floor(price * Config.Agent.commission)
    -- The server id may have been recycled during the yields above, so pay the character, not the id.
    local payee = core:getPlayerByCitizenId(offer.agent)
    if commission > 0 and payee then
        if core:businessTransact(Config.Finance.business, -commission, ('commission:%s'):format(agent.citizenid)) then
            if core:addMoney(payee.source, 'bank', commission, ('property-commission:%s'):format(property.slug)) then
                TriggerClientEvent('som:client:notify', payee.source, ('%s sold. Your commission is $%d.'):format(property.label, commission), 'success')
            elseif not core:businessTransact(Config.Finance.business, commission, ('commission:%s:refund'):format(agent.citizenid)) then
                print(('[som-housing] agent sale of %s: commission $%d left the agency but %s was not paid, settle it by hand'):format(property.slug, commission, agent.citizenid))
            end
        end
    end

    return done(true, nil, { label = property.label, price = price })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then offers[citizenid] = nil end
end)
