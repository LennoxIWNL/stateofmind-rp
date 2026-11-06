-- Fakes the handful of cross-resource exports the fixes under test actually
-- call. Tests flip the *Fails flags and read the call counters rather than
-- re-implementing som-core/som-economy/som-phone here.

local Mocks = {}

Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0, dispatchAlert = 0, businessTransact = 0 }
Mocks.admins = {}
Mocks.perks = {}
Mocks.voice = {}
Mocks.metadataRefused = false
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
function core:getPlayersByGang(gang)
    local out = {}
    for source, player in pairs(Mocks.players) do
        if player.gang and player.gang.name == gang then
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
    if Mocks.addMoneyThrows then error('simulated crash after the treasury was debited') end
    if Mocks.addMoneyFails then return false, 'refused' end
    Mocks.paid = (Mocks.paid or 0) + amount
    Mocks.lastPaid = { account = account, amount = amount, reason = reason }
    return true
end
Mocks.gangDefs = {
    none = { label = 'No Gang', grades = { [0] = { name = 'Unaffiliated' } } },
    ballas = { label = 'Ballas', grades = { [0] = { name = 'Recruit' }, [1] = { name = 'Member' }, [2] = { name = 'Shot Caller' }, [3] = { name = 'Lieutenant' }, [4] = { name = 'Boss', isboss = true } } },
}
Mocks.gangFunds = {}
Mocks.bank = {}
function core:getGangs() return Mocks.gangDefs end
function core:setGang(source, gang, grade)
    local def = Mocks.gangDefs[gang]
    local p = Mocks.players[source]
    if not def or not p or not def.grades[grade] then return false end
    p.gang = { name = gang, label = def.label, grade = grade, gradeLabel = def.grades[grade].name, isboss = def.grades[grade].isboss or false }
    return true
end
function core:getGangBalance(gang) return Mocks.gangFunds[gang] or 0 end
function core:gangTransact(gang, amount, reason)
    if Mocks.gangFails then return false, 'refused' end
    local balance = (Mocks.gangFunds[gang] or 0) + amount
    if balance < 0 then return false, 'insufficient gang funds' end
    Mocks.gangFunds[gang] = balance
    Mocks.gangLedger = Mocks.gangLedger or {}
    Mocks.gangLedger[#Mocks.gangLedger + 1] = { gang = gang, amount = amount, reason = reason }
    return true
end
function core:taxToTreasury(amount, reason)
    if Mocks.taxFails then return false, 'refused' end
    Mocks.treasury = Mocks.treasury + amount
    return true
end
function core:removeMoney(source, account, amount, reason)
    if (Mocks.bank[source] or 0) < amount then return false, 'insufficient funds' end
    Mocks.bank[source] = Mocks.bank[source] - amount
    return true
end
function core:businessTransact(name, amount, reason)
    Mocks.calls.businessTransact = Mocks.calls.businessTransact + 1
    Mocks.lastTransact = { name = name, amount = amount }
    return true
end
function core:treasuryTransact(delta, reason)
    Mocks.treasury = Mocks.treasury or 0
    if Mocks.treasury + delta < 0 then return false, 'insufficient treasury funds' end
    Mocks.treasury = Mocks.treasury + delta
    return true
end
function core:hasPermission(source, ace)
    return Mocks.admins[source] == true
end
function core:hasPerk(source, perk) return Mocks.perks[source] ~= nil and Mocks.perks[source][perk] or false end
function core:getJobs() return Mocks.jobs end
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

function economy:issueEquipment(source, dept, item)
    Mocks.issued = { source = source, dept = dept, item = item }
    return not Mocks.issueFails, Mocks.issueFails and 'not employed by this department' or nil
end

function economy:getBusiness(name) return Mocks.businesses[name] end

local phone = {}
function phone:billCitizen(citizenid, business, amount, reason, opts)
    Mocks.bills = Mocks.bills or {}
    Mocks.bills[#Mocks.bills + 1] = { citizenid = citizenid, business = business, amount = amount, reason = reason, opts = opts }
    return 1
end
function phone:notifyApp(source, app, message)
    if Mocks.exported.notifyApp then return Mocks.exported.notifyApp(source, app, message) end
end

function phone:registerApp(app) Mocks.apps[app.id] = app; return true end

local dispatch = {}
function dispatch:alert(source, alertType, extra)
    Mocks.calls.dispatchAlert = Mocks.calls.dispatchAlert + 1
    Mocks.lastAlertType = alertType
    Mocks.lastAlertExtra = extra
    if Mocks.alertFails then return nil end
    return 1
end

local medical = {}
function medical:isDowned(ref) return Mocks.downed[ref] == true end
function medical:revive(ref, by)
    if Mocks.reviveFails or Mocks.downed[ref] ~= true then return false end
    Mocks.downed[ref] = nil
    Mocks.revived = { ref = ref, by = by }
    return true
end

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
function ox:SetMetadata(inv, slot, metadata)
    if Mocks.metadataRefused then return end
    for _, item in pairs(Mocks.inv[inv] or {}) do
        if item.slot == slot then item.metadata = metadata end
    end
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
function ox:CanCarryItem(inv, name, count) return not Mocks.invFull[inv] end
function ox:RemoveItem(inv, name, count, metadata, slot)
    local list = Mocks.inv[inv] or {}
    for k, item in pairs(list) do
        if item.name == name and (slot == nil or item.slot == slot) then
            if (item.count or 1) > (count or 1) then item.count = item.count - (count or 1) else list[k] = nil end
            return true
        end
    end
    return false
end

local progress = {}
function progress:addXp(source, track, amount)
    Mocks.xp = Mocks.xp or {}
    Mocks.xp[#Mocks.xp + 1] = { source = source, track = track, amount = amount }
    return amount, 1, false
end
function progress:hasLevel(source, track, n) return ((Mocks.levels and Mocks.levels[track]) or 1) >= (tonumber(n) or 1) end
function progress:getLevel(source, track) return (Mocks.levels and Mocks.levels[track]) or 1 end

local registry = {
    ['som-progress'] = progress,
    ['pma-voice'] = { setPlayerCall = function(_, source, channel) Mocks.voice[source] = channel end },
    ['som-medical'] = medical,
    ['som-evidence'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-court'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-jobboard'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-groups'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-hack'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['som-launder'] = setmetatable({}, { __index = function(_, name)
        local fn = Mocks.exported[name]
        return fn and function(_, ...) return fn(...) end or nil
    end }),
    ['ox_doorlock'] = setmetatable({}, { __index = function(_, name)
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
    -- A resource exporting its own function (exports('name', fn)), not
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
    addCommand = function(name, _, fn) Mocks.commands[name] = fn end,
}

return Mocks
