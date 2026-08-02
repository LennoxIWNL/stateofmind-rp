-- Live scene tuning.
--
-- Shell models differ in where their floor, walls and furniture sit, so the
-- offsets in config are always wrong on the first attempt. Guessing them from
-- screenshots costs a restart per attempt. This lets a staff member nudge the
-- scene while looking at it and print values to paste back into config.lua.
--
-- Client side only and purely cosmetic: it moves a preview ped and a camera
-- that exist solely on this client. It cannot touch player state, money or
-- anything server owned, so the ACE check here is about keeping the keys out
-- of players' hands, not about protecting anything.
--
-- Set Config.SceneTuning.enabled = false for production.

if not Config.SceneTuning or not Config.SceneTuning.enabled then return end

local active = false
local step = Config.SceneTuning.step or 0.1
local target = 'cam'

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

RegisterCommand('somscene', function()
    if not Config.Shell.enabled then
        print('^3[som-multichar]^7 Config.Shell.enabled is false, nothing to tune.')
        return
    end

    -- The client cannot read ACE, so the server answers.
    if not lib.callback.await('som-multichar:server:canTuneScene', false) then
        TriggerEvent('som:client:notify', 'You do not have permission to do that', 'error')
        return
    end

    active = not active
    TriggerEvent('som:client:notify',
        active and 'Scene tuning ON. Arrows move, PgUp/PgDn height, [ ] rotate, TAB target, ENTER print.'
                or 'Scene tuning OFF', active and 'success' or 'info')
end, false)

CreateThread(function()
    while true do
        if not active then
            Wait(500)
        else
            Wait(0)

            -- Arrow keys move on the ground plane.
            if IsControlJustPressed(0, 174) then nudge(-step, 0.0, 0.0) end  -- left
            if IsControlJustPressed(0, 175) then nudge(step, 0.0, 0.0) end   -- right
            if IsControlJustPressed(0, 172) then nudge(0.0, step, 0.0) end   -- up
            if IsControlJustPressed(0, 173) then nudge(0.0, -step, 0.0) end  -- down

            -- Page up / page down move height.
            if IsControlJustPressed(0, 10) then nudge(0.0, 0.0, step) end
            if IsControlJustPressed(0, 11) then nudge(0.0, 0.0, -step) end

            -- Square brackets rotate the character.
            if IsControlJustPressed(0, 39) then
                Config.Shell.pedHeading = (Config.Shell.pedHeading - 15.0) % 360.0
                TriggerEvent('som-multichar:client:rebuildScene')
            end
            if IsControlJustPressed(0, 40) then
                Config.Shell.pedHeading = (Config.Shell.pedHeading + 15.0) % 360.0
                TriggerEvent('som-multichar:client:rebuildScene')
            end

            -- Tab cycles what the arrows move.
            if IsControlJustPressed(0, 37) then
                target = target == 'cam' and 'look' or (target == 'look' and 'ped' or 'cam')
                TriggerEvent('som:client:notify', ('Moving: %s'):format(target), 'info')
            end

            -- Enter prints the current values.
            if IsControlJustPressed(0, 18) then dump() end

            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('~p~SCENE TUNING~s~  moving: ~p~%s~s~  step %.2f'):format(target, step))
            SetTextScale(0.32, 0.32)
            SetTextFont(4)
            EndTextCommandDisplayText(0.015, 0.94)
        end
    end
end)
