--- Draws the track and asks the server to judge. The client holds no coordinates
--- it makes up and decides nothing: it sends "I am at checkpoint n" and moves on
--- only when the server says the checkpoint counted.

local recording, race, blip

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'inform') end

-- ---------------------------------------------------------------------------
-- Recording a track: drop checkpoints from the car, the server reads the position
-- ---------------------------------------------------------------------------

local function stopRecording()
    recording = nil
    exports['som-interact']:hideTextUI()
end

local function showCount(count, length)
    exports['som-interact']:showTextUI(('Recording a track: %d checkpoints, %d m. Page Up drops one, Page Down saves, End cancels'):format(count, length))
end

RegisterNetEvent('som-racing:client:record', function(max)
    TriggerEvent('som-phone:client:close')
    recording = { count = 0, length = 0, max = max }
    showCount(0, 0)
end)

lib.addKeybind({
    name = 'som_racing_drop', description = 'Race track: drop a checkpoint', defaultKey = 'PAGEUP',
    onPressed = function()
        if not recording then return end
        local res = lib.callback.await('som-racing:server:drop', false)
        if not res or not res.success then
            if res and res.ended then stopRecording() end
            return notify(res and res.error or 'Not available', 'error')
        end
        recording.count, recording.length = res.count, res.length
        showCount(res.count, res.length)
    end,
})

lib.addKeybind({
    name = 'som_racing_save', description = 'Race track: save it', defaultKey = 'PAGEDOWN',
    onPressed = function()
        if not recording then return end
        local input = lib.inputDialog('Save the track', { { type = 'input', label = 'Name', required = true, min = 4, max = 32 } })
        if not input or not recording then return end
        local res = lib.callback.await('som-racing:server:save', false, input[1])
        if not res or not res.success then
            if res and res.ended then stopRecording() end
            return notify(res and res.error or 'Not available', 'error')
        end
        stopRecording()
        notify('Track saved', 'success')
    end,
})

lib.addKeybind({
    name = 'som_racing_cancel', description = 'Race track: stop recording', defaultKey = 'END',
    onPressed = function()
        if not recording then return end
        TriggerServerEvent('som-racing:server:abortRecording')
        stopRecording()
    end,
})

-- ---------------------------------------------------------------------------
-- Racing
-- ---------------------------------------------------------------------------

local function target()
    return race.points[(race.seq + 1) % #race.points + 1]
end

local function moveBlip()
    if blip then RemoveBlip(blip) end
    local t = target()
    blip = AddBlipForCoord(t.x, t.y, t.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
end

local function clear()
    if blip then RemoveBlip(blip) end
    blip, race = nil, nil
end

RegisterNetEvent('som-racing:client:begin', function(data)
    clear()
    if type(data) ~= 'table' or type(data.points) ~= 'table' or #data.points < 2 then return end

    local points = {}
    for i, p in ipairs(data.points) do points[i] = vec3(p.x, p.y, p.z) end
    race = { points = points, laps = data.laps, radius = data.radius, seq = 0, lastSent = 0, startAt = GetGameTimer() + data.countdown * 1000 }
    moveBlip()

    local mine = race
    CreateThread(function()
        for i = data.countdown, 1, -1 do
            if race ~= mine then return end
            notify(tostring(i))
            Wait(1000)
        end
        if race == mine then notify('Go', 'success') end
    end)

    -- Rendering the ring needs every frame; this loop exists only while this player is in a live race.
    CreateThread(function()
        while race == mine do
            Wait(0)
            local now = GetGameTimer()
            if now >= mine.startAt then
                local t = target()
                DrawMarker(1, t.x, t.y, t.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mine.radius * 2.0, mine.radius * 2.0, 8.0,
                    255, 159, 10, 110, false, false, 2, false, nil, nil, false)
                if #(GetEntityCoords(PlayerPedId()) - t) <= mine.radius and now - mine.lastSent > 700 then
                    mine.lastSent = now
                    TriggerServerEvent('som-racing:server:checkpoint', mine.seq + 1)
                end
            end
        end
    end)
end)

RegisterNetEvent('som-racing:client:progress', function(seq)
    if not race or math.type(seq) ~= 'integer' then return end
    race.seq = seq
    if seq >= #race.points * race.laps then return clear() end
    moveBlip()
end)

RegisterNetEvent('som-racing:client:stop', clear)
