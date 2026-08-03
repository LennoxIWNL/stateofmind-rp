-- Staff permissions. Every check reads ACE, never a value sent by a client.
-- Grant in server.cfg with: add_ace group.admin som.admin allow

Permissions = {}

local hierarchy = Config.Permissions.hierarchy

---Returns true if the player holds the given ACE, or anything above it.
---@param source number
---@param ace string
---@return boolean
function Permissions.Has(source, ace)
    local id = tonumber(source)
    if not id or id <= 0 then return false end
    if type(ace) ~= 'string' then return false end

    -- The server native expects the player id as a string. Passing a number
    -- happens to work in some builds and silently fails in others, so be
    -- explicit rather than relying on coercion.
    local src = tostring(id)

    if IsPlayerAceAllowed(src, ace) then return true end

    -- A higher tier implies every tier below it.
    for i = 1, #hierarchy do
        local tier = hierarchy[i]
        if tier == ace then break end
        if IsPlayerAceAllowed(src, tier) then return true end
    end

    return false
end

---Prints what the server actually thinks this player is allowed.
---A denial is otherwise indistinguishable from a broken call.
---@param source number
function Permissions.Debug(source)
    local src = tostring(source)
    print(('^5[som-core]^7 ACE report for %s (%s):'):format(GetPlayerName(source) or '?', src))

    for _, ace in ipairs({ 'som.god', 'som.admin', 'som.mod', 'command' }) do
        print(('    %-12s %s'):format(ace, IsPlayerAceAllowed(src, ace) and 'ALLOW' or 'deny'))
    end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        print(('    identifier   %s'):format(GetPlayerIdentifier(source, i)))
    end
end

exports('debugPermissions', Permissions.Debug)

---Reports whether the permissions block in server.cfg took effect at all.
---
---A player being denied som.god has two very different causes that look
---identical from the player's side: the ACE lines never ran, or they ran but
---the player is not in the group. Checking the GROUP rather than the player
---separates them, because group.god holding som.god does not depend on any
---identifier being correct.
---Applies the ACE structure and the owner grants.
---
---This exists because server.cfg is gitignored: its ACE block cannot be
---version controlled, cannot be deployed with a push, and on the VPS it never
---took effect at all. Owning the grants here makes them travel with the repo
---and behave identically on every machine.
---
---Re-applying an existing ACE is a no-op, so this is safe every start.
local function bootstrap()
    if not Config.Permissions.bootstrap then return end

    local commands = {
        -- Inheritance. god implies admin implies mod.
        'add_principal group.god group.admin',
        'add_principal group.admin group.mod',

        'add_ace group.god som.god allow',
        'add_ace group.god som.admin allow',
        'add_ace group.god som.mod allow',
        'add_ace group.god command allow',

        'add_ace group.admin som.admin allow',
        'add_ace group.admin som.mod allow',
        'add_ace group.admin command allow',

        'add_ace group.mod som.mod allow',
    }

    for identifier, group in pairs(Config.Permissions.owners or {}) do
        commands[#commands + 1] = ('add_principal identifier.%s %s'):format(identifier, group)

        -- Granted straight to the identifier as well as through the group, so
        -- access survives a mistake in the group wiring.
        commands[#commands + 1] = ('add_ace identifier.%s som.god allow'):format(identifier)
        commands[#commands + 1] = ('add_ace identifier.%s command allow'):format(identifier)
    end

    for i = 1, #commands do
        ExecuteCommand(commands[i])
    end
end

CreateThread(function()
    bootstrap()

    -- ExecuteCommand queues, so give the console a moment to drain before
    -- asking whether any of it landed.
    Wait(1000)

    -- Which server.cfg is actually loaded.
    --
    -- Everything about this problem hinges on that question and nothing so far
    -- has answered it. The marker is set by a `sets` line in server.cfg, so if
    -- it reads MISSING the file being executed is not the file being edited,
    -- and no amount of correcting that file will ever change anything.
    local marker = GetConvar('som_cfg_marker', 'MISSING')

    -- Two checks, because they fail for different reasons. A group principal
    -- resolving through an inherited ACE is a different question from a direct
    -- grant on a leaf principal, and only the second proves ACE writes work.
    local viaGroup = IsPrincipalAceAllowed('group.god', 'som.god')

    local viaIdentifier = false
    for identifier in pairs(Config.Permissions.owners or {}) do
        if IsPrincipalAceAllowed('identifier.' .. identifier, 'som.god') then
            viaIdentifier = true
            break
        end
    end

    print(('^5[som-core]^7 permissions: cfg marker %s | group.god=%s | owner identifier=%s')
        :format(marker, tostring(viaGroup), tostring(viaIdentifier)))

    if viaGroup or viaIdentifier then
        print('^2[som-core]^7 permissions applied.')
        return
    end

    print('^1[som-core] PERMISSIONS FAILED.^7 Neither route resolved.')

    if marker == 'MISSING' then
        print('           The cfg marker is MISSING, so the server.cfg being executed is')
        print('           NOT the one in this repo. That explains everything: the ACE')
        print('           block never ran, and `add_ace resource.som-core command allow`')
        print('           never ran either, which is why som-core cannot apply ACEs')
        print('           itself. Find the file txAdmin actually loads and fix that one.')
    else
        print('           The cfg IS the right file, so ACE writes are being rejected at')
        print('           runtime. som-core needs `add_ace resource.som-core command allow`')
        print('           to grant ACEs via ExecuteCommand; check that line survived.')
    end
end)

---@param source number
---@return string|nil highest ACE tier held, or nil
function Permissions.GetTier(source)
    -- String, for the same reason as Permissions.Has. This was passing a number
    -- and silently reporting no tier at all.
    local src = tostring(source)

    for i = 1, #hierarchy do
        if IsPlayerAceAllowed(src, hierarchy[i]) then return hierarchy[i] end
    end
    return nil
end

---Guard for admin actions. Logs the attempt when it fails so denied calls are
---visible rather than silent.
---@param source number
---@param ace string
---@param action string
---@return boolean
function Permissions.Guard(source, ace, action)
    if Permissions.Has(source, ace) then return true end

    print(('[som-core] permission denied: %s (%s) attempted %s without %s')
        :format(GetPlayerName(source) or 'unknown', source, action, ace))
    return false
end

exports('hasPermission', function(source, ace)
    return Permissions.Has(source, ace)
end)

exports('getPermissionTier', function(source)
    return Permissions.GetTier(source)
end)
