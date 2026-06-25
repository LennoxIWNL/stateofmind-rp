local QBCore = exports['qb-core']:GetCoreObject()

local points = {}
local spawned = {}
local markerOn = {}
local showCoords = false
local uiOpen = false

-- ===========================================================================
--  Helpers
-- ===========================================================================
local function vec(p) return vector3(p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 0.0) end
local function zoneName(id) return ('som_js_%s'):format(id) end

local function getRaycastCoords()
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    local radX = camRot.x * math.pi / 180.0
    local radZ = camRot.z * math.pi / 180.0
    local dir = vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )
    local dest = camPos + dir * 25.0
    local handle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 7)
    local _, hit, endCoords, surfaceNormal = GetShapeTestResult(handle)
    if hit == 1 then return endCoords, surfaceNormal end
    return nil
end

local function snapToGround(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found then return gz end
    found, gz = GetGroundZFor_3dCoord(x, y, z - 0.5, false)
    if found then return gz end
    return z
end

local aimingMode = false
local aimCallback = nil

local function startAimMode(cb)
    aimingMode = true
    aimCallback = cb
    lib.notify({ title = 'Job Setup', description = 'Aim at the FLOOR where you want the point. LEFT CLICK to confirm, RIGHT CLICK to cancel.', type = 'inform', duration = 5000 })
end

CreateThread(function()
    while true do
        if aimingMode then
            local coords, normal = getRaycastCoords()
            if coords then
                local gz = snapToGround(coords.x, coords.y, coords.z)
                DrawMarker(28, coords.x, coords.y, gz, 0, 0, 0, 0, 0, 0,
                    0.15, 0.15, 0.15,
                    255, 20, 147, 200,
                    false, true, 2, false, nil, nil, false)
                DrawMarker(1, coords.x, coords.y, gz, 0, 0, 0, 0, 0, 0,
                    1.0, 1.0, 0.05,
                    255, 20, 147, 80,
                    false, true, 2, false, nil, nil, false)
            end

            if IsControlJustPressed(0, 24) then
                aimingMode = false
                if coords and aimCallback then
                    local gz = snapToGround(coords.x, coords.y, coords.z)
                    local heading = GetEntityHeading(PlayerPedId())
                    aimCallback(
                        { x = math.floor(coords.x * 100) / 100, y = math.floor(coords.y * 100) / 100, z = math.floor(gz * 100) / 100 },
                        math.floor(heading * 100) / 100
                    )
                    aimCallback = nil
                end
            elseif IsControlJustPressed(0, 25) then
                aimingMode = false
                aimCallback = nil
                lib.notify({ title = 'Job Setup', description = 'Cancelled', type = 'error' })
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function captureHere()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100 },
           math.floor(GetEntityHeading(ped) * 100) / 100
end

local function runAction(point)
    local a = point.action
    if not a or not a.kind or not a.name then return end
    if a.kind == 'event' then
        TriggerEvent(a.name, a.args)
    elseif a.kind == 'server_event' then
        TriggerServerEvent(a.name, a.args)
    elseif a.kind == 'command' then
        ExecuteCommand(a.name)
    elseif a.kind == 'export' and a.resource then
        pcall(function() exports[a.resource][a.name](a.args) end)
    end
end

-- ===========================================================================
--  Render / clear points
-- ===========================================================================
local function clearPoint(id)
    local s = spawned[id]
    if not s then return end
    if s.blip and DoesBlipExist(s.blip) then RemoveBlip(s.blip) end
    if s.ped and DoesEntityExist(s.ped) then DeleteEntity(s.ped) end
    if s.zoneName then exports['qb-target']:RemoveZone(s.zoneName) end
    spawned[id] = nil
end

local function clearAll()
    for id in pairs(spawned) do clearPoint(id) end
end

local function renderPoint(point)
    clearPoint(point.id)
    local s = {}
    local coords = vec(point)
    local typeDef = Config.Types[point.type] or {}

    local blipCfg = point.blip or typeDef.blip
    if blipCfg then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, blipCfg.sprite or 1)
        SetBlipColour(blip, blipCfg.color or 0)
        SetBlipScale(blip, blipCfg.scale or 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(point.label or typeDef.label or point.job)
        EndTextCommandSetBlipName(blip)
        s.blip = blip
    end

    local pedModel = point.ped or typeDef.ped
    if pedModel then
        local hash = type(pedModel) == 'number' and pedModel or GetHashKey(pedModel)
        RequestModel(hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
        if HasModelLoaded(hash) then
            local pedZ = snapToGround(coords.x, coords.y, coords.z)
            local ped = CreatePed(4, hash, coords.x, coords.y, pedZ, point.heading or 0.0, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            s.ped = ped
            SetModelAsNoLongerNeeded(hash)
        end
    end

    local hasAction = (point.action and point.action.kind) and true or false
    if hasAction or point.type ~= 'blip' then
        local zn = zoneName(point.id)
        exports['qb-target']:AddCircleZone(zn, coords, (point.radius or 1.5) + 0.0,
            { name = zn, useZ = true, debugPoly = false },
            {
                options = { {
                    icon = (point.targetIcon or typeDef.targetIcon or 'fas fa-hand-pointer'),
                    label = (point.targetLabel or typeDef.targetLabel or 'Interact'),
                    job = point.restrictJob and point.job or nil,
                    action = function() runAction(point) end,
                    canInteract = function() return true end,
                } },
                distance = Config.TargetDistance,
            })
        s.zoneName = zn
    end

    spawned[point.id] = s
end

local function renderAll()
    clearAll()
    for _, p in pairs(points) do renderPoint(p) end
end

-- ===========================================================================
--  Sync
-- ===========================================================================
local function sortedPointsList()
    local list = {}
    for _, p in pairs(points) do list[#list + 1] = p end
    table.sort(list, function(a, b) return (a.job or '') .. (a.label or '') < (b.job or '') .. (b.label or '') end)
    return list
end

RegisterNetEvent('som-jobsetup:client:sync', function(list)
    points = {}
    for _, p in ipairs(list) do points[p.id] = p end
    renderAll()
    if uiOpen then
        SendNUIMessage({ type = 'updatePoints', points = sortedPointsList() })
    end
end)

-- ===========================================================================
--  Marker / coords draw loop
-- ===========================================================================
CreateThread(function()
    while true do
        local sleep = 500
        if showCoords or next(markerOn) then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            for id, on in pairs(markerOn) do
                local p = points[id]
                if on and p then
                    local c = vec(p)
                    if #(pc - c) < Config.MarkerDrawDistance then
                        sleep = 0
                        DrawMarker(Config.Marker.type, c.x, c.y, c.z - 0.95, 0, 0, 0, 0, 0, 0,
                            Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                            Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                            false, true, 2, nil, nil, false)
                    end
                end
            end
            if showCoords then
                sleep = 0
                local h = GetEntityHeading(ped)
                local txt = ('~q~SoM ~w~Coords: ~q~%.2f~w~, ~q~%.2f~w~, ~q~%.2f~w~  Head: ~q~%.2f'):format(pc.x, pc.y, pc.z, h)
                SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 255, 255, 220)
                SetTextOutline(); SetTextEntry('STRING')
                AddTextComponentString(txt)
                DrawText(0.5, 0.92)
            end
        end
        Wait(sleep)
    end
end)

-- ===========================================================================
--  NUI — open / close
-- ===========================================================================
local setFocus = SetNuiFocus or SetNUIFocus

local function openUI()
    if uiOpen then return end
    uiOpen = true
    setFocus(true, true)
    SendNUIMessage({
        type = 'open',
        page = 'home',
        data = {
            points = sortedPointsList(),
            types = Config.Types,
            jobs = Config.Jobs,
            jobConfigs = Config.JobConfigs,
        }
    })
end

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    setFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

-- ===========================================================================
--  NUI Callbacks — Points
-- ===========================================================================
RegisterNUICallback('addPoint', function(data, cb)
    cb('ok')
    closeUI()
    startAimMode(function(coords, heading)
        TriggerServerEvent('som-jobsetup:server:save', {
            label = data.label or 'New Point',
            job = data.job or 'unknown',
            type = data.pointType or 'target',
            radius = (tonumber(data.radius) or 1.5) + 0.0,
            restrictJob = data.restrictJob and true or false,
            coords = coords,
            heading = heading,
        })
        lib.notify({ title = 'Job Setup', description = 'Point created!', type = 'success' })
    end)
end)

RegisterNUICallback('teleportToPoint', function(data, cb)
    local point = points[tonumber(data.id)]
    if point then
        SetEntityCoords(PlayerPedId(), vec(point).x, vec(point).y, vec(point).z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), point.heading or 0.0)
    end
    cb('ok')
end)

RegisterNUICallback('movePoint', function(data, cb)
    cb('ok')
    local point = points[tonumber(data.id)]
    if not point then return end
    closeUI()
    startAimMode(function(coords, heading)
        point.coords, point.heading = coords, heading
        TriggerServerEvent('som-jobsetup:server:save', point)
        lib.notify({ title = 'Job Setup', description = 'Point moved!', type = 'success' })
    end)
end)

RegisterNUICallback('deletePoint', function(data, cb)
    TriggerServerEvent('som-jobsetup:server:delete', tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('saveAction', function(data, cb)
    local point = points[tonumber(data.id)]
    if point then
        if data.kind == 'none' then
            point.action = nil
        else
            point.action = {
                kind = data.kind,
                name = data.name or '',
                resource = (data.resource ~= '' and data.resource) or nil,
                args = (data.args ~= '' and data.args) or nil,
            }
        end
        TriggerServerEvent('som-jobsetup:server:save', point)
    end
    cb('ok')
end)

RegisterNUICallback('toggleMarker', function(data, cb)
    local id = tonumber(data.id)
    markerOn[id] = not markerOn[id]
    cb({ markerOn = markerOn[id] and true or false })
end)

RegisterNUICallback('toggleCoords', function(_, cb)
    showCoords = not showCoords
    cb({ showCoords = showCoords })
end)

RegisterNUICallback('exportPoints', function(_, cb)
    TriggerServerEvent('som-jobsetup:server:export')
    cb('ok')
end)

RegisterNUICallback('getCoords', function(_, cb)
    local rc = getRaycastCoords()
    if rc then
        cb({ x = math.floor(rc.x * 100) / 100, y = math.floor(rc.y * 100) / 100, z = math.floor(rc.z * 100) / 100, heading = math.floor(GetEntityHeading(PlayerPedId()) * 100) / 100 })
    else
        local c, h = captureHere()
        cb({ x = c.x, y = c.y, z = c.z, heading = h })
    end
end)

-- ===========================================================================
--  NUI Callbacks — Job Config Injection
-- ===========================================================================
local jobLocCache = {}

RegisterNetEvent('som-jobsetup:client:jobLocations', function(resource, list)
    jobLocCache[resource] = list
end)

RegisterNUICallback('getJobLocations', function(data, cb)
    jobLocCache[data.resource] = nil
    TriggerServerEvent('som-jobsetup:server:getJobLocations', data.resource)
    local waited = 0
    while not jobLocCache[data.resource] and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    cb({ locations = jobLocCache[data.resource] or {} })
end)

RegisterNUICallback('patchLocation', function(data, cb)
    cb('ok')
    closeUI()
    startAimMode(function(coords, heading)
        TriggerServerEvent('som-jobsetup:server:patchJobLocation', {
            resource = data.resource,
            locType = data.locType,
            index = tonumber(data.index),
            x = coords.x, y = coords.y, z = coords.z, h = heading,
            restart = data.restart and true or false,
        })
        lib.notify({ title = 'Job Setup', description = 'Location written!', type = 'success' })
    end)
end)

-- ===========================================================================
--  Command / lifecycle
-- ===========================================================================
RegisterCommand(Config.Command, function() openUI() end, false)

RegisterNetEvent('som-jobsetup:client:export', function(raw)
    print('^5[som-jobsetup]^7 ===== points.json =====')
    print(raw)
    print('^5[som-jobsetup]^7 ======================')
    lib.notify({ title = 'Job Setup', description = 'Points JSON printed to F8 console', type = 'inform' })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        closeUI()
        clearAll()
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('som-jobsetup:server:requestSync')
end)
