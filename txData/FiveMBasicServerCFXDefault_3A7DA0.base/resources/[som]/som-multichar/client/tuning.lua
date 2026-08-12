-- Live scene tuning.
--
-- Shell models differ in where their floor, walls and furniture sit, so the
-- offsets in config are always wrong on the first attempt. Guessing them from
-- screenshots costs a restart per attempt. This lets a staff member nudge the
-- scene while looking at it and print values to paste back into config.lua.
--
-- INPUT: the character screen holds NUI focus with keep-input disabled, so the
-- game control system receives nothing. RegisterKeyMapping never fires, and
-- raw key polling proved unreliable too. The browser, however, receives every
-- keystroke, so input is handled in html/app.js and forwarded here through NUI
-- callbacks. That is the only layer guaranteed to see the keyboard while the
-- character screen is up.
--
-- Client side only and purely cosmetic: it moves a preview ped and a camera
-- that exist solely on this client. It cannot touch player state, money or
-- anything server owned.
--
-- Set Config.SceneTuning.enabled = false for production.

local active = false
local allowed = nil
local target = 'cam'
local step = Config.SceneTuning and Config.SceneTuning.step or 0.1

local function round(n)
    return math.floor(n * 100 + 0.5) / 100
end

local function dump()
    local shell = Config.Shell
    print('^5[som-multichar]^7 paste into config.lua Config.Shell:')
    print(('    pedOffset = vec3(%s, %s, %s),')
        :format(round(shell.pedOffset.x), round(shell.pedOffset.y), round(shell.pedOffset.z)))
    print(('    pedHeading = %s,'):format(round(shell.pedHeading)))
    print(('    camOffset = vec3(%s, %s, %s),')
        :format(round(shell.camOffset.x), round(shell.camOffset.y), round(shell.camOffset.z)))
    print(('    lookHeight = %s,'):format(round(shell.lookHeight or 0.9)))
    print('^5[som-multichar]^7 and into Config.Camera:')
    print(('    fov = %s,'):format(round(Config.Camera.fov)))

    TriggerEvent('som:client:notify', 'Values printed to the F8 console', 'success')
end

local function printCoords()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)

    print(('^5[som-multichar]^7 vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h))
    TriggerEvent('som:client:notify',
        ('%.2f, %.2f, %.2f  (printed to F8)'):format(c.x, c.y, c.z), 'success', 8000)
end

---Input is screen-relative. main.lua converts it using the camera's real
---rotation, since only it holds the camera handle.
local function nudge(dx, dy, dz)
    TriggerEvent('som-multichar:client:nudgeScene', target, dx, dy, dz)
end

---@return boolean
local function mayTune()
    if allowed == nil then
        local ok, result = pcall(function()
            return lib.callback.await('som-multichar:server:canTuneScene', false)
        end)
        allowed = (ok and result) and true or false

        -- Log the outcome: a silent false here previously looked identical to
        -- the keys not working at all.
        print(('^5[som-multichar]^7 scene tuning permission: %s')
            :format(allowed and 'granted' or 'denied'))
    end
    return allowed
end

-- ---------------------------------------------------------------------------
-- NUI callbacks, driven from html/app.js
-- ---------------------------------------------------------------------------

RegisterNUICallback('tuningToggle', function(_, cb)
    if not (Config.SceneTuning and Config.SceneTuning.enabled) then
        cb({ active = false })
        return
    end

    if not Config.Shell.enabled then
        TriggerEvent('som:client:notify', 'Config.Shell.enabled is false, nothing to tune', 'error')
        cb({ active = false })
        return
    end

    if not mayTune() then
        TriggerEvent('som:client:notify', 'You do not have permission to do that', 'error')
        cb({ active = false })
        return
    end

    active = not active

    -- Stop the camera drifting while framing, or judging an offset is guesswork.
    TriggerEvent('som-multichar:client:setOrbit', not active)

    print(('^5[som-multichar]^7 scene tuning %s'):format(active and 'ON' or 'OFF'))
    TriggerEvent('som:client:notify',
        active and 'Tuning ON. Arrows move, Z/X height, +/- zoom, ,/. aim height, Q/E rotate, R target, P print.'
                or 'Tuning OFF',
        active and 'success' or 'info', active and 9000 or 3000)

    cb({ active = active })
end)

RegisterNUICallback('tuningNudge', function(data, cb)
    if active and type(data) == 'table' then
        nudge((tonumber(data.dx) or 0) * step,
              (tonumber(data.dy) or 0) * step,
              (tonumber(data.dz) or 0) * step)
    end
    cb({})
end)

RegisterNUICallback('tuningFov', function(data, cb)
    if active then
        local dir = tonumber(data and data.dir) or 1
        local fov = (Config.Camera.fov or 34.0) + dir

        -- Below about 10 the perspective goes flat and telephoto, above 70 it
        -- distorts badly at this range.
        if fov < 10.0 then fov = 10.0 end
        if fov > 70.0 then fov = 70.0 end

        Config.Camera.fov = fov
        TriggerEvent('som-multichar:client:rebuildScene')
        TriggerEvent('som:client:notify', ('FOV %.0f'):format(fov), 'info', 1200)
    end
    cb({})
end)

RegisterNUICallback('tuningLook', function(data, cb)
    if active then
        local dir = tonumber(data and data.dir) or 1
        local h = (Config.Shell.lookHeight or 0.9) + (dir * 0.05)

        if h < 0.0 then h = 0.0 end
        if h > 2.0 then h = 2.0 end

        Config.Shell.lookHeight = h
        TriggerEvent('som-multichar:client:rebuildScene')
        TriggerEvent('som:client:notify', ('Aim height %.2f'):format(h), 'info', 1200)
    end
    cb({})
end)

RegisterNUICallback('tuningRotate', function(data, cb)
    if active then
        local dir = tonumber(data and data.dir) or 1
        Config.Shell.pedHeading = (Config.Shell.pedHeading + (15.0 * dir)) % 360.0
        TriggerEvent('som-multichar:client:rebuildScene')
    end
    cb({})
end)

RegisterNUICallback('tuningCycle', function(_, cb)
    if active then
        -- Only two things move now. The aim point is gone: the camera always
        -- looks at the character.
        target = target == 'cam' and 'ped' or 'cam'
        TriggerEvent('som:client:notify', ('Moving: %s'):format(target), 'info')
    end
    cb({})
end)

RegisterNUICallback('tuningPrint', function(_, cb)
    if active then dump() end
    cb({})
end)

RegisterNUICallback('tuningCoords', function(_, cb)
    printCoords()
    cb({})
end)

-- ---------------------------------------------------------------------------
-- In-world use
--
-- Once a character is loaded the NUI no longer holds focus, so a normal
-- keybind works and is the right tool for grabbing spawn coordinates.
-- ---------------------------------------------------------------------------

RegisterCommand('somhere', printCoords, false)
-- F10, NOT F11. F11 is pma-voice's Cycle Proximity, which every player uses
-- constantly, and server.cfg does not override voice_defaultCycle. Two
-- mappings on one key means whoever registers second loses, so a dev tool for
-- printing coordinates was quietly sitting on top of talking range.
RegisterKeyMapping('somhere', 'SOM: print my coordinates', 'keyboard', 'F10')
