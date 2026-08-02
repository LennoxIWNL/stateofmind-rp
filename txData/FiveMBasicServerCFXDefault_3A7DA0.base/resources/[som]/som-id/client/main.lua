-- ID card client.
--
-- Thin: it asks the server to show a document and renders whatever comes back.
-- It never builds a card itself, because a client that can author its own ID
-- can author anyone's.

local hideAt = 0

---Held out for the people nearby to read.
local function playShowAnim()
    local dict = Config.Anim.dict
    RequestAnimDict(dict)

    -- Bounded: a missing dict should cost nothing, not hang the interaction.
    local deadline = GetGameTimer() + 1000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    if not HasAnimDictLoaded(dict) then return end

    TaskPlayAnim(PlayerPedId(), dict, Config.Anim.clip,
        3.0, 3.0, Config.Anim.duration, Config.Anim.flag, 0, false, false, false)
end

---@param item string inventory item name
local function show(item)
    local ok = lib.callback.await('som-id:server:show', false, item)
    if not ok then
        TriggerEvent('som:client:notify', 'You cannot show that right now', 'error')
        return
    end

    playShowAnim()
end

RegisterNetEvent('som-id:client:card', function(card, duration, own)
    if type(card) ~= 'table' then return end

    hideAt = GetGameTimer() + (tonumber(duration) or 10000)
    SendNUIMessage({ action = 'show', card = card, own = own })
end)

-- No NUI focus at any point. The card is something you look at while the world
-- carries on, so taking the cursor would turn a glance into a menu.
CreateThread(function()
    while true do
        if hideAt > 0 and GetGameTimer() >= hideAt then
            hideAt = 0
            SendNUIMessage({ action = 'hide' })
        end

        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SendNUIMessage({ action = 'hide' }) end
end)

-- ox_inventory calls this from data/items.lua via client.export.
exports('useIdCard', function() show('id_card') end)
exports('useDriverLicense', function() show('driver_license') end)
exports('useWeaponLicense', function() show('weaponlicense') end)
