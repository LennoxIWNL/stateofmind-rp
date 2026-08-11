-- The armoury UI.
--
-- Thin by design: it shows what the server sent and posts back item names and
-- an account. It never computes a price, never decides eligibility, and never
-- hears about a certification the officer does not hold, because the server
-- filters the list before it is ever sent.
--
-- THE CART LIVES HERE, not in the page. A React component's state dies with the
-- page, and the page is destroyed every time the panel closes, so a cart kept
-- there would be lost by walking away from the counter. Keeping it in Lua means
-- it also survives the panel being closed by something other than the close
-- button: dying, a resource restart, or the officer being cuffed mid-shop.
--
-- It is still not an authority. som-police:server:takeItem re-resolves the item,
-- its price and its count from config on every single line, so the cart decides
-- what is ASKED for and the server decides what is given.

Armoury = {}

local isOpen = false

-- cart[n] = { item = string, count = number }
local cart = {}

-- Bounds on what the cart may hold.
--
-- Not a game rule, a loop bound. Checkout makes one server call per unit,
-- because that is the shape of the existing takeItem contract, so an unbounded
-- cart would be a way to make the client issue thousands of callbacks in a row.
local MAX_LINES = 20
local MAX_PER_LINE = 20
local MAX_UNITS = 25

---@param value any
---@return table cart sanitised copy
local function sanitiseCart(value)
    local out, units = {}, 0

    if type(value) ~= 'table' then return out end

    for _, line in ipairs(value) do
        if #out >= MAX_LINES then break end

        if type(line) == 'table' and type(line.item) == 'string' and line.item ~= '' then
            local count = math.floor(tonumber(line.count) or 0)

            if count > 0 then
                if count > MAX_PER_LINE then count = MAX_PER_LINE end
                if units + count > MAX_UNITS then count = MAX_UNITS - units end

                if count > 0 then
                    out[#out + 1] = { item = line.item, count = count }
                    units = units + count
                end
            end
        end
    end

    return out
end

---@param data table the server's armoury response
function Armoury.Open(data)
    if isOpen then return end

    isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        data = {
            label = data.label,
            issue = data.issue,
            personal = data.personal,
            payment = data.payment,
            -- Handed back so the basket is where it was left.
            cart = cart,
        },
    })
end

---Shows the certification card. Read-only: granting lives in the MDT, where
---the rank check is, and a control here that always refused would be worse than
---no control.
---@param data table { certifications, name, badge }
function Armoury.ShowCerts(data)
    isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({ action = 'certs', data = data })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('cartSet', function(data, cb)
    cart = sanitiseCart(type(data) == 'table' and data.cart or nil)
    cb({ success = true })
end)

---Pulls the whole basket.
---
---One server call per unit, deliberately, because takeItem is the contract that
---already does every check worth doing: it re-resolves the item from config,
---confirms the officer is at the armoury, applies the certification gate,
---charges the correct account and refunds if the inventory has no room. Batching
---would mean writing a second path through all of that, and a second path is
---where the two disagree.
---
---A line that fails does not stop the rest. An officer whose bag filled up on
---item three should still get items four and five, and be told which ones did
---not fit.
RegisterNUICallback('checkout', function(data, cb)
    if not isOpen then return cb({ success = false, error = 'not open' }) end
    if #cart == 0 then return cb({ success = false, error = 'basket is empty' }) end

    local account = type(data) == 'table' and data.account or nil
    if account ~= nil and type(account) ~= 'string' then account = nil end

    local drawn, failed, spent = 0, 0, 0
    local remaining, lastError = {}, nil

    for _, line in ipairs(cart) do
        local filled = 0

        for _ = 1, line.count do
            -- pcall, because an ox_lib callback rejects as well as resolves: an
            -- invalid response or the callback timeout makes await raise. If
            -- that unwound out of here, cb() below would never be called, the
            -- page would sit in its busy state forever, and the officer's only
            -- way out would be a reconnect. som-medical had exactly this bug.
            local ok, res = pcall(lib.callback.await, 'som-police:server:takeItem', false, {
                item = line.item,
                account = account,
            })

            if not ok then
                lastError = 'the armoury did not answer'
                break
            end

            if not res or not res.success then
                lastError = res and res.error or lastError

                -- One refusal on a line means the rest of that line refuses for
                -- the same reason, whether that is money, room or a
                -- certification. Carrying on would repeat the same round trip
                -- to be told the same thing.
                break
            end

            filled = filled + 1
            drawn = drawn + 1
            spent = spent + (res.price or 0)
        end

        -- Everything not drawn stays in the basket, so a partly filled checkout
        -- leaves exactly what still needs sorting out.
        local unfilled = line.count - filled

        if unfilled > 0 then
            failed = failed + unfilled
            remaining[#remaining + 1] = { item = line.item, count = unfilled }
        end
    end

    cart = sanitiseCart(remaining)

    if GetResourceState('som-ui') == 'started' then
        -- A free issue draw and a paid one do not sound the same. Taking a
        -- bandage off the department shelf and spending $95,000 sounding
        -- identical is the flatness this vocabulary exists to fix.
        local sound = 'error'
        if drawn > 0 then sound = spent > 0 and 'purchase' or 'success' end

        exports['som-ui']:playSound(sound)
    end

    cb({
        success = drawn > 0,
        error = drawn == 0 and (lastError or 'nothing could be drawn') or nil,
        drawn = drawn,
        failed = failed,
        spent = spent,
        remaining = cart,
    })

    -- Balances moved and what is affordable moved with them.
    --
    -- After cb(), so a refresh that fails cannot leave the basket waiting on an
    -- answer it already earned.
    if drawn > 0 then
        local ok, refreshed = pcall(lib.callback.await, 'som-police:server:armoury', false)

        if ok and refreshed and refreshed.success then
            SendNUIMessage({
                action = 'refresh',
                data = {
                    issue = refreshed.issue,
                    personal = refreshed.personal,
                    payment = refreshed.payment,
                },
            })
        end
    end
end)

-- A new character does not inherit the last one's basket.
AddEventHandler('som:client:onPlayerLoaded', function()
    cart = {}
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
