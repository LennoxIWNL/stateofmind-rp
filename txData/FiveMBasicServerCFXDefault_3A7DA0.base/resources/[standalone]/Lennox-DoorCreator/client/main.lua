local isOpen = false
local nuiReady = false

local function openUI()
    if isOpen then return end

    local data = lib.callback.await('lennox-doorcreator:server:getData', false)
    if not data then
        lib.notify({ type = 'error', description = 'Access denied or data unavailable.' })
        return
    end

    isOpen = true
    SetNuiFocus(true, true)

    if data.theme then
        DoorPreview.setThemeColor(data.theme)
    end

    SendNUIMessage({
        type = 'open',
        data = data,
    })
end

local function closeUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })

    if DoorCreator.isActive() then
        DoorCreator.cancelSelection()
    end
    if BulkSelector.isActive() then
        BulkSelector.stop()
    end
    DoorPreview.clearAll()
end

-- =========================================================================
--  NUI Callbacks
-- =========================================================================

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('startCreator', function(_, cb)
    DoorCreator.startSelection()
    cb('ok')
end)

RegisterNUICallback('cancelCreator', function(_, cb)
    DoorCreator.cancelSelection()
    cb('ok')
end)

RegisterNUICallback('createDoor', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:createDoor', false, data)
    cb(result)
end)

RegisterNUICallback('editDoor', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:editDoor', false, data.id, data)
    cb(result)
end)

RegisterNUICallback('deleteDoor', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:deleteDoor', false, data.id)
    cb(result)
end)

RegisterNUICallback('getDoor', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:getDoor', false, data.id)
    cb(result)
end)

-- Bulk
RegisterNUICallback('startBulk', function(_, cb)
    BulkSelector.start()
    cb('ok')
end)

RegisterNUICallback('stopBulk', function(_, cb)
    BulkSelector.stop()
    cb('ok')
end)

RegisterNUICallback('setRadius', function(data, cb)
    BulkSelector.setRadius(data.radius)
    cb('ok')
end)

RegisterNUICallback('toggleBulkEntity', function(data, cb)
    BulkSelector.toggleEntity(data.index)
    cb('ok')
end)

RegisterNUICallback('bulkCreate', function(data, cb)
    local selected = BulkSelector.getSelected()
    local result = lib.callback.await('lennox-doorcreator:server:bulkCreate', false, selected, data.settings)
    BulkSelector.stop()
    cb(result)
end)

-- Buildings
RegisterNUICallback('createBuilding', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:createBuilding', false, data)
    cb(result)
end)

RegisterNUICallback('editBuilding', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:editBuilding', false, data.id, data)
    cb(result)
end)

RegisterNUICallback('deleteBuilding', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:deleteBuilding', false, data.id, data.deleteDoors)
    cb(result)
end)

RegisterNUICallback('applyBuildingPerms', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:applyBuildingPerms', false, data.id, data.permissions)
    cb(result)
end)

RegisterNUICallback('highlightBuilding', function(data, cb)
    BuildingClient.highlightBuildingDoors(data.doors or {})
    cb('ok')
end)

-- Templates
RegisterNUICallback('getTemplates', function(_, cb)
    local result = lib.callback.await('lennox-doorcreator:server:getTemplates', false)
    cb(result)
end)

RegisterNUICallback('createTemplate', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:createTemplate', false, data)
    cb(result)
end)

RegisterNUICallback('getTemplate', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:getTemplate', false, data.id)
    cb(result)
end)

RegisterNUICallback('deleteTemplate', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:deleteTemplate', false, data.id)
    cb(result)
end)

RegisterNUICallback('exportTemplate', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:exportTemplate', false, data.id)
    cb(result)
end)

RegisterNUICallback('importTemplate', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:importTemplate', false, data.importStr)
    cb(result)
end)

-- Import
RegisterNUICallback('importPreview', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:importPreview', false, data.source, data.content)
    cb(result)
end)

RegisterNUICallback('importExecute', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:importExecute', false, data.doors)
    cb(result)
end)

-- Backups
RegisterNUICallback('getBackups', function(_, cb)
    local result = lib.callback.await('lennox-doorcreator:server:getBackups', false)
    cb(result)
end)

RegisterNUICallback('createBackup', function(_, cb)
    local result = lib.callback.await('lennox-doorcreator:server:createBackup', false)
    cb(result)
end)

RegisterNUICallback('previewBackup', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:previewBackup', false, data.id)
    cb(result)
end)

RegisterNUICallback('restoreBackup', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:restoreBackup', false, data.id)
    cb(result)
end)

RegisterNUICallback('deleteBackup', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:deleteBackup', false, data.id)
    cb(result)
end)

-- Logs
RegisterNUICallback('getLogs', function(data, cb)
    local result = lib.callback.await('lennox-doorcreator:server:getLogs', false, data)
    cb(result)
end)

-- Teleport
RegisterNUICallback('teleportToDoor', function(data, cb)
    if data.coords then
        SetEntityCoords(PlayerPedId(), data.coords.x, data.coords.y, data.coords.z, false, false, false, false)
    end
    cb('ok')
end)

-- Refresh data
RegisterNUICallback('refreshData', function(_, cb)
    local data = lib.callback.await('lennox-doorcreator:server:getData', false)
    cb(data)
end)

-- =========================================================================
--  Events
-- =========================================================================

RegisterNetEvent('lennox-doorcreator:client:open', function()
    openUI()
end)

RegisterNetEvent('lennox-doorcreator:client:notify', function(nType, message)
    ClientUtils.notify(nType, message)
    lib.notify({ type = nType, description = message })
end)

RegisterNetEvent('lennox-doorcreator:client:teleport', function(coords)
    if coords then
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    end
end)

-- =========================================================================
--  Keybind
-- =========================================================================

if Config.Keybind then
    RegisterKeyMapping(Config.Command, 'Open Lennox Door Creator', 'keyboard', Config.Keybind)
end
