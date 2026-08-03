-- Staff permissions. Every check reads ACE, never a value sent by a client.
-- Grant in server.cfg with: add_ace group.admin som.admin allow

Permissions = {}

local hierarchy = Config.Permissions.hierarchy

---Highest tier an owner is granted, by identifier.
---
---ACE is the real mechanism and it DOES resolve now; som-core prints proof of
---that at boot. This is a fallback that costs nothing and covers only the
---handful of people in Config.Permissions.owners, so that whoever owns the
---server can still administer it if ACE ever breaks again.
---
---It was originally written because ACE genuinely did not resolve. That has
---since been fixed by ordering som.cfg correctly. See the note in
---Config.Permissions.
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

---Deliberately UNRESTRICTED, and deliberately self-only.
---
---A permission problem is the one thing an admin command cannot diagnose,
---because if permissions are broken the diagnostic is refused too. So this
---reports on the CALLER and nobody else, which makes it safe to leave open:
---it tells a player their own identifiers and their own access, which they
---could determine anyway.
---
---Run this first when a staff command appears to do nothing. If the license
---printed here is not the one in Config.Permissions.owners, that is the answer.
lib.addCommand('somperms', {
    help = 'Show your own identifiers and staff access',
}, function(source)
    if source == 0 then return end

    Permissions.Debug(source)

    local tier = Permissions.GetTier(source) or 'none'
    TriggerClientEvent('som:client:notify', source,
        ('Access: %s. Identifiers printed to the server console.'):format(tier),
        tier == 'none' and 'error' or 'success', 8000)
end)

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

---Registers a staff command whose permission is checked by Permissions.Has.
---
---lib.addCommand ends with
---
---    RegisterCommand(name, handler, restricted and true)
---
---and that third argument hands enforcement to FiveM, gating the command on the
---`command.<name>` ACE. That works, because ACE resolves here.
---
---This is used anyway, for two reasons. It routes the check through
---Permissions.Has, so the owner-by-identifier fallback applies and staff access
---survives ACE breaking again. And a refusal becomes a message the player can
---see, rather than FiveM silently swallowing the command with no output
---anywhere, which is genuinely hard to tell apart from a broken script.
---
---The command is therefore registered UNRESTRICTED so FiveM lets it through,
---and the permission is checked below. That is safe ONLY because of the guard:
---without it, this would publish /givemoney to the entire server.
---@param name string
---@param props table lib.addCommand properties. `restricted` is ignored.
---@param ace string the ACE tier required, e.g. Config.Permissions.admin
---@param handler fun(source: number, args: table, raw: string)
function Permissions.AddCommand(name, props, ace, handler)
    props = props or {}
    props.restricted = false

    lib.addCommand(name, props, function(source, args, raw)
        -- The console (source 0) is always allowed: it is the server operator
        -- and has no identifier to match against.
        if source ~= 0 and not Permissions.Guard(source, ace, name) then
            TriggerClientEvent('som:client:notify', source,
                'You do not have permission to do that', 'error')
            return
        end

        handler(source, args, raw)
    end)
end

exports('hasPermission', function(source, ace)
    return Permissions.Has(source, ace)
end)

exports('getPermissionTier', function(source)
    return Permissions.GetTier(source)
end)
