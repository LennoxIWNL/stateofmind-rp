--- Heists as job board providers. A tier is a provider; a site is a place. A
--- dongle (a ledger row, not just an item) starts a run, the hack is the
--- server's own puzzle, doors open through ox_doorlock, the police are told
--- through som-dispatch, and loot is paid in two separate currencies: clean
--- cash from the treasury under an hourly cap, and marked bills minted by
--- som-launder's ledger. The client only shows where to go.

local core = exports['som-core']
local ox = exports.ox_inventory

Heists = {}

local runs = {}
local byCitizen = {}
local treasuryBusy = false

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function log(text)
    local url = GetConvar('som_heist_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
end

local function usable(site)
    return site.enabled == true and site.terminal ~= nil and type(site.lootPoints) == 'table' and #site.lootPoints > 0
end

-- ---------------------------------------------------------------------------
-- Dongles
-- ---------------------------------------------------------------------------

local function newUid()
    return ('%08X%08X'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
end

---Issues a dongle: a ledger row plus an item that points at it.
---@param source number
---@param tag string
---@return string|nil uid, string|nil err
function Heists.MintDongle(source, tag)
    local uid = newUid()
    MySQL.insert.await('INSERT INTO som_heist_dongles (uid, source_tag) VALUES (?, ?)', { uid, tostring(tag):sub(1, 32) })

    if not ox:AddItem(source, Config.dongleItem, 1, { uid = uid }) then
        MySQL.update.await("UPDATE som_heist_dongles SET status = 'void' WHERE uid = ? AND status = 'issued'", { uid })
        return nil, 'could not carry it'
    end

    return uid
end

---The slot and uid of a dongle the ledger still calls issued, or nil.
---@param source number
---@return number|nil slot, string|nil uid
local function usableDongle(source)
    for _, item in ipairs(ox:Search(source, 'slots', Config.dongleItem) or {}) do
        local uid = item.metadata and item.metadata.uid
        if type(uid) == 'string' and uid:match('^%x+$') and #uid == 16 then
            local status = MySQL.scalar.await('SELECT status FROM som_heist_dongles WHERE uid = ?', { uid })
            if status == 'issued' then return item.slot, uid end
        end
    end
end

---Spends a dongle. The ledger claim comes first, so a duplicated item cannot
---start two runs.
local function spendDongle(source)
    local slot, uid = usableDongle(source)
    if not slot then return false end

    if MySQL.update.await("UPDATE som_heist_dongles SET status = 'used' WHERE uid = ? AND status = 'issued'", { uid }) ~= 1 then
        return false
    end

    ox:RemoveItem(source, Config.dongleItem, 1, nil, slot)
    return true
end

exports('mintDongle', Heists.MintDongle)

lib.addCommand('givedongle', {
    help = 'Issue a ledger backed Trojan USB',
    params = { { name = 'target', type = 'playerId', help = 'server id' } },
}, function(source, args)
    if source ~= 0 and not core:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source, 'You do not have permission to do that', 'error')
    end

    local uid, err = Heists.MintDongle(args.target, 'admin')
    local text = uid and ('Issued dongle %s'):format(uid) or ('Could not issue: %s'):format(err)
    if source ~= 0 then TriggerClientEvent('som:client:notify', source, text, 'inform') else print('[som-heists] ' .. text) end
end)

-- ---------------------------------------------------------------------------
-- Run state
-- ---------------------------------------------------------------------------

local function objective(run)
    local site = run.site
    if run.stage == 'hack' then
        return { kind = 'hack', coords = site.terminal, label = site.label .. ' terminal' }
    end

    return { kind = 'loot', index = run.next, coords = site.lootPoints[run.next], label = site.label .. ' loot' }
end

local function sendObjective(run)
    for _, s in pairs(run.members) do TriggerClientEvent('som-heists:client:objective', s, objective(run)) end
end

local function clear(groupId)
    local run = runs[groupId]
    if not run then return end

    runs[groupId] = nil
    for cid, source in pairs(run.members) do
        byCitizen[cid] = nil
        TriggerClientEvent('som-heists:client:objective', source, nil)
    end
end

local function close(groupId, status)
    local run = runs[groupId]
    if not run then return end

    MySQL.update.await("UPDATE som_heist_runs SET status = ? WHERE id = ? AND status = 'active'", { status, run.id })
    log(('heist %s at %s ended %s'):format(run.tier, run.site.id, status))
    clear(groupId)
    exports['som-jobboard']:finish(groupId)
end

local function alarm(run, source)
    if run.alarmed then return end
    run.alarmed = true

    exports['som-dispatch']:alert(source, 'heistInProgress', {
        coords = run.site.terminal,
        message = ('Alarm triggered: %s'):format(run.site.label),
    })
end

-- ---------------------------------------------------------------------------
-- Pay
-- ---------------------------------------------------------------------------

---Clean cash from the treasury, capped per rolling hour for the whole tier.
---Debit first, credit second, refund if the credit fails.
---@return number paid
local function payClean(source, run, wanted)
    if wanted < 1 or treasuryBusy then return 0 end
    treasuryBusy = true

    local cfg = Config.tiers[run.tier]
    local spent = tonumber(MySQL.scalar.await(
        'SELECT COALESCE(SUM(clean_paid), 0) FROM som_heist_runs WHERE tier = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)',
        { run.tier })) or 0

    local amount = math.min(wanted, math.max(0, cfg.hourlyCleanCap - spent))
    local paid = 0

    if amount >= 1 and core:treasuryTransact(-amount, ('heist:%s'):format(run.site.id)) then
        if core:addMoney(source, 'bank', amount, ('heist:%s'):format(run.site.id)) then
            paid = amount
            MySQL.update.await('UPDATE som_heist_runs SET clean_paid = clean_paid + ? WHERE id = ?', { paid, run.id })
        else
            core:treasuryTransact(amount, ('heist:%s:refund'):format(run.site.id))
        end
    end

    treasuryBusy = false
    return paid
end

-- ---------------------------------------------------------------------------
-- Starting a run
-- ---------------------------------------------------------------------------

local function policeOnDuty()
    return #core:getPlayersByJob('police', true)
end

---A free site for the tier: usable and not on cooldown. One conditional insert
---claims it, so two groups cannot take the same place.
---@return table|nil site, number|nil runId
local function claimSite(tier, info)
    local cfg = Config.tiers[tier]
    local candidates = {}
    for _, site in ipairs(Config.sites) do
        if site.tier == tier and usable(site) then candidates[#candidates + 1] = site end
    end

    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    for _, site in ipairs(candidates) do
        local id = MySQL.insert.await([[
            INSERT INTO som_heist_runs (site, tier, group_id)
            SELECT ?, ?, ? FROM DUAL
            WHERE NOT EXISTS (
                SELECT 1 FROM som_heist_runs
                WHERE site = ? AND (status = 'active' OR created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE))
            )
        ]], { site.id, tier, info.id, site.id, cfg.cooldownMinutes })

        if id and id > 0 then return site, id end
    end
end

local function start(tier, info)
    local cfg = Config.tiers[tier]
    if policeOnDuty() < cfg.policeMin or not info.leader then return false end

    local site, runId = claimSite(tier, info)
    if not site then return false end

    if not spendDongle(info.leader) then
        MySQL.update.await('DELETE FROM som_heist_runs WHERE id = ?', { runId })
        return false
    end

    local points = #site.lootPoints
    local run = {
        id = runId, group = info.id, tier = tier, site = site, stage = 'hack', members = {}, next = 1,
        attempts = 2, hacking = false, expires = os.time() + Config.minutes * 60,
        cleanEach = math.floor(math.random(cfg.clean.min, cfg.clean.max) / points), bills = {},
    }

    for i = 1, cfg.marked.count do
        local k = ((i - 1) % points) + 1
        run.bills[k] = run.bills[k] or {}
        run.bills[k][#run.bills[k] + 1] = cfg.marked.worth
    end

    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            byCitizen[m.citizenid] = info.id
        end
    end

    runs[info.id] = run
    log(('heist %s started at %s'):format(tier, site.id))
    sendObjective(run)
    return true
end

local function openDoors(run)
    for _, name in ipairs(run.site.doors or {}) do
        local door = exports.ox_doorlock:getDoorFromName(name)
        if door then exports.ox_doorlock:setDoorState(door.id, 0) end
    end
end

lib.callback.register('som-heists:server:interact', function(source, kind)
    local player = core:getPlayer(source)
    local run = player and runs[byCitizen[player.citizenid]]
    if not run then return done(false, 'you are not on a job') end
    if kind ~= 'hack' and kind ~= 'loot' then return done(false, 'bad request') end

    local goal = objective(run)
    if goal.kind ~= kind then return done(false, 'not yet') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - goal.coords) > Config.interactDistance then
        return done(false, 'you are too far away')
    end

    if kind == 'hack' then
        if run.hacking then return done(false, 'someone is already on it') end
        run.hacking = true

        local cfg = Config.tiers[run.tier]
        local won = exports['som-hack']:run(source, cfg.hack.kind, cfg.hack.level)
        run.hacking = false

        if runs[run.group] ~= run then return done(false, 'the job is over') end

        alarm(run, source)

        if won then
            openDoors(run)
            run.stage = 'loot'
            sendObjective(run)
            return done(true)
        end

        run.attempts = run.attempts - 1
        if run.attempts <= 0 then
            close(run.group, 'failed')
            return done(false, 'the system locked you out')
        end

        return done(false, 'that did not work')
    end

    local index = run.next
    run.next = index + 1

    local paid = payClean(source, run, run.cleanEach)
    local bills = run.bills[index]
    local minted = bills and exports['som-launder']:mintBills(source, bills, ('heist:%s'):format(run.site.id))

    TriggerClientEvent('som:client:notify', source,
        paid > 0 and ('You took $%d'):format(paid) or 'You took what you could carry', 'success')
    if bills and not minted then TriggerClientEvent('som:client:notify', source, 'You could not carry the rest', 'error') end

    if run.next > #run.site.lootPoints then
        close(run.group, 'done')
    else
        sendObjective(run)
    end

    return done(true)
end)

function Heists.Sweep()
    for groupId, run in pairs(runs) do
        if run.expires <= os.time() then close(groupId, 'failed') end
    end
end

AddEventHandler('som-groups:server:changed', function(groupId)
    local run = runs[groupId]
    if not run then return end

    local info = exports['som-groups']:getGroupById(groupId)
    if not info then return clear(groupId) end

    local still = {}
    for _, m in ipairs(info.members) do still[m.citizenid] = true end

    for cid, source in pairs(run.members) do
        if not still[cid] then
            run.members[cid] = nil
            byCitizen[cid] = nil
            TriggerClientEvent('som-heists:client:objective', source, nil)
        end
    end
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local groupId = byCitizen[citizenid]
    if not groupId then return end
    runs[groupId].members[citizenid] = nil
    byCitizen[citizenid] = nil
end)

for tier, cfg in pairs(Config.tiers) do
    exports['som-jobboard']:registerProvider({
        id = 'heist_' .. tier, label = cfg.label, summary = ('Needs a Trojan USB and %d on the police'):format(cfg.policeMin),
        minSize = cfg.minSize, maxSize = cfg.maxSize, slots = cfg.slots,
        canStart = function(info)
            if policeOnDuty() < cfg.policeMin then return false, 'the city is too quiet for this' end

            local any = false
            for _, site in ipairs(Config.sites) do
                if site.tier == tier and usable(site) then any = true end
            end
            if not any then return false, 'no sites are open yet' end

            if not info.leader or not usableDongle(info.leader) then return false, 'the leader needs a Trojan USB' end
            return true
        end,
        start = function(info) return start(tier, info) end,
    })
end

-- A restart ends every run, so none may keep a site claimed as active.
CreateThread(function()
    MySQL.update.await("UPDATE som_heist_runs SET status = 'failed' WHERE status = 'active'")
end)

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Heists.Sweep)
    end
end)
