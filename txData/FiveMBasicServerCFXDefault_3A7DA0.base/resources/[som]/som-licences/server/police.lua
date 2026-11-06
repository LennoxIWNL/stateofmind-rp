local core = exports['som-core']

local ACTIONS = { suspend = true, revoke = true, reinstate = true }

---The on-duty officer and the person in front of them, both re-derived here.
---@return table|nil officer, table|nil target, string|nil err
local function officerAndTarget(source, targetId)
    local officer = core:getPlayer(source)
    if not officer or officer.job.name ~= Config.job or not officer.job.onduty then
        return nil, nil, 'you are not on duty'
    end

    if math.type(targetId) ~= 'integer' or targetId == source then return nil, nil, 'nobody there' end

    local target = core:getPlayer(targetId)
    if not target then return nil, nil, 'nobody there' end

    local a, b = GetPlayerPed(source), GetPlayerPed(targetId)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.police.distance then
        return nil, nil, 'too far away'
    end

    return officer, target
end

lib.callback.register('som-licences:server:check', function(source, targetId)
    local _, target, err = officerAndTarget(source, targetId)
    if not target then return { success = false, error = err } end

    local status = Licences.Status(target.citizenid)
    local lines = {}
    for kind, def in pairs(Config.types) do
        local s = status[kind]
        lines[#lines + 1] = ('%s: %s%s'):format(def.label, s and s.state or 'none',
            s and s['until'] and (' until ' .. s['until']) or '')
    end
    table.sort(lines)

    return { success = true, name = ('%s %s'):format(target.charinfo.firstname, target.charinfo.lastname), lines = lines }
end)

lib.callback.register('som-licences:server:act', function(source, targetId, kind, action, days)
    local officer, target, err = officerAndTarget(source, targetId)
    if not target then return { success = false, error = err } end
    if officer.job.grade < Config.approveGrade then return { success = false, error = 'your rank cannot do that' } end
    if type(kind) ~= 'string' or not Config.types[kind] or not ACTIONS[action] then
        return { success = false, error = 'bad request' }
    end

    local cid = target.citizenid
    local changed
    if action == 'suspend' then
        if math.type(days) ~= 'integer' or days < 1 or days > Config.police.maxSuspendDays then
            return { success = false, error = ('1 to %d days'):format(Config.police.maxSuspendDays) }
        end
        changed = MySQL.update.await('UPDATE som_licenses SET suspended_until = DATE_ADD(NOW(), INTERVAL ? DAY) WHERE citizenid = ? AND type = ? AND revoked = 0', { days, cid, kind })
    elseif action == 'revoke' then
        changed = MySQL.update.await('UPDATE som_licenses SET revoked = 1, suspended_until = NULL WHERE citizenid = ? AND type = ? AND revoked = 0', { cid, kind })
    else
        changed = MySQL.update.await('UPDATE som_licenses SET revoked = 0, suspended_until = NULL WHERE citizenid = ? AND type = ?', { cid, kind })
    end

    if not changed or changed < 1 then return { success = false, error = 'they have no such licence' } end

    Licences.Sync(target.source)
    TriggerClientEvent('som:client:notify', target.source,
        ('Your %s was %s'):format(Config.types[kind].label:lower(), action == 'reinstate' and 'reinstated' or (action .. (action == 'suspend' and 'ed' or 'd'))), 'error')

    return { success = true }
end)

local offers = {} -- buyer citizenid -> { officer = source, officerCid, expires = game ms }

lib.callback.register('som-licences:server:issueWeapon', function(source, targetId)
    local officer, target, err = officerAndTarget(source, targetId)
    if not target then return { success = false, error = err } end
    if officer.job.grade < Config.approveGrade then return { success = false, error = 'your rank cannot do that' } end
    if Licences.Status(target.citizenid).weapon then return { success = false, error = 'they already hold or have lost this licence' } end

    offers[target.citizenid] = { officer = source, officerCid = officer.citizenid, expires = GetGameTimer() + Config.weapon.offerSeconds * 1000 }
    TriggerClientEvent('som-licences:client:weaponOffer', target.source, Config.weapon.fee)
    return { success = true }
end)

-- The buyer's answer. Everything about the officer is checked again here, since
-- they may have gone off duty or walked away while the dialog was open.
lib.callback.register('som-licences:server:answerWeapon', function(source, accepted)
    local buyer = core:getPlayer(source)
    local offer = buyer and offers[buyer.citizenid]
    if not offer then return { success = false, error = 'no offer' } end
    offers[buyer.citizenid] = nil

    local function tell(text, kind)
        if core:getPlayer(offer.officer) then TriggerClientEvent('som:client:notify', offer.officer, text, kind) end
    end

    if accepted ~= true then
        tell('They declined the weapon licence', 'error')
        return { success = false }
    end
    if offer.expires < GetGameTimer() then return { success = false, error = 'the offer ran out' } end

    local officer, target, err = officerAndTarget(offer.officer, source)
    if not target or officer.citizenid ~= offer.officerCid or officer.job.grade < Config.approveGrade then
        return { success = false, error = err or 'the officer can no longer issue it' }
    end

    local ok, issueErr = Licences.Issue(source, 'weapon', Config.weapon.fee, function(amount, reason)
        return core:businessTransact(Config.weapon.business, amount, reason)
    end, officer.citizenid)

    tell(ok and 'Weapon licence issued' or issueErr, ok and 'success' or 'error')
    if ok then TriggerClientEvent('som:client:notify', source, 'Weapon licence issued', 'success') end
    return { success = ok, error = issueErr }
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid) offers[citizenid] = nil end)
