DoorCreator = {}

local isSelecting = false
local selectedDoor1 = nil
local selectedDoor2 = nil
local awaitingSecondDoor = false
local currentTarget = nil

function DoorCreator.startSelection()
    isSelecting = true
    selectedDoor1 = nil
    selectedDoor2 = nil
    awaitingSecondDoor = false
    currentTarget = nil

    SendNUIMessage({ type = 'creatorMode', data = { active = true } })

    Citizen.CreateThread(function()
        while isSelecting do
            Citizen.Wait(0)
            DoorPreview.drawCrosshair()

            local hit, entity = DoorCreator.raycast()
            if hit and entity ~= currentTarget then
                if currentTarget then
                    DoorPreview.unhighlightEntity(currentTarget)
                end
                currentTarget = entity
                DoorPreview.highlightEntity(entity)

                local info = ClientUtils.getEntityInfo(entity)
                if info then
                    SendNUIMessage({
                        type = 'doorDetected',
                        data = {
                            model = info.model,
                            modelName = info.modelName,
                            category = info.category,
                            coords = info.coords,
                            heading = info.heading,
                        },
                    })
                end
            elseif not hit and currentTarget then
                DoorPreview.unhighlightEntity(currentTarget)
                currentTarget = nil
                SendNUIMessage({ type = 'doorDetected', data = json.null })
            end

            if currentTarget then
                local info = ClientUtils.getEntityInfo(currentTarget)
                if info then
                    ClientUtils.drawText3D(
                        vector3(info.coords.x, info.coords.y, info.coords.z),
                        awaitingSecondDoor and '~b~Select 2nd Door' or ('~b~' .. info.modelName)
                    )
                end
            end

            if IsControlJustPressed(0, 191) then -- ENTER
                if currentTarget then
                    DoorCreator.confirmSelection()
                end
            end

            if IsControlJustPressed(0, 194) then -- BACKSPACE
                if awaitingSecondDoor then
                    awaitingSecondDoor = false
                    DoorCreator.finishSelection()
                else
                    DoorCreator.cancelSelection()
                end
            end
        end
    end)
end

function DoorCreator.raycast()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local rX = camRot.x * math.pi / 180.0
    local rZ = camRot.z * math.pi / 180.0

    local dir = vector3(
        -math.sin(rZ) * math.abs(math.cos(rX)),
        math.cos(rZ) * math.abs(math.cos(rX)),
        math.sin(rX)
    )

    local dest = camCoords + dir * Config.RaycastDistance

    local ray = StartShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        dest.x, dest.y, dest.z,
        16, -- objects
        PlayerPedId(),
        0
    )

    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit == 1 and DoesEntityExist(entity) then
        local model = GetEntityModel(entity)
        if ClientUtils.isDoorModel(model) then
            return true, entity
        end
        if GetEntityType(entity) == 3 then
            return true, entity
        end
    end

    return false, nil
end

function DoorCreator.confirmSelection()
    if not currentTarget then return end

    local info = ClientUtils.getEntityInfo(currentTarget)
    if not info then return end

    if not selectedDoor1 then
        selectedDoor1 = info
        awaitingSecondDoor = true

        SendNUIMessage({
            type = 'doorSelected',
            data = {
                door = 1,
                info = info,
                awaitingSecond = true,
            },
        })

        ClientUtils.notify('info', 'Door 1 selected. Select door 2 for a double door, or press Backspace to skip.')
    elseif awaitingSecondDoor then
        selectedDoor2 = info
        awaitingSecondDoor = false
        DoorCreator.finishSelection()
    end
end

function DoorCreator.finishSelection()
    isSelecting = false
    DoorPreview.clearAll()

    local doorData = {
        model = selectedDoor1.model,
        coords = selectedDoor1.coords,
        heading = selectedDoor1.heading,
        modelName = selectedDoor1.modelName,
        category = selectedDoor1.category,
    }

    if selectedDoor2 then
        local cx = (selectedDoor1.coords.x + selectedDoor2.coords.x) / 2
        local cy = (selectedDoor1.coords.y + selectedDoor2.coords.y) / 2
        local cz = (selectedDoor1.coords.z + selectedDoor2.coords.z) / 2

        doorData.doors = {
            { coords = selectedDoor1.coords, heading = selectedDoor1.heading, model = selectedDoor1.model },
            { coords = selectedDoor2.coords, heading = selectedDoor2.heading, model = selectedDoor2.model },
        }
        doorData.coords = { x = cx, y = cy, z = cz }
        doorData.isDouble = true
    end

    SendNUIMessage({
        type = 'openEditor',
        data = doorData,
    })
end

function DoorCreator.cancelSelection()
    isSelecting = false
    awaitingSecondDoor = false
    selectedDoor1 = nil
    selectedDoor2 = nil
    currentTarget = nil
    DoorPreview.clearAll()

    SendNUIMessage({ type = 'creatorMode', data = { active = false } })
end

function DoorCreator.isActive()
    return isSelecting
end
