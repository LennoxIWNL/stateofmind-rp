--- Where the court is reached: a desk for the bench and the bar, and the eye
--- on a nearby player for an officer filing a case.

local function serverIdOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

CreateThread(function()
    exports['som-interact']:addBoxZone({
        name = 'court:desk',
        coords = Config.Desk.coords,
        size = Config.Desk.size,
        rotation = Config.Desk.rotation,
        options = {
            {
                name = 'court:docket',
                icon = 'fa-solid fa-gavel',
                label = 'Court docket',
                distance = 2.0,
                onSelect = Menus.Docket,
            },
            {
                name = 'court:mine',
                icon = 'fa-solid fa-folder-open',
                label = 'My cases',
                distance = 2.0,
                onSelect = Menus.MyCases,
            },
        },
    })

    exports['som-interact']:addGlobalPlayer({
        {
            name = 'court:file',
            icon = 'fa-solid fa-file-pen',
            label = 'File court case',
            distance = 3.0,
            onSelect = function(data)
                local target = serverIdOf(data.entity)
                if target then Menus.File(target) end
            end,
        },
    })
end)
