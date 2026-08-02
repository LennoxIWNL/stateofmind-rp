-- Live scene tuning.
--
-- Shell models differ in where their floor, walls and furniture sit, so the
-- offsets in config are always wrong on the first attempt. Guessing them from
-- screenshots costs a restart per attempt. This lets a staff member nudge the
-- scene while looking at it and print values to paste back into config.lua.
--
-- INPUT NOTE: the character screen holds NUI focus with keep-input disabled,
-- so the game control system receives nothing and RegisterKeyMapping bindings
-- never fire. Everything here therefore polls IsRawKeyPressed, which reads the
-- keyboard directly and works regardless of who owns focus.
--
-- Numpad is used for the nudge keys on purpose: the arrow keys are already
-- bound to roster navigation inside the NUI, and both would fire at once.
--
-- Client side only and purely cosmetic: it moves a preview ped and a camera
-- that exist solely on this client. It cannot touch player state, money or
-- anything server owned.
--
-- Set Config.SceneTuning.enabled = false for production.

if not Config.SceneTuning or not Config.SceneTuning.enabled then return end

local KEY = {
    F10 = 121, F11 = 122,
    NUM0 = 96, NUM1 = 97, NUM2 = 98, NUM3 = 99, NUM4 = 100,
    NUM5 = 101, NUM6 = 102, NUM7 = 103, NUM8 = 104, NUM9 = 105,
}

local active = false
local allowed = nil
local target = 'cam'
local step = Config.SceneTuning.step or 0.1
local held = {}

---Edge detection: IsRawKeyPressed is true for as long as the key is down.
---@param key number
---@return boolean pressed this frame
local function justPressed(key)
    local down = IsRawKeyPressed(key)
    local was = held[key]
    held[key] = down
    return down and not was
end

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

---Cached so the permission round trip happens once, not on every toggle.
---@return boolean
local function mayTune()
    if allowed == nil then
        allowed = lib.callback.await('som-multichar:server:canTuneScene', false) and true or false
    end
    return allowed
end

local function toggle()
    if not Config.Shell.enabled then
        TriggerEvent('som:client:notify', 'Config.Shell.enabled is false, nothing to tune', 'error')
        return
    end

    if not mayTune() then
        TriggerEvent('som:client:notify', 'You do not have permission to do that', 'error')
        return
    end

    active = not active
    TriggerEvent('som:client:notify',
        active and 'Scene tuning ON. Numpad 8/2/4/6 move, 7/9 height, 1/3 rotate, 5 target, 0 print.'
                or 'Scene tuning OFF',
        active and 'success' or 'info')
end

CreateThread(function()
    while true do
        -- Poll at a low rate when idle. This is the only always-running loop in
        -- the resource, so it stays cheap when nobody is tuning.
        Wait(active and 0 or 150)

        if justPressed(KEY.F10) then toggle() end
        if justPressed(KEY.F11) then printCoords() end

        if active then
            if justPressed(KEY.NUM4) then nudge(-step, 0.0, 0.0) end
            if justPressed(KEY.NUM6) then nudge(step, 0.0, 0.0) end
            if justPressed(KEY.NUM8) then nudge(0.0, step, 0.0) end
            if justPressed(KEY.NUM2) then nudge(0.0, -step, 0.0) end
            if justPressed(KEY.NUM7) then nudge(0.0, 0.0, step) end
            if justPressed(KEY.NUM9) then nudge(0.0, 0.0, -step) end

            if justPressed(KEY.NUM1) then
                Config.Shell.pedHeading = (Config.Shell.pedHeading - 15.0) % 360.0
                TriggerEvent('som-multichar:client:rebuildScene')
            end
            if justPressed(KEY.NUM3) then
                Config.Shell.pedHeading = (Config.Shell.pedHeading + 15.0) % 360.0
                TriggerEvent('som-multichar:client:rebuildScene')
            end

            if justPressed(KEY.NUM5) then
                target = target == 'cam' and 'look' or (target == 'look' and 'ped' or 'cam')
                TriggerEvent('som:client:notify', ('Moving: %s'):format(target), 'info')
            end

            if justPressed(KEY.NUM0) then dump() end

            SetTextFont(4)
            SetTextScale(0.34, 0.34)
            SetTextColour(255, 20, 147, 255)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(
                ('SCENE TUNING   moving: %s   step %.2f'):format(target, step))
            EndTextCommandDisplayText(0.015, 0.94)
        end
    end
end)
