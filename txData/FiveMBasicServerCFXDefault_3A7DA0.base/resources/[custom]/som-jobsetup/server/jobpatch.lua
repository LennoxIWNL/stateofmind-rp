local function isAllowed(src)
    return IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, 'command')
end

local function splitLines(s)
    local t = {}
    for line in (s .. '\n'):gmatch('(.-)\n') do t[#t + 1] = line end
    return t
end

local function num(n) return (('%.2f'):format(n + 0.0)):gsub('%.00$', '.0') end

local function makeVec(arity, x, y, z, h)
    if arity == 4 then
        return ('vector4(%s, %s, %s, %s)'):format(num(x), num(y), num(z), num(h or 0.0))
    end
    return ('vector3(%s, %s, %s)'):format(num(x), num(y), num(z))
end

local function parseLocations(content, wantedTypes)
    local out = {}
    local inLoc, curType = false, nil
    for _, l in ipairs(splitLines(content)) do
        if not inLoc then
            if l:match('Config%.Locations%s*=%s*{') then inLoc = true end
        else
            if l:match('^}') then break end
            local t = l:match('%[%s*"([%w_]+)"%s*%]%s*=%s*{')
            if t then curType = t end
            if curType and (not wantedTypes or wantedTypes[curType]) then
                local idx = l:match('^%s*%[%s*(%d+)%s*%]%s*=')
                local vec = l:match('vector%d(%b())')
                if idx and vec then
                    out[#out + 1] = { type = curType, index = tonumber(idx),
                                      coords = vec:sub(2, -2):gsub('%s+', '') }
                end
            end
        end
    end
    return out
end

local function patchLocation(content, locType, index, arity, nested, x, y, z, h)
    local lines = splitLines(content)
    local inLoc, curType, typeCloseLine = false, nil, nil
    for i, l in ipairs(lines) do
        if not inLoc then
            if l:match('Config%.Locations%s*=%s*{') then inLoc = true end
        else
            if l:match('^}') then break end
            local t = l:match('%[%s*"([%w_]+)"%s*%]%s*=%s*{')
            if t then curType = t end
            if curType == locType then
                if typeCloseLine == nil and l:match('^%s*},?%s*$') and not l:match('"') then
                    typeCloseLine = i
                end
                local idx = l:match('^%s*%[%s*(%d+)%s*%]%s*=')
                if idx and tonumber(idx) == index then
                    local newLine, n = l:gsub('vector%d%b()', makeVec(arity, x, y, z, h), 1)
                    if n == 0 then return nil, 'no vector found on that line' end
                    lines[i] = newLine
                    return table.concat(lines, '\n') .. '\n'
                end
            end
        end
    end
    if typeCloseLine and not nested then
        local entry = ('        [%d] = %s,'):format(index, makeVec(arity, x, y, z, h))
        table.insert(lines, typeCloseLine, entry)
        return table.concat(lines, '\n') .. '\n'
    elseif typeCloseLine and nested then
        return nil, ('index %d does not exist for "%s" (nested types are replace-only, pick an existing bed)'):format(index, locType)
    end
    return nil, ('location type "%s" not found in config'):format(locType)
end

RegisterNetEvent('som-jobsetup:server:getJobLocations', function(resource)
    local src = source
    if not isAllowed(src) then return end
    local jc = Config.JobConfigs[resource]
    if not jc then return end
    local content = LoadResourceFile(resource, jc.file)
    if not content then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
            description = ('Could not read %s/%s'):format(resource, jc.file), type = 'error' })
        return
    end
    local wanted = {}
    for k in pairs(jc.locations) do wanted[k] = true end
    TriggerClientEvent('som-jobsetup:client:jobLocations', src, resource, parseLocations(content, wanted))
end)

RegisterNetEvent('som-jobsetup:server:patchJobLocation', function(data)
    local src = source
    if not isAllowed(src) then return end
    if type(data) ~= 'table' then return end
    local jc = Config.JobConfigs[data.resource]
    if not jc then return end
    local locDef = jc.locations[data.locType]
    if not locDef then return end

    local content = LoadResourceFile(data.resource, jc.file)
    if not content then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
            description = 'Could not read the job config', type = 'error' })
        return
    end

    local stamp = os.date('%Y%m%d-%H%M%S')
    SaveResourceFile(GetCurrentResourceName(),
        ('data/backups/%s-%s.lua'):format(data.resource, stamp), content, -1)

    local newContent, err = patchLocation(content, data.locType, tonumber(data.index),
        locDef.arity, locDef.nested, data.x, data.y, data.z, data.h)
    if not newContent then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
            description = 'Patch aborted: ' .. tostring(err), type = 'error' })
        return
    end

    local ok = SaveResourceFile(data.resource, jc.file, newContent, -1)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
            description = 'Failed to write the job config (file permissions?)', type = 'error' })
        return
    end

    TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
        description = ('Wrote %s[%s][%d]. Backup saved.'):format(data.resource, data.locType, data.index),
        type = 'success' })

    if data.restart then
        SetTimeout(400, function()
            ExecuteCommand('ensure ' .. data.resource)
            ExecuteCommand('restart ' .. data.resource)
            TriggerClientEvent('ox_lib:notify', src, { title = 'Job Setup',
                description = ('Restarted %s, change is live.'):format(data.resource), type = 'inform' })
        end)
    end
end)
