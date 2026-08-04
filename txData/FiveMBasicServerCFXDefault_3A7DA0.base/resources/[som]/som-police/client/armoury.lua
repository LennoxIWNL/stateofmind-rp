-- The armoury UI.
--
-- Thin by design: it shows what the server sent and posts back an item name and
-- an account. It never computes a price, never decides eligibility, and never
-- hears about a certification the officer does not hold, because the server
-- filters the list before it is ever sent.

Armoury = {}

local isOpen = false

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

RegisterNUICallback('take', function(data, cb)
    if type(data) ~= 'table' or type(data.item) ~= 'string' then
        return cb({ success = false, error = 'invalid request' })
    end

    local res = lib.callback.await('som-police:server:takeItem', false, {
        item = data.item,
        account = data.account,
    })

    cb(res or { success = false, error = 'no response' })

    -- Refreshed after every purchase, because balances moved and what is
    -- affordable moved with them.
    if res and res.success then
        local refreshed = lib.callback.await('som-police:server:armoury', false)

        if refreshed and refreshed.success then
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)
