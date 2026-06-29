BuildingClient = {}

function BuildingClient.teleportToDoor(doorId, coords)
    if not coords then return end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    ClientUtils.notify('info', ('Teleported to door #%d'):format(doorId))
end

function BuildingClient.highlightBuildingDoors(doorList)
    DoorPreview.clearAll()

    for _, door in ipairs(doorList) do
        if door.coords then
            local objects = GetGamePool('CObject')
            local bestEntity = nil
            local bestDist = 2.0

            for _, obj in ipairs(objects) do
                if DoesEntityExist(obj) then
                    local pos = GetEntityCoords(obj)
                    local dist = #(vector3(door.coords.x, door.coords.y, door.coords.z) - pos)
                    if dist < bestDist and GetEntityModel(obj) == door.model then
                        bestDist = dist
                        bestEntity = obj
                    end
                end
            end

            if bestEntity then
                DoorPreview.highlightEntity(bestEntity)
            end
        end
    end
end
