-- Staff permissions. Every check reads ACE, never a value sent by a client.
-- Grant in server.cfg with: add_ace group.admin som.admin allow

Permissions = {}

local hierarchy = Config.Permissions.hierarchy

---Highest tier an owner is granted, by identifier.
---
---ACE is still the mechanism for everyone else. This exists because on this
---server ACE never resolved: the cfg provably executes, the add_ace and
---add_principal lines are present and correct, som-core re-applies them at
---boot as well, and IsPlayerAceAllowed still returns false for an identifier
---that is listed. Several sessions went into that without an explanation.
---
---Rather than keep guessing, ownership is settled by a direct identifier match
---that cannot fail. It is less flexible than ACE and deliberately covers only
---the handful of people in Config.Permissions.owners.
---@param source number
---@return string|nil group
local function ownerGroup(source)
    local owners = Config.Permissions.owners
    if not owners or not next(owners) then return nil end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local group = owners[GetPlayerIdentifier(source, i)]
        if group then return group end
    end

    return nil
end

-- What each group implies, most privileged first.
local GROUP_TIERS = {
    ['group.god']   = { 'som.god', 'som.admin', 'som.mod' },
    ['group.admin'] = { 'som.admin', 'som.mod' },
    ['group.mod']   = { 'som.mod' },
}

---Returns true if the player holds the given ACE, or anything above it.
---@param source number
---@param ace string
---@return boolean
function Permissions.Has(source, ace)
    local id = tonumber(source)
    if not id or id <= 0 then return false end
    if type(ace) ~= 'string' then return false end

    local group = ownerGroup(id)
    if group then
        for _, held in ipairs(GROUP_TIERS[group] or {}) do
            if held == ace then return true end
        end
    end

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

-- ACE grants are NOT applied from here any more.
--
-- som-core used to re-apply them with ExecuteCommand at boot. Every call was
-- refused with "Access denied for command add_ace", because granting an ACE
-- itself requires one, and the `add_ace resource.som-core command allow` line
-- that would have permitted it had not taken effect either. The result was a
-- console full of denials and no permissions.
--
-- The grants live in som.cfg, which now declares them ABOVE the ensure lines.
-- Owners are matched by identifier regardless, so staff access does not depend
-- on any of this resolving.

CreateThread(function()
    -- After the cfg has finished executing.
    Wait(2000)

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

    -- ACE did not resolve. On this server it never has, for reasons that
    -- survived several sessions of diagnosis, so owners fall back to a direct
    -- identifier match and everything below is informational.
    local owners = 0
    for _ in pairs(Config.Permissions.owners or {}) do owners = owners + 1 end

    print('^3[som-core]^7 ACE did not resolve. Owners fall back to identifier matching,')
    print(('           which covers %d configured %s and is unaffected by this.')
        :format(owners, owners == 1 and 'owner' or 'owners'))

    if marker == 'MISSING' then
        print('^1           The cfg marker is MISSING^7, so the file being executed is not')
        print('           the one in this repo. Fix that first; nothing else is reliable')
        print('           until it is.')
    else
        print('           The cfg IS the right file and its ACE lines ran, so anyone who')
        print('           is not a configured owner will have no staff access. Add them')
        print('           to Config.Permissions.owners in som-core/shared/config.lua.')
    end
end)

---@param source number
---@return string|nil highest ACE tier held, or nil
function Permissions.GetTier(source)
    -- Owners first, for the same reason as Permissions.Has.
    local group = ownerGroup(source)
    if group then
        local tiers = GROUP_TIERS[group]
        if tiers and tiers[1] then return tiers[1] end
    end

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
