--- A "Serve court papers" option on other players while a paper is held. The
--- server has chosen the paper and checks the person, the distance and the
--- time; this only asks and shows the progress bar.

local holding, busy = false, false

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

RegisterNetEvent('som-serving:client:hold', function(on)
    holding = on == true
end)

local function serve(ped)
    local index = NetworkGetPlayerIndexFromPed(ped)
    if index == -1 then return end
    local target = GetPlayerServerId(index)
    if target <= 0 then return end

    busy = true
    local began = lib.callback.await('som-serving:server:begin', false, target)
    if not began or not began.success then
        busy = false
        return say(began and began.error or 'Failed', 'error')
    end

    local ok = lib.progressBar({
        duration = Config.seconds * 1000, label = 'Serving court papers', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a' },
    })
    if not ok then
        busy = false
        return
    end

    local result = lib.callback.await('som-serving:server:finish', false, target)
    busy = false
    if result and not result.success then say(result.error or 'Failed', 'error') end
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'som_serving_serve', label = 'Serve court papers', icon = 'fa-solid fa-file-signature',
            distance = Config.distance,
            canInteract = function() return holding and not busy end,
            onSelect = function(data)
                if data and data.entity then serve(data.entity) end
            end,
        },
    })
end)
