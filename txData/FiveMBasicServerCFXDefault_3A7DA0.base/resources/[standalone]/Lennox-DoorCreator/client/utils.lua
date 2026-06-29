ClientUtils = {}

function ClientUtils.getModelName(hash)
    if AllDoorHashes[hash] then return AllDoorHashes[hash] end
    return ('0x%X'):format(hash & 0xFFFFFFFF)
end

function ClientUtils.getCategory(hash)
    return DoorCategories[hash] or 'unknown'
end

function ClientUtils.isDoorModel(hash)
    return AllDoorHashes[hash] ~= nil
end

function ClientUtils.getEntityInfo(entity)
    if not DoesEntityExist(entity) then return nil end
    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    return {
        entity = entity,
        model = model,
        modelName = ClientUtils.getModelName(model),
        category = ClientUtils.getCategory(model),
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
    }
end

function ClientUtils.drawText3D(coords, text, scale)
    scale = scale or 0.35
    local onScreen, sX, sY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(sX, sY)
    end
end

function ClientUtils.hexToRgba(hex, alpha)
    hex = hex:gsub('#', '')
    local r = tonumber(hex:sub(1, 2), 16) or 99
    local g = tonumber(hex:sub(3, 4), 16) or 102
    local b = tonumber(hex:sub(5, 6), 16) or 241
    return r, g, b, alpha or 255
end

function ClientUtils.notify(nType, message)
    SendNUIMessage({ type = 'notification', data = { type = nType, message = message } })
end
