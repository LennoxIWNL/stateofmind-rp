-- Fakes the handful of cross-resource exports the fixes under test actually
-- call. Tests flip the *Fails flags and read the call counters rather than
-- re-implementing som-core/som-economy/som-phone here.

local Mocks = {}

Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0, dispatchAlert = 0 }
Mocks.players = {}          -- players[source] = { citizenid = ..., job = ... }
Mocks.payWithFails = false
Mocks.businessSpendFails = false

local core = {}
function core:getPlayer(source) return Mocks.players[source] end
function core:getPlayers() return {} end
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
    return true
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

local registry = {
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
    __call = function(_, name, fn) end,
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
