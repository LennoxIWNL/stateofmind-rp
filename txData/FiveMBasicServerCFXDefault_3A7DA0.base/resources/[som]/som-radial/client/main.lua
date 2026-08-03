-- Radial client.
--
-- The list of entries is decided by the server and cached here, so opening is
-- instant rather than waiting on a callback while the key is already held.
-- Refreshed whenever the thing that decides entitlement changes.

local isOpen = false
local entries = { sections = {}, items = {} }
local handsUp = false

local HANDS_UP = { dict = 'missminuteman_1ig_2', clip = 'handsup_base' }

---@return boolean
local function refresh()
    local data = lib.callback.await('som-radial:server:entries', false)
    if not data then return false end

    entries = data
    return true
end

-- ---------------------------------------------------------------------------
-- Contextual filtering
--
-- The server decides what a player is ENTITLED to see. This decides what makes
-- sense right now, which is a different question and belongs on the client
-- because it changes several times a second.
-- ---------------------------------------------------------------------------

---@return table[] sections, table[] items
local function contextual()
    local vehicle = cache.vehicle or nil
    local seated = vehicle ~= nil

    -- Standing next to one counts for doors and the boot, not for the engine.
    if not vehicle then
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        local nearby = GetClosestVehicle(coords.x, coords.y, coords.z, 4.0, 0, 71)
        if nearby and nearby ~= 0 and DoesEntityExist(nearby) then vehicle = nearby end
    end

    local sections, items = {}, {}

    for _, section in ipairs(entries.sections or {}) do
        if section.when ~= 'vehicle' or vehicle then
            sections[#sections + 1] = section
        end
    end

    for _, item in ipairs(entries.items or {}) do
        local ok = true

        if item.section == 'vehicle' then
            if not vehicle then ok = false end
            if item.seatedOnly and not seated then ok = false end
        end

        if ok then items[#items + 1] = item end
    end

    return sections, items, vehicle
end

---Builds the entries for a submenu that depends on the vehicle you are at.
---@param kind string
---@param vehicle number
---@return table[]
local function dynamicMenu(kind, vehicle)
    local list = {}

    if kind == 'doors' then
        for index, label in pairs(Config.Doors) do
            -- Only offer doors the vehicle actually has.
            if GetIsDoorValid(vehicle, index) or index == 4 or index == 5 then
                list[#list + 1] = {
                    id = ('door.%d'):format(index),
                    label = label,
                    icon = 'door',
                    order = index,
                    door = index,
                    open = GetVehicleDoorAngleRatio(vehicle, index) > 0.1,
                }
            end
        end

    elseif kind == 'seats' then
        local max = GetVehicleMaxNumberOfPassengers(vehicle)

        for seat = -1, max - 1 do
            if IsVehicleSeatFree(vehicle, seat) then
                list[#list + 1] = {
                    id = ('seat.%d'):format(seat),
                    label = seat == -1 and 'Driver' or ('Seat %d'):format(seat + 1),
                    icon = 'seat',
                    order = seat + 2,
                    seat = seat,
                }
            end
        end
    end

    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

-- ---------------------------------------------------------------------------
-- Open and close
-- ---------------------------------------------------------------------------

local currentVehicle

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open()
    if isOpen then return end
    if not exports['som-core']:isPlayerLoaded() then return end
    if IsPauseMenuActive() or IsNuiFocused() then return end

    -- Dead or cuffed players do not get a menu of things to do.
    if IsPedFatallyInjured(cache.ped) then return end
    if exports['som-core']:getMetadata('cuffed') then return end

    if not entries.items or #entries.items == 0 then
        if not refresh() then return end
    end

    local sections, items, vehicle = contextual()
    currentVehicle = vehicle

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            sections = sections,
            items = items,
            colours = Config.Colours,
            deadZone = Config.DeadZone,
        },
    })
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------

---@param spec string 'resource.method'
local function dispatch(spec)
    local resource, method = spec:match('^([^.]+)%.(.+)$')
    if not resource or not method then return end

    if GetResourceState(resource) ~= 'started' then
        TriggerEvent('som:client:notify', 'That is not available right now', 'error')
        return
    end

    local ok, err = pcall(function() return exports[resource][method]() end)
    if not ok then
        print(('[som-radial] %s failed: %s'):format(spec, err))
    end
