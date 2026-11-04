-- Fakes the handful of cross-resource exports the fixes under test actually
-- call. Tests flip the *Fails flags and read the call counters rather than
-- re-implementing som-core/som-economy/som-phone here.

local Mocks = {}

Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0, dispatchAlert = 0, businessTransact = 0 }
Mocks.admins = {}
Mocks.fines = {}
Mocks.fineFails = false
Mocks.exported = {}        -- name -> function, filled by exports(name, fn) in loaded resources
Mocks.downed = {}
Mocks.weapons = {}
Mocks.inv = {}              -- inventory id -> list of { name, count, metadata, slot }
Mocks.invFull = {}          -- inventory id -> true when AddItem must fail
Mocks.players = {}          -- players[source] = { citizenid = ..., job = ... }
Mocks.payWithFails = false
Mocks.businessSpendFails = false

local core = {}
function core:getPlayer(source) return Mocks.players[source] end
function core:getPlayers() return {} end
function core:getPlayersByJob(job, onDutyOnly)
    local out = {}
    for source, player in pairs(Mocks.players) do
        if player.job and player.job.name == job and (not onDutyOnly or player.job.onduty) then
            local copy = {}
            for k, v in pairs(player) do copy[k] = v end
            copy.source = source
            out[#out + 1] = copy
        end
    end
    return out
end
function core:getPlayerByCitizenId(citizenid)
    for source, player in pairs(Mocks.players) do
        if player.citizenid == citizenid then
            local copy = {}
            for k, v in pairs(player) do copy[k] = v end
            copy.source = source
            return copy
        end
    end
    return nil
end
function core:payWith(source, account, amount, reason)
    Mocks.calls.payWith = Mocks.calls.payWith + 1
    if Mocks.payWithFails then return false, 'insufficient funds' end
    return true
end
function core:addMoney(source, account, amount, reason)
    Mocks.calls.addMoney = Mocks.calls.addMoney + 1
    if Mocks.addMoneyFails then return false, 'refused' end
    Mocks.paid = (Mocks.paid or 0) + amount
    Mocks.lastPaid = { account = account, amount = amount, reason = reason }
    return true
end
function core:businessTransact(name, amount, reason)
    Mocks.calls.businessTransact = Mocks.calls.businessTransact + 1
    Mocks.lastTransact = { name = name, amount = amount }
    return true
end
function core:hasPermission(source, ace)
    return Mocks.admins[source] == true
end
function core:paymentOptions(source) return {} end
function core:getMetadata(source, key)
    local player = Mocks.players[source]
    return player and player.metadata and player.metadata[key] or nil
end
function core:setMetadata(source, key, value)
    local player = Mocks.players[source]
    if not player then return false end
    player.metadata = player.metadata or {}
    player.metadata[key] = value
    return true
end

local economy = {}
function economy:issueFine(source, targetId, amount, reason)
    if Mocks.fineFails then return false, 'fine refused' end
    Mocks.fines[#Mocks.fines + 1] = { by = source, target = targetId, amount = amount, reason = reason }
    return true, #Mocks.fines
end
function economy:businessSpend(name, amount, reason)
    Mocks.calls.businessSpend = Mocks.calls.businessSpend + 1
    return not Mocks.businessSpendFails
end

local phone = {}
function phone:billCitizen(citizenid, business, amount, reason, opts) return 1 end
function phone:notifyApp(source, app, message) end

local dispatch = {}
function dispatch:alert(source, alertType, extra)
    Mocks.calls.dispatchAlert = Mocks.calls.dispatchAlert + 1
    Mocks.lastAlertType = alertType
    return 1
end

local medical = {}
function medical:isDowned(ref) return Mocks.downed[ref] == true end

local ox = {}
function ox:Search(inv, mode, name)
    local slots, count = {}, 0
    for _, item in pairs(Mocks.inv[inv] or {}) do
        if item.name == name then
            slots[#slots + 1] = item
            count = count + (item.count or 1)
        end
    end
    return mode == 'count' and count or slots
end
function ox:GetCurrentWeapon(inv) return Mocks.weapons[inv] end
function ox:RegisterStash(id) Mocks.inv[id] = Mocks.inv[id] or {} end
function ox:GetInventoryItems(inv) return Mocks.inv[inv] end
function ox:AddItem(inv, name, count, metadata)
    -- A full pack still takes back the empty bag it just gave up, which freed a slot.
    if Mocks.invFull[inv] and name ~= 'empty_evidence_bag' then return false end
    Mocks.inv[inv] = Mocks.inv[inv] or {}
    Mocks.slot = (Mocks.slot or 0) + 1
    Mocks.inv[inv][Mocks.slot] = { name = name, count = count, metadata = metadata, slot = Mocks.slot }
    return true
end
function ox:RemoveItem(inv, name, count, metadata, slot)
    local list = Mocks.inv[inv] or {}
    for k, item in pairs(list) do
        if item.name == name and (slot == nil or item.slot == slot) then list[k] = nil; return true end
    end
    return false
end

local registry = {
    ['som-medical'] = medical,
    ['som-evidence'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-court'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['ox_inventory'] = ox,
    ['som-core'] = core,
    ['som-economy'] = economy,
    ['som-phone'] = phone,
    ['som-dispatch'] = dispatch,
}

_G.exports = setmetatable({}, {
    __index = function(_, name)
        return registry[name] or error('export not mocked: ' .. tostring(name), 2)
    end,
    -- A resource exporting its own function (exports('name', fn)) — not
    -- needed by these tests, so a no-op rather than a real registry.
    __call = function(_, name, fn) Mocks.exported[name] = fn end,
})

_G.Mocks = Mocks

local libCallbacks = {}
_G.RegisteredCallbacks = libCallbacks
_G.lib = {
    callback = {
        register = function(name, fn) libCallbacks[name] = fn end,
    },
}

return Mocks
