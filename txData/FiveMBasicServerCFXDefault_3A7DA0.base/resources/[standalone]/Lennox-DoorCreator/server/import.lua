ImportManager = {}

function ImportManager.getOxDoors()
    local rows = MySQL.query.await('SELECT id, name, data FROM ox_doorlock ORDER BY id ASC')
    local doors = {}
    for _, row in ipairs(rows or {}) do
        local data = json.decode(row.data or '{}')
        doors[#doors + 1] = {
            id = row.id,
            name = row.name,
            model = data.model,
            coords = data.coords,
            heading = data.heading,
            doors = data.doors,
            groups = data.groups,
            characters = data.characters,
            items = data.items,
            state = data.state,
            lockpick = data.lockpick,
            autolock = data.autolock,
            maxDistance = data.maxDistance,
            doorRate = data.doorRate,
            lockSound = data.lockSound,
            unlockSound = data.unlockSound,
            hideUi = data.hideUi,
            holdOpen = data.holdOpen,
            passcode = data.passcode,
            lockpickDifficulty = data.lockpickDifficulty,
        }
    end
    return doors
end

function ImportManager.parseQBDoorlock(configContent)
    local doors = {}
    if not configContent or configContent == '' then
        return doors, 'Empty config content'
    end

    local patterns = {
        { key = 'objName', pat = 'objName%s*=%s*["\'](.-)["\'%]]' },
        { key = 'objHash', pat = 'objHash%s*=%s*([%-]?%d+)' },
        { key = 'objHeading', pat = 'objHeading%s*=%s*([%-]?%d+%.?%d*)' },
        { key = 'locked', pat = 'locked%s*=%s*(true)' },
        { key = 'pickable', pat = 'pickable%s*=%s*(true)' },
        { key = 'distance', pat = 'distance%s*=%s*(%d+%.?%d*)' },
    }

    local coordPat = 'objCoords%s*=%s*vector3%(([%-]?%d+%.?%d*),%s*([%-]?%d+%.?%d*),%s*([%-]?%d+%.?%d*)%)'

    local idx = 1
    for block in configContent:gmatch('%[(["\'].-)%]%s*=%s*(%b{})') do
        -- This is a simplified parser; full QB config parsing is complex
    end

    for block in configContent:gmatch('{(.-)}') do
        local door = { valid = true, warnings = {} }

        for _, p in ipairs(patterns) do
            local val = block:match(p.pat)
            if val then door[p.key] = val end
        end

        local cx, cy, cz = block:match(coordPat)
        if cx and cy and cz then
            door.coords = { x = tonumber(cx), y = tonumber(cy), z = tonumber(cz) }
        end

        if door.objHash or door.coords then
            local model = door.objHash and tonumber(door.objHash) or nil
            local heading = door.objHeading and tonumber(door.objHeading) or 0.0
            local state = door.locked == 'true' and 1 or 0

            local oxData = {
                model = model,
                coords = door.coords or { x = 0, y = 0, z = 0 },
                heading = heading,
                state = state,
                lockpick = door.pickable == 'true',
                maxDistance = door.distance and tonumber(door.distance) or Config.DefaultMaxDistance,
                auto = false,
                autolock = 0,
                doors = json.null,
                characters = {},
                groups = {},
                items = {},
                hideUi = false,
                holdOpen = false,
                lockSound = Config.DefaultLockSound,
                unlockSound = Config.DefaultUnlockSound,
                doorRate = Config.DefaultDoorRate,
                passcode = json.null,
                lockpickDifficulty = json.null,
            }

            local groups = {}
            for job in block:gmatch('authorizedJobs%s*=%s*{(.-)}') do
                for k in job:gmatch('["\'](.-)["\'%]]') do
                    groups[k] = 0
                end
            end
            for gang in block:gmatch('authorizedGangs%s*=%s*{(.-)}') do
                for k in gang:gmatch('["\'](.-)["\'%]]') do
                    groups[k] = 0
                end
            end
            if next(groups) then oxData.groups = groups end

            local chars = {}
            for cids in block:gmatch('authorizedCitizenIDs%s*=%s*{(.-)}') do
                for cid in cids:gmatch('["\'](.-)["\'%]]') do
                    chars[#chars + 1] = cid
                end
            end
            if #chars > 0 then oxData.characters = chars end

            if not model then
                door.valid = false
                door.warnings[#door.warnings + 1] = 'Missing model hash'
            end
            if not door.coords then
                door.valid = false
                door.warnings[#door.warnings + 1] = 'Missing coordinates'
            end

            doors[#doors + 1] = {
                name = door.objName or ('QB Import ' .. idx),
                data = oxData,
                valid = door.valid,
                warnings = door.warnings,
                source = 'qb-doorlock',
            }
            idx = idx + 1
        end
    end

    return doors, nil
end

function ImportManager.parseNuiDoorlock(configContent)
    -- nui_doorlock has a similar format to qb-doorlock
    return ImportManager.parseQBDoorlock(configContent)
end

function ImportManager.parseCustomJSON(jsonContent)
    local doors = {}
    local ok, parsed = pcall(json.decode, jsonContent)
    if not ok or type(parsed) ~= 'table' then
        return doors, 'Invalid JSON'
    end

    local list = parsed
    if not parsed[1] and parsed.doors then
        list = parsed.doors
    end

    for i, entry in ipairs(list) do
        local valid = true
        local warnings = {}

        local oxData = {
            model = entry.model or entry.objHash or entry.hash,
            coords = entry.coords or { x = entry.x or 0, y = entry.y or 0, z = entry.z or 0 },
            heading = entry.heading or entry.objHeading or 0.0,
            state = entry.state or entry.locked and 1 or Config.DefaultLockState,
            auto = entry.auto or false,
            autolock = entry.autolock or 0,
            doors = entry.doors or json.null,
            characters = entry.characters or {},
            groups = entry.groups or {},
            items = entry.items or {},
            lockpick = entry.lockpick or false,
            hideUi = entry.hideUi or false,
            holdOpen = entry.holdOpen or false,
            lockSound = entry.lockSound or Config.DefaultLockSound,
            unlockSound = entry.unlockSound or Config.DefaultUnlockSound,
            maxDistance = entry.maxDistance or Config.DefaultMaxDistance,
            doorRate = entry.doorRate or Config.DefaultDoorRate,
            passcode = entry.passcode or json.null,
            lockpickDifficulty = entry.lockpickDifficulty or json.null,
        }

        if not oxData.model then
            valid = false
            warnings[#warnings + 1] = 'Missing model hash'
        end
        if not oxData.coords or (oxData.coords.x == 0 and oxData.coords.y == 0 and oxData.coords.z == 0) then
            warnings[#warnings + 1] = 'Coordinates may be invalid'
        end

        doors[#doors + 1] = {
            name = entry.name or ('Import ' .. i),
            data = oxData,
            valid = valid,
            warnings = warnings,
            source = 'custom_json',
        }
    end

    return doors, nil
end

function ImportManager.batchInsert(doors, playerName, playerIdentifier)
    local success = 0
    local failed = 0
    local ids = {}

    for _, door in ipairs(doors) do
        if door.valid ~= false then
            local dataStr = json.encode(door.data)
            local id = MySQL.insert.await(
                'INSERT INTO ox_doorlock (name, data) VALUES (?, ?)',
                { door.name, dataStr }
            )
            if id then
                success = success + 1
                ids[#ids + 1] = id
            else
                failed = failed + 1
            end
        else
            failed = failed + 1
        end
    end

    DoorLogger.log(DoorActions.IMPORT, {
        playerName = playerName,
        playerIdentifier = playerIdentifier,
        details = { success = success, failed = failed, source = doors[1] and doors[1].source or 'unknown' },
    })

    return { success = success, failed = failed, ids = ids }
end
