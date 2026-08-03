-- Bootstrap and the economy's periodic work.

-- ---------------------------------------------------------------------------
-- Sink and faucet instrumentation
--
-- This only MEASURES. It deliberately does not auto-correct: an economy that
-- silently retunes itself is impossible to reason about, and a bug in the
-- corrector would be indistinguishable from player behaviour.
--
-- Everything it reports comes from som_transactions, which is why that table
-- records a flow on every row.
-- ---------------------------------------------------------------------------

local function reportBalance()
    local window = Config.Balance.reportIntervalMinutes

    local row = MySQL.single.await([[
        SELECT
            COALESCE(SUM(CASE WHEN flow = 'faucet' THEN amount ELSE 0 END), 0) AS faucet,
            COALESCE(SUM(CASE WHEN flow = 'sink'   THEN amount ELSE 0 END), 0) AS sink
        FROM som_transactions
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { window })

    if not row or row.faucet == 0 then return end

    local ratio = row.sink / row.faucet
    local target = Config.Balance.targetSinkFaucetRatio
    local drift = math.abs(ratio - target)

    print(('[som-economy] last %dm: faucet %d, sink %d, ratio %.2f (target %.2f)')
        :format(window, row.faucet, row.sink, ratio, target))

    if drift > Config.Balance.warnDeviation then
        print(('[som-economy] ^3ratio is %.2f off target. %s^7')
            :format(drift, ratio < target
                and 'Money is entering faster than it leaves; sinks need raising.'
                or  'Money is leaving faster than it enters; players will feel squeezed.'))
    end
end

-- ---------------------------------------------------------------------------
-- Loops
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Wait for som-core to have its database connection up.
    Wait(2000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_market LIMIT 1')
    end)

    if not ok then
        print('[som-economy] som_market is missing. Import setup.sql before starting.')
        return
    end

    Market.Load()
    Business.Load()

    while true do
        Wait(Config.Market.tickMinutes * 60000)
        Market.Recover()
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Balance.reportIntervalMinutes * 60000)
        reportBalance()
    end
end)

-- ---------------------------------------------------------------------------
-- Staff visibility
--
-- One command, kept because there is no admin menu yet and no physical anchor
-- for "show me the state of the economy". It moves into som-admin at Phase 4d.
-- ---------------------------------------------------------------------------

-- Not `restricted`: that hands the check to FiveM's ACE, which does not resolve
-- on this server, so the command was refused before its handler ran and printed
-- nothing at all. som-core's hasPermission has an owner-by-identifier fallback
-- that works, so the check happens here instead. See som-core/server/
-- permissions.lua, Permissions.AddCommand.
lib.addCommand('economy', {
    help = 'Show market and treasury state',
}, function(source)
    if source ~= 0 and not exports['som-core']:hasPermission(source, 'som.admin') then
        return TriggerClientEvent('som:client:notify', source,
            'You do not have permission to do that', 'error')
    end

    print('---- SOM economy ----')
    print(('treasury: %d'):format(exports['som-core']:getTreasury()))

    for _, b in ipairs(Business.GetAll()) do
        -- oxmysql returns TINYINT(1) as a boolean, not 1, so comparing against
        -- the number marked every business inactive including LSPD.
        local active = b.active == true or b.active == 1
        print(('  %-14s %-10s %12d  %s'):format(
            b.name, b.funding, Business.GetBalance(b.name),
            active and '' or '(inactive)'))
    end

    for _, m in ipairs(Market.GetAll()) do
        print(('  %-16s %6d / %-6d  %3d%%'):format(
            m.item, m.price, m.base, math.floor(m.health * 100)))
    end

    reportBalance()
end)
