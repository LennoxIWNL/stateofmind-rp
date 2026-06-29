DoorPreview = {}

local highlightedEntities = {}
local maxHighlights = 50
local themeR, themeG, themeB = 99, 102, 241

function DoorPreview.setThemeColor(hex)
    themeR, themeG, themeB = ClientUtils.hexToRgba(hex)
end

function DoorPreview.highlightEntity(entity)
    if #highlightedEntities >= maxHighlights then return end
    if not DoesEntityExist(entity) then return end

    for _, e in ipairs(highlightedEntities) do
        if e == entity then return end
    end

    highlightedEntities[#highlightedEntities + 1] = entity
    SetEntityDrawOutline(entity, true)
    SetEntityDrawOutlineColor(themeR, themeG, themeB, 255)
    SetEntityDrawOutlineShader(1)
end

function DoorPreview.unhighlightEntity(entity)
    if not DoesEntityExist(entity) then return end
    SetEntityDrawOutline(entity, false)
    for i = #highlightedEntities, 1, -1 do
        if highlightedEntities[i] == entity then
            table.remove(highlightedEntities, i)
            break
        end
    end
end

function DoorPreview.clearAll()
    for _, entity in ipairs(highlightedEntities) do
        if DoesEntityExist(entity) then
            SetEntityDrawOutline(entity, false)
        end
    end
    highlightedEntities = {}
end

function DoorPreview.drawRadiusMarker(center, radius)
    local r, g, b = themeR, themeG, themeB
    DrawMarker(
        1,
        center.x, center.y, center.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        radius * 2.0, radius * 2.0, 0.5,
        r, g, b, 40,
        false, false, 2, false, nil, nil, false
    )
    DrawMarker(
        28,
        center.x, center.y, center.z - 0.95,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        radius * 2.0, radius * 2.0, 0.5,
        r, g, b, 80,
        false, false, 2, false, nil, nil, false
    )
end

function DoorPreview.drawCrosshair()
    DrawRect(0.5, 0.5, 0.002, 0.015, themeR, themeG, themeB, 200)
    DrawRect(0.5, 0.5, 0.015, 0.002, themeR, themeG, themeB, 200)
end

function DoorPreview.getHighlightedCount()
    return #highlightedEntities
end
