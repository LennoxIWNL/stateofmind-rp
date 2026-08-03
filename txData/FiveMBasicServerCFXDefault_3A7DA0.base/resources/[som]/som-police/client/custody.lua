-- Custody, client side.
--
-- Two jobs: put the verbs on the eye, and make being cuffed mean something
-- locally. Neither decides anything. Every verb is a request, and the cuffed
-- state below is applied because the SERVER said so, never because this file
-- decided it.

Custody = {}

local cuffed = false
local escortedBy = nil
local cuffProp = nil

---@return boolean
function Custody.IsCuffed()
    return cuffed
end

---Notifies from a { success, error } response.
local function handle(res, failure)
    if not res or not res.success then
        TriggerEvent('som:client:notify',
            (res and res.error) or failure or 'That did not work', 'error')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Requests
--
-- Shared with the keybinds, which is the point: a keybind is a faster way to
-- send the SAME message, never a second code path with different checks.
-- ---------------------------------------------------------------------------

Custody.Request = {}

---@param targetId number server id
function Custody.Request.cuff(targetId)
    if not targetId then return end

    local ok = lib.progressBar({
        duration = Config.Custody.cuffDuration,
        label = 'Restraining',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_left' },
    })

    if not ok then return end

    handle(lib.callback.await('som-police:server:cuff', false, targetId))
end

function Custody.Request.uncuff(targetId)
    if not targetId then return end

    local ok = lib.progressBar({
        duration = Config.Custody.uncuffDuration,
        label = 'Releasing',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_left' },
    })

    if not ok then return end

    handle(lib.callback.await('som-police:server:uncuff', false, targetId))
end

function Custody.Request.escort(targetId)
    if not targetId then return end
    handle(lib.callback.await('som-police:server:escort', false, targetId))
end

function Custody.Request.stopEscort()
    handle(lib.callback.await('som-police:server:stopEscort', false))
end

---Puts a restrained person into the nearest vehicle.
function Custody.Request.putInVehicle(targetId)
    if not targetId then return end

    local target = GetPlayerFromServerId(targetId)
    local ped = target ~= -1 and GetPlayerPed(target) or nil
    local coords = ped and GetEntityCoords(ped) or GetEntityCoords(cache.ped)

    local vehicle = lib.getClosestVehicle(coords, 5.0, false)
    if not vehicle or vehicle == 0 then
        return TriggerEvent('som:client:notify', 'No vehicle nearby', 'error')
    end

    -- First free rear seat. Seat -1 is the driver, which a restrained person
    -- must never end up in, so the search starts at 0 (front passenger) only
    -- when the rears are full.
    local seat
    for candidate = 1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, candidate) then seat = candidate break end
    end
    if not seat and IsVehicleSeatFree(vehicle, 0) then seat = 0 end

    if not seat then
        return TriggerEvent('som:client:notify', 'No free seat', 'error')
    end

    handle(lib.callback.await('som-police:server:putInVehicle', false, {
        target = targetId,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        seat = seat,
    }))
end

function Custody.Request.pullFromVehicle(targetId)
    if not targetId then return end
    handle(lib.callback.await('som-police:server:pullFromVehicle', false, targetId))
end

function Custody.Request.search(targetId)
    if not targetId then return end

    local ok = lib.progressBar({
        duration = Config.Custody.searchDuration,
        label = 'Searching',
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'missminuteman_1ig_2', clip = 'handsup_base' },
    })

    if not ok then return end

    handle(lib.callback.await('som-police:server:search', false, targetId))
end

function Custody.Request.seizeCash(targetId)
    if not targetId then return end

    local res = lib.callback.await('som-police:server:seizeCash', false, targetId)
    if not handle(res) then return end

    TriggerEvent('som:client:notify',
        ('Seized $%s into department funds'):format(res.amount), 'success')
end

function Custody.Request.checkId(targetId)
    if not targetId then return end

    local res = lib.callback.await('som-police:server:checkId', false, targetId)
    if not handle(res) then return end

    lib.registerContext({
        id = 'som_police_id',
        title = res.name,
        options = {
            { title = 'Date of birth', description = tostring(res.dob), icon = 'cake-candles' },
            { title = 'Citizen ID', description = res.citizenid, icon = 'id-card' },
            { title = 'Fingerprint', description = res.fingerprint or 'Not on file', icon = 'fingerprint' },
        },
    })

    lib.showContext('som_police_id')