end

RegisterNUICallback('select', function(data, cb)
    cb({})
    close()

    if type(data) ~= 'table' or not data.id then return end

    -- Dynamic entries act on the vehicle the menu was opened against, so a
    -- player cannot open the menu at one car and apply it to another.
    if data.door and currentVehicle and DoesEntityExist(currentVehicle) then
        local index = tonumber(data.door)
        if GetVehicleDoorAngleRatio(currentVehicle, index) > 0.1 then
            SetVehicleDoorShut(currentVehicle, index, false)
        else
            SetVehicleDoorOpen(currentVehicle, index, false, false)
        end
        return
    end

    if data.seat and currentVehicle and DoesEntityExist(currentVehicle) then
        TaskWarpPedIntoVehicle(cache.ped, currentVehicle, tonumber(data.seat))
        return
    end

    if data.export then dispatch(data.export) end
end)

RegisterNUICallback('submenu', function(data, cb)
    local kind = type(data) == 'table' and data.menu
    local menu = kind and Config.Menus[kind]

    if not menu or not currentVehicle or not DoesEntityExist(currentVehicle) then
        cb({ items = {} })
        return
    end

    cb({ label = menu.label, items = dynamicMenu(menu.dynamic, currentVehicle) })
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

-- ---------------------------------------------------------------------------
-- Built in actions
-- ---------------------------------------------------------------------------

exports('handsUp', function()
    handsUp = not handsUp

    if not handsUp then
        ClearPedTasks(cache.ped)
        TriggerServerEvent('som-radial:server:handsUp', false)
        return
    end

    RequestAnimDict(HANDS_UP.dict)
    local deadline = GetGameTimer() + 1000
    while not HasAnimDictLoaded(HANDS_UP.dict) and GetGameTimer() < deadline do Wait(0) end
    if not HasAnimDictLoaded(HANDS_UP.dict) then handsUp = false return end

    TaskPlayAnim(cache.ped, HANDS_UP.dict, HANDS_UP.clip, 3.0, 3.0, -1, 49, 0, false, false, false)

    -- som-theft gates cash robbery on this, so it is framework state rather
    -- than something this resource keeps to itself.
    TriggerServerEvent('som-radial:server:handsUp', true)
end)

exports('toggleEngine', function()
    local vehicle = cache.vehicle
    if not vehicle then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then
        TriggerEvent('som:client:notify', 'You are not driving', 'error')
        return
    end

    local running = GetIsVehicleEngineRunning(vehicle)
    SetVehicleEngineOn(vehicle, not running, false, true)
end)

exports('toggleHazards', function()
    local vehicle = cache.vehicle
    if not vehicle then return end

    local on = not (GetVehicleIndicatorLights(vehicle) == 3)
    SetVehicleIndicatorLights(vehicle, 0, on)
    SetVehicleIndicatorLights(vehicle, 1, on)
end)

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

if Config.HoldToOpen then
    RegisterCommand('+somradial', open, false)
    RegisterCommand('-somradial', function()
        if not isOpen then return end
        -- Release picks whatever the cursor is over. The NUI answers with a
        -- select callback, or with nothing if inside the dead zone.
        SendNUIMessage({ action = 'confirm' })
    end, false)

    RegisterKeyMapping('+somradial', 'Open radial menu', 'keyboard', Config.OpenKey)
else
    RegisterCommand('somradial', function()
        if isOpen then close() else open() end
    end, false)

    RegisterKeyMapping('somradial', 'Open radial menu', 'keyboard', Config.OpenKey)
end

-- Entitlement changes, so the cached list has to change with them.
RegisterNetEvent('som:client:playerLoaded', refresh)
RegisterNetEvent('som:client:onJobChanged', refresh)
RegisterNetEvent('som:client:onGangChanged', refresh)
RegisterNetEvent('som-radial:client:refresh', refresh)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
