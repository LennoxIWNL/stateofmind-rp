-- Staff permissions. Every check reads ACE, never a value sent by a client.
-- Grant in server.cfg with: add_ace group.admin som.admin allow

Permissions = {}

local hierarchy = Config.Permissions.hierarchy

---Returns true if the player holds the given ACE, or anything above it.
---@param source number
---@param ace string
---@return boolean
function Permissions.Has(source, ace)
    if type(source) ~= 'number' or source <= 0 then return false end
    if type(ace) ~= 'string' then return false end

    if IsPlayerAceAllowed(source, ace) then return true end

    -- A higher tier implies every tier below it.
    for i = 1, #hierarchy do
        local tier = hierarchy[i]
        if tier == ace then break end
        if IsPlayerAceAllowed(source, tier) then return true end
    end

    return false
end

---@param source number
---@return string|nil highest ACE tier held, or nil
function Permissions.GetTier(source)
    for i = 1, #hierarchy do
        if IsPlayerAceAllowed(source, hierarchy[i]) then return hierarchy[i] end
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
