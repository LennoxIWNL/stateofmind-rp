--- The apps this resource ships. Each is a table of actions run through the
--- pipeline in core.lua, so none of them repeats the owned, downed, locked, app
--- allowed, size and rate checks. Apps in other resources use the same host.

local core = exports['som-core']

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

---What the phone shows when it opens, and what the shell needs on every refresh.
---@param source number
---@param player table
---@param device table
---@return table
function Phone.Open(source, player, device)
    local row = MySQL.single.await('SELECT theme, wallpaper FROM som_phone_settings WHERE citizenid = ?', { player.citizenid })

    local pendingBills = MySQL.scalar.await(
        'SELECT COUNT(*) FROM som_phone_bills WHERE to_citizenid = ? AND status = ?',
        { player.citizenid, 'pending' }) or 0

    return {
        success = true,
        apps = Phone.AppsFor(source),
        settings = row or { theme = 'default', wallpaper = 'default' },
        themes = Config.Themes,
        owner = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        number = player.charinfo.phone,
        hasPasscode = device.pass_hash ~= nil,
        badges = { bank = tonumber(pendingBills) or 0 },
    }
end

-- ---------------------------------------------------------------------------
-- Bank (accounts, bills, transfers)
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'bank', label = 'Bank', icon = 'bank', colour = '#2ecc71', order = 10,
    actions = {
        overview = { fn = function(source) return Bank.GetOverview(source) end },
        share = { writes = true, fn = function(source)
            local ok, result = Bank.ShareAccount(source)
            return done(ok, result, { shared = ok and result or 0 })
        end },
        bill = { writes = true, fn = function(source, payload)
            return done(Bank.CreateBill(source, payload.accountNo, payload.amount, payload.reason))
        end },
        pay = { writes = true, fn = function(source, payload) return done(Bank.PayBill(source, payload.id)) end },
        decline = { writes = true, fn = function(source, payload) return done(Bank.DeclineBill(source, payload.id)) end },
        transfer = { writes = true, fn = function(source, payload)
            return done(Bank.Transfer(source, payload.accountNo, payload.amount))
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Properties: a read-only view over som-housing
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'properties', label = 'Properties', icon = 'briefcase', colour = '#e0a13b', order = 20,
    actions = {
        overview = { fn = function(source, _, player)
            if GetResourceState('som-housing') ~= 'started' then return done(false, 'Properties is unavailable') end

            local near = lib.callback.await('som-housing:server:nearby', source) or {}

            return {
                success = true,
                properties = exports['som-housing']:listFor(player.citizenid) or {},
                finance = exports['som-housing']:financeListFor(player.citizenid) or {},
                nearby = near.nearby or {},
                accounts = near.accounts or {},
                owned = near.owned or 0,
                maxOwned = near.maxOwned or 0,
            }
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'settings', label = 'Settings', icon = 'settings', colour = '#8e8e93', order = 90,
    actions = {
        setTheme = { writes = true, fn = function(source, payload, player)
            local def = type(payload.theme) == 'string' and Config.Themes[payload.theme]
            if not def then return done(false, 'unknown theme') end

            -- A theme is a supporter perk, so the entitlement is checked here.
            if def.perk and not core:hasPerk(source, def.perk) then return done(false, 'That theme is not unlocked') end

            MySQL.insert.await([[
                INSERT INTO som_phone_settings (citizenid, theme) VALUES (?, ?)
                ON DUPLICATE KEY UPDATE theme = VALUES(theme)
            ]], { player.citizenid, payload.theme })

            return { success = true }
        end },
        setPasscode = { writes = true, fn = function(source, payload, player) return Phone.SetPasscode(source, payload, player) end },
    },
})