end

function Custody.Request.fine(targetId)
    if not targetId then return end

    local res = lib.callback.await('som-police:server:finePresets', false)
    if not handle(res) then return end

    local options = {}

    for index, preset in ipairs(res.presets) do
        options[#options + 1] = {
            title = preset.label,
            description = ('$%s'):format(preset.amount),
            icon = 'receipt',
            onSelect = function()
                local out = lib.callback.await('som-police:server:issueFine', false, {
                    target = targetId, preset = index,
                })

                if not handle(out) then return end
                TriggerEvent('som:client:notify', ('Fined $%s'):format(out.amount), 'success')
            end,
        }
    end

    options[#options + 1] = {
        title = 'Other',
        description = 'Type an amount and a reason',
        icon = 'pen',
        onSelect = function()
            local input = lib.inputDialog('Issue a fine', {
                { type = 'number', label = 'Amount', required = true, min = 1 },
                { type = 'input', label = 'Reason', required = true, max = 128 },
            })

            if not input then return end

            local out = lib.callback.await('som-police:server:issueFine', false, {
                target = targetId, amount = input[1], reason = input[2],
            })

            if not handle(out) then return end
            TriggerEvent('som:client:notify', ('Fined $%s'):format(out.amount), 'success')
        end,
    }

    lib.registerContext({ id = 'som_police_fine', title = 'Issue a fine', options = options })
    lib.showContext('som_police_fine')
end

-- ---------------------------------------------------------------------------
-- Being cuffed
-- ---------------------------------------------------------------------------

local function playCuffAnim()
    lib.requestAnimDict(Config.Custody.anim.dict)

    TaskPlayAnim(cache.ped, Config.Custody.anim.dict, Config.Custody.anim.clip,
        8.0, -8.0, -1, 49, 0, false, false, false)

    if not cuffProp then
        local model = joaat(Config.Custody.anim.prop)
        lib.requestModel(model)

        cuffProp = CreateObject(model, GetEntityCoords(cache.ped), true, true, false)
        AttachEntityToEntity(cuffProp, cache.ped,
            GetPedBoneIndex(cache.ped, 60309), 0.02, 0.05, -0.02, 350.0, 170.0, 0.0,
            true, true, false, true, 1, true)
    end
end

local function clearCuffAnim()
    ClearPedTasks(cache.ped)

    if cuffProp then
        DeleteEntity(cuffProp)
        cuffProp = nil
    end
end

RegisterNetEvent('som-police:client:setCuffed', function(state)
    cuffed = state == true

    if cuffed then
        playCuffAnim()
    else
        clearCuffAnim()
    end

    -- The eye is left alone deliberately. A cuffed player should still be able
    -- to be searched and moved BY others, and disabling their own eye is what
    -- the control loop below does instead, selectively.
end)

-- A restrained person can still run. That is the design: restraint is a
-- roleplay state, not a paralysis, and a suspect who can move can still be
-- chased or walked into a cell.
--
-- What they cannot do is shoot, punch, or get into a vehicle unaided. The loop
-- runs only while actually cuffed, so it costs nothing the rest of the time.
CreateThread(function()
    while true do
        if cuffed then
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 24, true)   -- attack
            DisableControlAction(0, 25, true)   -- aim
            DisableControlAction(0, 47, true)   -- weapon
            DisableControlAction(0, 58, true)   -- weapon
            DisableControlAction(0, 140, true)  -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            -- Entering a vehicle. They have to be PUT in one.
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)

            if not IsEntityPlayingAnim(cache.ped, Config.Custody.anim.dict,
                Config.Custody.anim.clip, 3) then
                playCuffAnim()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Being escorted and moved
-- ---------------------------------------------------------------------------

RegisterNetEvent('som-police:client:beginEscort', function(escorterId)
    local escorter = GetPlayerFromServerId(escorterId)
    if escorter == -1 then return end

    escortedBy = escorterId
    AttachEntityToEntity(cache.ped, GetPlayerPed(escorter), 11816,
        0.45, 0.45, 0.0, 0.0, 0.0, 20.0, false, false, false, false, 2, true)
end)

RegisterNetEvent('som-police:client:endEscort', function()
    escortedBy = nil
    DetachEntity(cache.ped, true, false)
end)

