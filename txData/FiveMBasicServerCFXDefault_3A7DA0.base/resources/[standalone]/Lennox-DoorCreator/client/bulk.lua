BulkSelector = {}

local isActive = false
local radius = Config.BulkDefaultRadius
local centerPos = nil
local detectedEntities = {}
local selectedEntities = {}
local lastScanPos = nil
local scanCooldown = 0

function BulkSelector.start()
    isActive = true
    radius = Config.BulkDefaultRadius
    centerPos = GetEntityCoords(PlayerPedId())
    detectedEntities = {}
    selectedEntities = {}
    lastScanPos = nil

    BulkSelector.scan()
    SendNUIMessage({ type = 'bulkMode', data = { active = true, radius = radius } })

    Citizen.CreateThread(function()
        while isActive do
            Citizen.Wait(0)
            if centerPos then
                DoorPreview.drawRadiusMarker(centerPos, radius)
            end
        end
    end)

    Citizen.CreateThread(function()
        while isActive do
            Citizen.Wait(500)
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            if not lastScanPos or #(pos - lastScanPos) > 5.0 then
                centerPos = pos
                BulkSelector.scan()
            end
        end
    end)
end

function BulkSelector.stop()
    isActive = false
    DoorPreview.clearAll()
    detectedEntities = {}
    selectedEntities = {}
    SendNUIMessage({ type = 'bulkMode', data = { active = false } })
end

function BulkSelector.setRadius(newRadius)
    radius = math.max(Config.BulkMinRadius, math.min(Config.BulkMaxRadius, newRadius))
    BulkSelector.scan()
    SendNUIMessage({ type = 'bulkMode', data = { active = true, radius = radius } })
end

function BulkSelector.scan()
    if not centerPos then return end
    lastScanPos = centerPos

    DoorPreview.clearAll()
    detectedEntities = {}

    local objects = GetGamePool('CObject')
    for _, obj in ipairs(objects) do
        if DoesEntityExist(obj) then
            local model = GetEntityModel(obj)
            local pos = GetEntityCoords(obj)
            local dist = #(centerPos - pos)

            if dist <= radius then
                local isDoor = ClientUtils.isDoorModel(model)
                local isObject = GetEntityType(obj) == 3

                if isDoor or isObject then
                    local info = ClientUtils.getEntityInfo(obj)
                    if info then
                        info.distance = math.floor(dist * 10) / 10
                        info.selected = true
                        detectedEntities[#detectedEntities + 1] = info
                        DoorPreview.highlightEntity(obj)
                    end
                end
            end
        end
    end

    table.sort(detectedEntities, function(a, b) return a.distance < b.distance end)

    selectedEntities = {}
    for _, e in ipairs(detectedEntities) do
        if e.selected then
            selectedEntities[#selectedEntities + 1] = e
        end
    end

    SendNUIMessage({
        type = 'bulkUpdate',
        data = {
            entities = detectedEntities,
            radius = radius,
            count = #detectedEntities,
        },
    })
end

function BulkSelector.toggleEntity(index)
    if detectedEntities[index] then
        detectedEntities[index].selected = not detectedEntities[index].selected
        local entity = detectedEntities[index].entity
        if detectedEntities[index].selected then
            DoorPreview.highlightEntity(entity)
        else
            DoorPreview.unhighlightEntity(entity)
        end
    end
    BulkSelector.updateSelected()
end

function BulkSelector.updateSelected()
    selectedEntities = {}
    for _, e in ipairs(detectedEntities) do
        if e.selected then
            selectedEntities[#selectedEntities + 1] = e
        end
    end
    SendNUIMessage({
        type = 'bulkUpdate',
        data = {
            entities = detectedEntities,
            radius = radius,
            count = #selectedEntities,
        },
    })
end

function BulkSelector.getSelected()
    local doors = {}
    for _, e in ipairs(selectedEntities) do
        doors[#doors + 1] = {
            model = e.model,
            coords = e.coords,
            heading = e.heading,
            modelName = e.modelName,
            category = e.category,
        }
    end
    return doors
end

function BulkSelector.isActive()
    return isActive
end
