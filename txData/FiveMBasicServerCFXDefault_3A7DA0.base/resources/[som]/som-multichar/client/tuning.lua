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
    print(('    camLookAtOffset = vec3(%s, %s, %s),')
        :format(round(shell.camLookAtOffset.x), round(shell.camLookAtOffset.y), round(shell.camLookAtOffset.z)))

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

local function nudge(dx, dy, dz)
    local shell = Config.Shell

    if target == 'cam' then
        shell.camOffset = shell.camOffset + vec3(dx, dy, dz)
    elseif target == 'look' then
        shell.camLookAtOffset = shell.camLookAtOffset + vec3(dx, dy, dz)
    else
        shell.pedOffset = shell.pedOffset + vec3(dx, dy, dz)
    end

    TriggerEvent('som-multichar:client:rebuildScene')
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
        active and 'Tuning ON. Arrows move, PgUp/PgDn height, Q/E rotate, R target, P print.'
                or 'Tuning OFF',
        active and 'success' or 'info')

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
        target = target == 'cam' and 'look' or (target == 'look' and 'ped' or 'cam')
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
RegisterKeyMapping('somhere', 'SOM: print my coordinates', 'keyboard', 'F11')