RegisterNetEvent('som-police:client:intoVehicle', function(netId, seat)
    local vehicle = NetworkDoesEntityExistWithNetworkId(netId)
        and NetworkGetEntityFromNetworkId(netId) or nil

    if not vehicle or vehicle == 0 then return end

    if escortedBy then
        escortedBy = nil
        DetachEntity(cache.ped, true, false)
    end

    SetPedIntoVehicle(cache.ped, vehicle, seat)
end)

RegisterNetEvent('som-police:client:outOfVehicle', function()
    if not cache.vehicle then return end

    TaskLeaveVehicle(cache.ped, cache.vehicle, 16)
end)

-- ---------------------------------------------------------------------------
-- The eye
--
-- Registered once. `canInteract` decides what is shown; the server decides what
-- happens. Note which options are NOT job gated: restraint and moving are
-- available to anyone carrying handcuffs, because kidnapping has to be
-- possible for policing to mean anything.
-- ---------------------------------------------------------------------------

---@param entity number
---@return number|nil server id
local function serverIdOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end

    return GetPlayerServerId(player)
end

---Whether the player is carrying handcuffs. A UI filter: the server checks the
---same thing again, and is the one that matters.
local function carryingCuffs()
    return (exports.ox_inventory:GetItemCount(Config.Custody.item) or 0) > 0
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'police:cuff',
            icon = 'fa-solid fa-handcuffs',
            label = 'Cuff',
            distance = Config.Custody.distance,
            canInteract = function(entity)
                return carryingCuffs() and not Custody.IsCuffed()
            end,
            onSelect = function(data)
                Custody.Request.cuff(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:uncuff',
            icon = 'fa-solid fa-unlock',
            label = 'Uncuff',
            distance = Config.Custody.distance,
            canInteract = function() return not Custody.IsCuffed() end,
            onSelect = function(data)
                Custody.Request.uncuff(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:escort',
            icon = 'fa-solid fa-people-pulling',
            label = 'Escort',
            distance = Config.Custody.distance,
            canInteract = function() return not Custody.IsCuffed() end,
            onSelect = function(data)
                Custody.Request.escort(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:putin',
            icon = 'fa-solid fa-car-side',
            label = 'Put in vehicle',
            distance = Config.Custody.distance,
            canInteract = function() return not Custody.IsCuffed() end,
            onSelect = function(data)
                Custody.Request.putInVehicle(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:pullout',
            icon = 'fa-solid fa-person-walking-arrow-right',
            label = 'Pull from vehicle',
            distance = 4.0,
            canInteract = function() return not Custody.IsCuffed() end,
            onSelect = function(data)
                Custody.Request.pullFromVehicle(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:search',
            icon = 'fa-solid fa-hand',
            label = 'Search',
            distance = Config.Custody.distance,
            canInteract = function() return not Custody.IsCuffed() end,
            onSelect = function(data)
                Custody.Request.search(serverIdOf(data.entity))
            end,
        },

        -- Police only from here down. These are the verbs that carry
        -- authority rather than merely force.
        {
            name = 'police:checkid',
            icon = 'fa-solid fa-id-card',
            label = 'Check ID',
            distance = Config.Custody.distance,
            canInteract = function() return Duty.IsOnDuty() end,
            onSelect = function(data)
                Custody.Request.checkId(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:seize',
            icon = 'fa-solid fa-sack-dollar',
            label = 'Seize cash',
            distance = Config.Custody.distance,
            canInteract = function() return Duty.IsOnDuty() end,
            onSelect = function(data)
                Custody.Request.seizeCash(serverIdOf(data.entity))
            end,
        },
        {
            name = 'police:fine',
            icon = 'fa-solid fa-receipt',
            label = 'Issue a fine',
            distance = 5.0,
            canInteract = function() return Duty.IsOnDuty() end,
            onSelect = function(data)
                Custody.Request.fine(serverIdOf(data.entity))
            end,
        },
    })
end)

-- Restore state on a resource restart, so reloading som-police does not free
-- everybody who was cuffed.
AddEventHandler('som:client:onMetadataChanged', function(metadata)
    if type(metadata) ~= 'table' then return end

    local should = metadata.cuffed == true
    if should == cuffed then return end

    cuffed = should
    if cuffed then playCuffAnim() else clearCuffAnim() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearCuffAnim()
    if escortedBy then DetachEntity(cache.ped, true, false) end
end)
