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
CreateThread(function()
    -- After the cfg has finished executing.
    Wait(3000)

    local aces = IsPrincipalAceAllowed('group.god', 'som.god')

    if aces then
        print('^2[som-core]^7 permissions: server.cfg ACE block is active.')
        print('           If a player still shows deny, their identifier is not in group.god.')
        return
    end

    print('^1[som-core] PERMISSIONS NOT APPLIED.^7 group.god does not hold som.god, which')
    print('           means the ACE block in server.cfg never executed. Everything after')
    print('           the point it stopped is missing too, not just permissions.')
    print('           Common causes: the cfg is not the one being loaded, or a line above')
    print('           the block aborted execution. Check the console for errors during')
    print('           startup, above the first resource start.')
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
