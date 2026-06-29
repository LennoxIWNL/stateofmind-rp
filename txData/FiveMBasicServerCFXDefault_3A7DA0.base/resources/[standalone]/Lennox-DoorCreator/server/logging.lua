DoorLogger = {}

local LOG_TAG = '^5[Lennox-DoorCreator]^7'

function DoorLogger.log(action, data)
    local details = data.details
    if type(details) == 'table' then
        details = json.encode(details)
    end

    MySQL.insert('INSERT INTO lennox_door_logs (action, door_id, building_id, player_name, player_identifier, details) VALUES (?, ?, ?, ?, ?, ?)', {
        action,
        data.doorId,
        data.buildingId,
        data.playerName or 'System',
        data.playerIdentifier or 'system',
        details,
    })

    if Config.Debug then
        print(('%s ^3[LOG]^7 %s by %s'):format(LOG_TAG, action, data.playerName or 'System'))
    end

    if Config.LogToDiscord and Config.DiscordWebhook ~= '' then
        DoorLogger.sendDiscord(action, data)
    end
end

function DoorLogger.sendDiscord(action, data)
    local color = 3447003
    if action:find('delete') then color = 15158332
    elseif action:find('create') then color = 3066993
    elseif action:find('edit') then color = 15844367
    elseif action:find('restore') then color = 10181046
    elseif action:find('import') then color = 1752220 end

    local fields = {
        { name = 'Action', value = action, inline = true },
        { name = 'Player', value = (data.playerName or 'System') .. '\n' .. (data.playerIdentifier or ''), inline = true },
    }

    if data.doorId then
        fields[#fields + 1] = { name = 'Door ID', value = tostring(data.doorId), inline = true }
    end
    if data.buildingId then
        fields[#fields + 1] = { name = 'Building ID', value = tostring(data.buildingId), inline = true }
    end

    local detailStr = ''
    if data.details then
        if type(data.details) == 'table' then
            detailStr = json.encode(data.details)
        else
            detailStr = tostring(data.details)
        end
        if #detailStr > 1000 then
            detailStr = detailStr:sub(1, 997) .. '...'
        end
        fields[#fields + 1] = { name = 'Details', value = '```json\n' .. detailStr .. '\n```', inline = false }
    end

    local embed = {
        title = 'Lennox Door Creator — ' .. action,
        color = color,
        fields = fields,
        footer = { text = 'Lennox Door Creator v1.0.0' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
        username = 'Lennox Door Creator',
        embeds = { embed },
    }), { ['Content-Type'] = 'application/json' })
end

function DoorLogger.cleanup()
    if Config.LogRetention <= 0 then return end
    local deleted = MySQL.update.await(
        'DELETE FROM lennox_door_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        { Config.LogRetention }
    )
    if deleted and deleted > 0 then
        print(('%s ^3Cleaned up %d old log entries^7'):format(LOG_TAG, deleted))
    end
end

function DoorLogger.getLogs(filters)
    local where = {}
    local params = {}

    if filters.action and filters.action ~= '' then
        where[#where + 1] = 'action = ?'
        params[#params + 1] = filters.action
    end
    if filters.doorId then
        where[#where + 1] = 'door_id = ?'
        params[#params + 1] = filters.doorId
    end
    if filters.player and filters.player ~= '' then
        where[#where + 1] = '(player_name LIKE ? OR player_identifier LIKE ?)'
        params[#params + 1] = '%' .. filters.player .. '%'
        params[#params + 1] = '%' .. filters.player .. '%'
    end

    local offset = filters.offset or 0
    local limit = filters.limit or 50

    local whereStr = #where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or ''
    local query = ('SELECT * FROM lennox_door_logs %s ORDER BY created_at DESC LIMIT %d OFFSET %d'):format(whereStr, limit, offset)
    local countQuery = ('SELECT COUNT(*) as total FROM lennox_door_logs %s'):format(whereStr)

    local rows = MySQL.query.await(query, params)
    local countResult = MySQL.scalar.await(countQuery, params)

    return {
        logs = rows or {},
        total = countResult or 0,
        offset = offset,
        limit = limit,
    }
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600000)
        DoorLogger.cleanup()
    end
end)
