StandaloneFramework = {}

function StandaloneFramework.getPlayerName(src)
    return GetPlayerName(src) or 'Unknown'
end

function StandaloneFramework.getPlayerIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then return id end
    end
    return identifiers[1] or 'unknown'
end

function StandaloneFramework.isAdmin(src)
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        for _, adminId in ipairs(Config.AdminIdentifiers) do
            if id == adminId then return true end
        end
    end

    return false
end

function StandaloneFramework.getJobs()
    return {}
end

function StandaloneFramework.getGangs()
    return {}
end

function StandaloneFramework.getName()
    return 'standalone'
end
