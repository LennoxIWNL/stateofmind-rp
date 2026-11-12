-- Bootstrap, lifecycle, periodic loops, and the public export surface.

local saveInterval = Config.Save.intervalMinutes * 60000
local paycheckInterval = Config.Money.paycheckInterval * 60000

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local source = source
    local player = Players.Get(source)
    if not player then return end

    player:save()
    TriggerEvent('som:server:playerUnloaded', source, player.citizenid)
    Players.Remove(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, player in ipairs(Players.GetAll()) do
        player:save()
    end
end)

-- ---------------------------------------------------------------------------
-- Periodic save
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(saveInterval)

        local players = Players.GetAll()
        for i = 1, #players do
            players[i]:save()
        end

        if Config.Debug and #players > 0 then
            print(('[som-core] saved %s characters'):format(#players))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Hunger and thirst decay
--
-- setMetadata clamps to Config.MetadataBounds, so the floor is handled there
-- and this only has to subtract. Skipped entirely if either rate is zero, so
-- turning decay off is a config edit rather than a code one.
-- ---------------------------------------------------------------------------

CreateThread(function()
    local needs = Config.Needs
    if not needs then return end

    local interval = (needs.intervalMinutes or 0) * 60000
    if interval <= 0 then return end

    while true do
        Wait(interval)

        for _, player in ipairs(Players.GetAll()) do
            if needs.hungerPerInterval and needs.hungerPerInterval > 0 then
                player:setMetadata('hunger', (player.metadata.hunger or 100) - needs.hungerPerInterval)
            end

            if needs.thirstPerInterval and needs.thirstPerInterval > 0 then
                player:setMetadata('thirst', (player.metadata.thirst or 100) - needs.thirstPerInterval)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Payroll
--
-- Pay is drawn from the job's business account, never minted. If the business
-- cannot cover it, nobody is paid and the shortfall is logged. That is the
-- mechanism that makes the Phase 4 faucet side of the economy bounded.
-- ---------------------------------------------------------------------------

function PayCheck(player)
    local job = player.job
    local jobDef = Jobs[job.name]
    local payment = job.payment or 0

    -- Hard ceiling, applied here rather than trusted from config, so a
    -- mistake in a job definition cannot flood the economy.
    local ceiling = Config.Money.maxHourlyPaycheck
    if ceiling and payment > ceiling then payment = ceiling end

    if payment <= 0 or not jobDef then return end

    local eligible = job.onduty
        or jobDef.offDutyPay
        or Config.Money.payOffDutyByDefault
    if not eligible then return end

    local reason = ('paycheck:%s'):format(job.name)

    if not jobDef.business then
        -- Jobs with no business register entry are a faucet.
        -- Only 'unemployed' should reach this branch.
        Money.Add(player.source, 'bank', payment, reason)
        return
    end

    if not Money.BusinessTransact(jobDef.business, -payment, ('payroll:%s'):format(job.name)) then
        if Config.Debug then
            print(('[som-core] %s could not cover payroll for %s'):format(jobDef.business, player.citizenid))
        end
        return
    end

    local paid = Money.Add(player.source, 'bank', payment, reason, {
        counterparty = jobDef.business,
        flow = 'transfer',
    })
    if not paid then
        Money.BusinessTransact(jobDef.business, payment, ('payroll:%s:refund'):format(job.name))
    end
end

CreateThread(function()
    while true do
        Wait(paycheckInterval)

        for _, player in ipairs(Players.GetAll()) do
            -- One failed database call must not end paychecks for everyone.
            local ok, err = pcall(PayCheck, player)
            if not ok then print(('[som-core] paycheck failed for %s: %s'):format(player.citizenid, tostring(err))) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Status from item use
--
-- ox_inventory fires 'ox_inventory:usedItem' on the server (server.lua, a plain
-- TriggerEvent, not a net event) only after the item was really consumed and the
-- client's report matched the slot the server recorded. The effect comes from
-- Config.ItemStatus, so the client sends nothing and a cancelled use changes nothing.
-- ox deletes an item's `client` table on the server, which is why this is not read
-- from data/items.lua; a test keeps the two in step.
-- ---------------------------------------------------------------------------

AddEventHandler('ox_inventory:usedItem', function(source, name)
    local player = Players.Get(source)
    local effect = type(name) == 'string' and Config.ItemStatus[name]
    if not player or not effect then return end

    for key, points in pairs(effect) do
        player:setMetadata(key, (player.metadata[key] or 0) + points)
    end
end)

-- ---------------------------------------------------------------------------
-- Exports
--
-- Consumed as: exports['som-core']:getPlayer(source)
-- Money exports live in money.lua, permission exports in permissions.lua.
-- ---------------------------------------------------------------------------

exports('getPlayer', function(source) return Players.Get(source) end)
exports('getPlayerByCitizenId', function(citizenid) return Players.GetByCitizenId(citizenid) end)
exports('getPlayerByLicense', function(license) return Players.GetByLicense(license) end)
exports('getPlayers', function() return Players.GetAll() end)
exports('getPlayersByJob', function(job, onDuty) return Players.GetByJob(job, onDuty) end)
exports('getPlayersByGang', function(gang) return Players.GetByGang(gang) end)

exports('setJob', function(source, job, grade)
    local player = Players.Get(source)
    if not player then return false, 'player not found' end
    return player:setJob(job, grade)
end)

exports('setGang', function(source, gang, grade)
    local player = Players.Get(source)
    if not player then return false, 'player not found' end
    return player:setGang(gang, grade)
end)

exports('setDuty', function(source, onduty)
    local player = Players.Get(source)
    if not player then return false, 'player not found' end
    return player:setDuty(onduty)
end)

exports('setMetadata', function(source, key, value)
    local player = Players.Get(source)
    if not player then return false, 'player not found' end
    return player:setMetadata(key, value)
end)

exports('getMetadata', function(source, key)
    local player = Players.Get(source)
    if not player then return nil end
    return player:getMetadata(key)
end)

exports('getJobs', function() return Jobs end)
exports('getGangs', function() return Gangs end)

-- ---------------------------------------------------------------------------
-- Staff commands
--
-- These are the only commands som-core registers. Everything else in the
-- framework is an interaction, per Phase 8. Each money path lands in the
-- ledger like any other.
--
-- Registered through Permissions.AddCommand rather than with lib.addCommand's
-- `restricted`, because that hands the check to FiveM's ACE and ACE does not
-- resolve here. See the note on Permissions.AddCommand: with `restricted` set,
-- these commands were refused before their handler ran and printed nothing.
-- ---------------------------------------------------------------------------

Permissions.AddCommand('setjob', {
    help = 'Set a player job',
    params = {
        { name = 'id', type = 'playerId', help = 'Target player' },
        { name = 'job', type = 'string', help = 'Job name' },
        { name = 'grade', type = 'number', help = 'Job grade', optional = true },
    },
}, Config.Permissions.admin, function(source, args)
    local player = Players.Get(args.id)
    if not player then return end

    local ok, err = player:setJob(args.job, args.grade or 0)

    if not ok then
        return TriggerClientEvent('som:client:notify', source, err, 'error')
    end

    -- Success was silent, which is indistinguishable from the command not
    -- running at all. Both the admin and the target are told.
    TriggerClientEvent('som:client:notify', source,
        ('%s is now %s (%s)'):format(GetPlayerName(args.id) or args.id,
            player.job.label, player.job.gradeLabel), 'success')

    if args.id ~= source then
        TriggerClientEvent('som:client:notify', args.id,
            ('You are now %s (%s)'):format(player.job.label, player.job.gradeLabel),
            'success')
    end
end)

Permissions.AddCommand('setgang', {
    help = 'Set a player gang',
    params = {
        { name = 'id', type = 'playerId', help = 'Target player' },
        { name = 'gang', type = 'string', help = 'Gang name' },
        { name = 'grade', type = 'number', help = 'Gang grade', optional = true },
    },
}, Config.Permissions.admin, function(source, args)
    local player = Players.Get(args.id)
    if not player then return end

    local ok, err = player:setGang(args.gang, args.grade or 0)
    if not ok then
        TriggerClientEvent('som:client:notify', source, err, 'error')
    end
end)

Permissions.AddCommand('givemoney', {
    help = 'Give money to a player',
    params = {
        { name = 'id', type = 'playerId', help = 'Target player' },
        { name = 'account', type = 'string', help = 'cash, bank or crypto' },
        { name = 'amount', type = 'number', help = 'Amount' },
    },
}, Config.Permissions.god, function(source, args)
    local ok, err = Money.Add(args.id, args.account, args.amount, ('admin:%s'):format(GetPlayerName(source)))
    TriggerClientEvent('som:client:notify', source, ok and 'Money added' or err, ok and 'success' or 'error')
end)

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Fail loudly at boot rather than on the first character load.
    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_characters LIMIT 1')
    end)

    if not ok then
        print('[som-core] som_* tables are missing. Import setup.sql before starting.')
        return
    end

    local jobCount, gangCount = 0, 0
    for _ in pairs(Jobs) do jobCount = jobCount + 1 end
    for _ in pairs(Gangs) do gangCount = gangCount + 1 end

    print(('[som-core] ready. %d jobs, %d gangs.'):format(jobCount, gangCount))
    print('[som] State of Mind RP framework, made by Lennox')
end)
