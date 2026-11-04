--- Hourly gang pay. Only gangs that hold turf are paid, only online members,
--- and the money comes out of the gang account first: debit, then credit the
--- member, then refund the account if the credit fails. If the account runs
--- dry the rest of that gang goes unpaid this hour.

local core = exports['som-core']
local Gangs = core:getGangs()

function Turf.Payroll()
    local held = {}
    for _, r in ipairs(MySQL.query.await(
        'SELECT owner_gang, COUNT(*) AS zones FROM som_turf WHERE owner_gang IS NOT NULL GROUP BY owner_gang') or {}) do
        held[r.owner_gang] = r.zones
    end

    local paid = 0
    for gang in pairs(held) do
        local def = Gangs[gang]
        for _, player in ipairs(def and core:getPlayersByGang(gang) or {}) do
            local pay = math.min(player.gang.payment or 0, Config.payrollCap)
            if pay > 0 then
                if not core:gangTransact(gang, -pay, 'gang:payroll') then break end
                local ok = core:addMoney(player.source, 'bank', pay, 'gang_pay:' .. gang, { counterparty = gang, flow = 'transfer' })
                if ok then
                    paid = paid + pay
                else
                    core:gangTransact(gang, pay, 'gang:payroll_refund')
                end
            end
        end
    end
    return paid
end

CreateThread(function()
    while true do
        Wait(Config.payrollMinutes * 60000)
        Turf.Payroll()
    end
end)
