--- Hiring and hourly pay. The owner offers a job to the person next to them, who accepts or
--- declines. Pay comes out of the shop account and is claimed per staff row from last_paid_at in
--- the database, so two ticks or a restart cannot pay the same hour twice. Made by Lennox.

local core = exports['som-core']
local done = Shops.Done

local offers = {}

local function nameOf(player) return ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname) end

lib.callback.register('som-shops:server:hire', function(source, id, target, pay)
    local owner, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end

    pay = Shops.Int(pay, 1, Config.maxHourlyPay)
    if not pay then return done(false, ('the pay must be $1 to $%d an hour'):format(Config.maxHourlyPay)) end

    local them = Shops.Int(target, 1, 65535)
    local hire = them and them ~= source and core:getPlayer(them)
    if not hire then return done(false, 'there is nobody to hire') end

    local pa, pb = GetPlayerPed(source), GetPlayerPed(them)
    if pa == 0 or pb == 0 or #(GetEntityCoords(pa) - GetEntityCoords(pb)) > Config.hireDistance then return done(false, 'they need to be next to you') end

    if (MySQL.scalar.await('SELECT COUNT(*) FROM som_shop_staff WHERE shop_id = ?', { shop.id }) or 0) >= Config.maxStaff then return done(false, 'you have all the staff you can have') end
    if MySQL.scalar.await('SELECT 1 FROM som_shop_staff WHERE citizenid = ?', { hire.citizenid }) then return done(false, 'they already work at a shop') end

    offers[hire.citizenid] = { shop = shop.id, pay = pay, owner = owner.citizenid, source = source, expires = os.time() + Config.hireExpireSeconds }
    TriggerClientEvent('som-shops:client:hireOffer', hire.source, shop.label, nameOf(owner), pay)
    return done(true)
end)

lib.callback.register('som-shops:server:answerHire', function(source, accept)
    local player = core:getPlayer(source)
    if not player or type(accept) ~= 'boolean' then return done(false, 'not available') end

    local offer = offers[player.citizenid]
    offers[player.citizenid] = nil
    if not offer or offer.expires < os.time() then return done(false, 'that offer is gone') end
    if not accept then return done(true) end

    local owner = core:getPlayer(offer.source)
    local shop = Shops.Find(offer.shop)
    if not shop or not owner or owner.citizenid ~= offer.owner or not Shops.Owns(owner, shop.id) then return done(false, 'that offer is gone') end

    -- Affected rows, not insertId: this table has no AUTO_INCREMENT, so insertId is 0 even when the row went in.
    local hired = MySQL.update.await([[
        INSERT IGNORE INTO som_shop_staff (citizenid, shop_id, hourly_pay)
        SELECT ?, ?, ? FROM DUAL WHERE (SELECT COUNT(*) FROM som_shop_staff WHERE shop_id = ?) < ?
    ]], { player.citizenid, shop.id, offer.pay, shop.id, Config.maxStaff })
    if not hired or hired < 1 then return done(false, 'the job is no longer open') end

    TriggerClientEvent('som:client:notify', owner.source, ('%s took the job'):format(nameOf(player)), 'success')
    return done(true)
end)

lib.callback.register('som-shops:server:setPay', function(source, id, citizenid, pay)
    local _, shop = Shops.Owned(source, id)
    pay = Shops.Int(pay, 1, Config.maxHourlyPay)
    if not shop or not pay or type(citizenid) ~= 'string' then return done(false, 'bad request') end

    local changed = MySQL.update.await('UPDATE som_shop_staff SET hourly_pay = ? WHERE shop_id = ? AND citizenid = ?', { pay, shop.id, citizenid })
    if (changed or 0) < 1 then return done(false, 'they do not work here') end
    return done(true)
end)

lib.callback.register('som-shops:server:fire', function(source, id, citizenid)
    local _, shop = Shops.Owned(source, id)
    if not shop or type(citizenid) ~= 'string' then return done(false, 'bad request') end

    local gone = MySQL.update.await('DELETE FROM som_shop_staff WHERE shop_id = ? AND citizenid = ?', { shop.id, citizenid })
    if (gone or 0) < 1 then return done(false, 'they do not work here') end
    return done(true)
end)

lib.callback.register('som-shops:server:quit', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local gone = MySQL.update.await('DELETE FROM som_shop_staff WHERE citizenid = ?', { player.citizenid })
    if (gone or 0) < 1 then return done(false, 'you do not work at a shop') end
    return done(true)
end)

-- ---------------------------------------------------------------------------
-- Payroll
-- ---------------------------------------------------------------------------

function Shops.PayTick()
    local due = MySQL.query.await([[
        SELECT s.citizenid, s.shop_id, s.hourly_pay, UNIX_TIMESTAMP(s.last_paid_at) AS paid_at
        FROM som_shop_staff s JOIN som_shops o ON o.shop_id = s.shop_id
        WHERE o.owner IS NOT NULL AND s.last_paid_at <= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { Config.payIntervalMinutes }) or {}

    for _, row in ipairs(due) do
        local worker = core:getPlayerByCitizenId(row.citizenid)
        if worker then
            local claimed = MySQL.update.await(
                'UPDATE som_shop_staff SET last_paid_at = NOW() WHERE citizenid = ? AND shop_id = ? AND UNIX_TIMESTAMP(last_paid_at) = ?',
                { row.citizenid, row.shop_id, row.paid_at })

            if (claimed or 0) >= 1 then
                local business, reason = 'shop_' .. row.shop_id, 'shop:payroll:' .. row.shop_id
                local pay = tonumber(row.hourly_pay)

                if not core:businessTransact(business, -pay, reason) then
                    -- The hour stays claimed: an empty account means no pay, not a retry every minute.
                    local boss = MySQL.scalar.await('SELECT owner FROM som_shops WHERE shop_id = ?', { row.shop_id })
                    local owner = boss and core:getPlayerByCitizenId(boss)
                    if owner then TriggerClientEvent('som:client:notify', owner.source, 'The shop account cannot cover wages', 'error') end
                elseif not core:addMoney(worker.source, 'bank', pay, reason, { counterparty = business, flow = 'transfer' }) then
                    core:businessTransact(business, pay, reason .. '_refund')
                    MySQL.update.await('UPDATE som_shop_staff SET last_paid_at = FROM_UNIXTIME(?) WHERE citizenid = ? AND shop_id = ?', { row.paid_at, row.citizenid, row.shop_id })
                else
                    TriggerClientEvent('som:client:notify', worker.source, ('You were paid $%d'):format(pay), 'success')
                end
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.payTickSeconds * 1000)
        local ok, err = pcall(Shops.PayTick)
        if not ok then print(('[som-shops] payroll failed: %s'):format(tostring(err))) end
    end
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then offers[citizenid] = nil end
end)
