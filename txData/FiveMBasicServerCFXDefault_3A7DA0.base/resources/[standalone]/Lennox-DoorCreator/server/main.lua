-- =========================================================================
--  Lennox Door Creator — Server Core
-- =========================================================================

local LENNOX_SIG     = 'Lennox'
local LENNOX_VERSION = '1.0.0'
local LENNOX_PRODUCT = 'Door Creator'

local function sigHash(s)
    local h = 0x5A3C
    for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 0x7FFFFFFF end
    return h
end

local MAGIC = sigHash(LENNOX_SIG)
local EXPECTED_MAGIC = sigHash('Le' .. string.char(110, 110, 111, 120))

local BANNER = {
    '^5[Lennox-DoorCreator]^7',
    '^5[Lennox-DoorCreator] ^2 _                                 ^7',
    '^5[Lennox-DoorCreator] ^2/ /  ___  ____  ____  ____  _  __ ^7',
    '^5[Lennox-DoorCreator] ^2/ /  / _ \\/ __ \\/ __ \\/ __ \\| |/_/^7',
    '^5[Lennox-DoorCreator] ^2/ /__/  __/ / / / / / / /_/ />  <  ^7',
    '^5[Lennox-DoorCreator] ^2\\____/\\___/_/ /_/_/ /_/\\____/_/|_| ^7',
    '^5[Lennox-DoorCreator]^7',
    '^5[Lennox-DoorCreator] ^3  D O O R   C R E A T O R   v' .. LENNOX_VERSION .. '^7',
    '^5[Lennox-DoorCreator] ^7  Created by ^2Lennox^7',
    '^5[Lennox-DoorCreator]^7',
}

local function verifyIntegrity()
    if MAGIC ~= EXPECTED_MAGIC then return false end
    local found = false
    for _, line in ipairs(BANNER) do
        if line:find(string.char(76, 101, 110, 110, 111, 120)) then found = true; break end
    end
    if not found then return false end
    return true
end

-- =========================================================================
--  Framework Detection
-- =========================================================================
Framework = nil

local function detectFramework()
    if Config.Framework == 'qb' or (Config.Framework == 'auto' and GetResourceState('qb-core') == 'started') then
        Framework = QBFramework
    elseif Config.Framework == 'esx' or (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
        Framework = ESXFramework
    else
        Framework = StandaloneFramework
    end
    return Framework.getName()
end

-- =========================================================================
--  Rate Limiting
-- =========================================================================
local rateLimits = {}

local function checkRateLimit(src, action, maxPerMinute, cooldownMs)
    local key = src .. ':' .. action
    local now = GetGameTimer()
    if not rateLimits[key] then rateLimits[key] = { count = 0, reset = now + 60000, lastAction = 0 } end
    local rl = rateLimits[key]

    if now > rl.reset then
        rl.count = 0
        rl.reset = now + 60000
    end

    if cooldownMs and (now - rl.lastAction) < cooldownMs then
        return false, 'Please wait before performing this action again.'
    end

    rl.count = rl.count + 1
    rl.lastAction = now

    if rl.count > maxPerMinute then
        return false, 'Rate limit exceeded. Please slow down.'
    end

    return true
end

-- =========================================================================
--  Validation
-- =========================================================================
local function validateCoords(coords)
    if type(coords) ~= 'table' then return false end
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return false end
    if coords.x < MAP_BOUNDS.min.x or coords.x > MAP_BOUNDS.max.x then return false end
    if coords.y < MAP_BOUNDS.min.y or coords.y > MAP_BOUNDS.max.y then return false end
    if coords.z < MAP_BOUNDS.min.z or coords.z > MAP_BOUNDS.max.z then return false end
    return true
end

local function validateDoorData(data)
    if type(data) ~= 'table' then return false, 'Invalid data' end
    if type(data.name) ~= 'string' or #data.name == 0 then return false, 'Name is required' end
    if #data.name > 50 then return false, 'Name must be 50 characters or less' end
    if not data.model or type(data.model) ~= 'number' then return false, 'Invalid model hash' end
    if not validateCoords(data.coords) then return false, 'Invalid coordinates' end
    if data.heading and type(data.heading) ~= 'number' then return false, 'Invalid heading' end

    if data.groups and type(data.groups) == 'table' then
        for k, v in pairs(data.groups) do
            if type(k) ~= 'string' or type(v) ~= 'number' then
                return false, 'Invalid group format'
            end
        end
    end

    if data.characters and type(data.characters) == 'table' then
        for _, v in ipairs(data.characters) do
            if type(v) ~= 'string' then return false, 'Invalid character format' end
        end
    end

    if data.items and type(data.items) == 'table' then
        for _, v in ipairs(data.items) do
            if type(v) ~= 'string' then return false, 'Invalid item format' end
        end
    end

    return true
end

local function buildOxData(data)
    return {
        auto = data.auto or false,
        autolock = data.autolock or 0,
        coords = data.coords,
        heading = data.heading or 0.0,
        model = data.model,
        doors = data.doors or json.null,
        characters = data.characters or {},
        groups = data.groups or {},
        items = data.items or {},
        lockpick = data.lockpick or false,
        hideUi = data.hideUi or false,
        holdOpen = data.holdOpen or false,
        lockSound = data.lockSound or Config.DefaultLockSound,
        unlockSound = data.unlockSound or Config.DefaultUnlockSound,
        maxDistance = data.maxDistance or Config.DefaultMaxDistance,
        doorRate = data.doorRate or Config.DefaultDoorRate,
        state = data.state ~= nil and data.state or Config.DefaultLockState,
        passcode = data.passcode or json.null,
        lockpickDifficulty = data.lockpickDifficulty or json.null,
    }
end

-- =========================================================================
--  Door Cache
-- =========================================================================
local doorCache = {}
local buildingCache = {}

local function refreshDoorCache()
    local rows = MySQL.query.await('SELECT id, name, data FROM ox_doorlock ORDER BY id ASC')
    doorCache = {}
    for _, row in ipairs(rows or {}) do
        doorCache[row.id] = {
            id = row.id,
            name = row.name,
            data = json.decode(row.data or '{}'),
        }
    end
end

local function refreshBuildingCache()
    local rows = MySQL.query.await('SELECT * FROM lennox_buildings ORDER BY id ASC')
    buildingCache = {}
    for _, row in ipairs(rows or {}) do
        buildingCache[row.id] = {
            id = row.id,
            name = row.name,
            description = row.description,
            doors = json.decode(row.doors or '[]'),
            permissions = json.decode(row.permissions or '{}'),
            metadata = json.decode(row.metadata or '{}'),
            createdBy = row.created_by,
            createdAt = row.created_at,
            updatedAt = row.updated_at,
        }
    end
end

local function getDoorList()
    local list = {}
    for _, door in pairs(doorCache) do
        list[#list + 1] = {
            id = door.id,
            name = door.name,
            model = door.data.model,
            coords = door.data.coords,
            heading = door.data.heading,
            state = door.data.state,
            groups = door.data.groups,
            isDoor = door.data.doors ~= nil and door.data.doors ~= json.null,
            category = door.data.model and DoorCategories[door.data.model] or 'unknown',
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function getBuildingList()
    local list = {}
    for _, b in pairs(buildingCache) do
        list[#list + 1] = b
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- =========================================================================
--  Callbacks (NUI → Client → Server)
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:getData', function(source)
    if not Framework.isAdmin(source) then return nil end
    return {
        doors = getDoorList(),
        buildings = getBuildingList(),
        jobs = Framework.getJobs(),
        gangs = Framework.getGangs(),
        theme = Config.ThemeColor,
        framework = Framework.getName(),
    }
end)

lib.callback.register('lennox-doorcreator:server:getDoor', function(source, doorId)
    if not Framework.isAdmin(source) then return nil end
    local door = doorCache[doorId]
    if not door then return nil end
    return { id = door.id, name = door.name, data = door.data }
end)

lib.callback.register('lennox-doorcreator:server:createDoor', function(source, data)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local allowed, msg = checkRateLimit(source, 'create', 10, nil)
    if not allowed then return { ok = false, message = msg } end

    local valid, err = validateDoorData(data)
    if not valid then return { ok = false, message = err } end

    local oxData = buildOxData(data)
    local dataStr = json.encode(oxData)

    local id = MySQL.insert.await('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)', { data.name, dataStr })
    if not id then return { ok = false, message = 'Database error' } end

    doorCache[id] = { id = id, name = data.name, data = oxData }

    pcall(function()
        exports.ox_doorlock:editDoor(id, oxData)
    end)

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.CREATE, {
        doorId = id,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = data.name, model = data.model, coords = data.coords },
    })

    return { ok = true, id = id, message = ('Door #%d created successfully'):format(id) }
end)

lib.callback.register('lennox-doorcreator:server:editDoor', function(source, doorId, data)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local allowed, msg = checkRateLimit(source, 'edit', 20, nil)
    if not allowed then return { ok = false, message = msg } end

    if not doorCache[doorId] then return { ok = false, message = 'Door not found' } end

    local valid, err = validateDoorData(data)
    if not valid then return { ok = false, message = err } end

    local oxData = buildOxData(data)
    local dataStr = json.encode(oxData)

    MySQL.update.await('UPDATE ox_doorlock SET name = ?, data = ? WHERE id = ?', { data.name, dataStr, doorId })

    local oldData = doorCache[doorId].data
    doorCache[doorId] = { id = doorId, name = data.name, data = oxData }

    pcall(function()
        exports.ox_doorlock:editDoor(doorId, oxData)
    end)

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.EDIT, {
        doorId = doorId,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = data.name, before = oldData, after = oxData },
    })

    return { ok = true, message = ('Door #%d updated'):format(doorId) }
end)

lib.callback.register('lennox-doorcreator:server:deleteDoor', function(source, doorId)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    if not doorCache[doorId] then return { ok = false, message = 'Door not found' } end

    local oldDoor = doorCache[doorId]
    MySQL.update.await('DELETE FROM ox_doorlock WHERE id = ?', { doorId })
    doorCache[doorId] = nil

    for _, b in pairs(buildingCache) do
        for i = #b.doors, 1, -1 do
            if b.doors[i] == doorId then
                table.remove(b.doors, i)
                MySQL.update.await('UPDATE lennox_buildings SET doors = ? WHERE id = ?', { json.encode(b.doors), b.id })
                break
            end
        end
    end

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.DELETE, {
        doorId = doorId,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = oldDoor.name, model = oldDoor.data.model },
    })

    return { ok = true, message = ('Door #%d deleted'):format(doorId) }
end)

lib.callback.register('lennox-doorcreator:server:bulkCreate', function(source, doorsData, sharedSettings)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local allowed, msg = checkRateLimit(source, 'bulk', 2, 30000)
    if not allowed then return { ok = false, message = msg } end

    if type(doorsData) ~= 'table' or #doorsData == 0 then
        return { ok = false, message = 'No doors provided' }
    end
    if #doorsData > Config.MaxBulkDoors then
        return { ok = false, message = ('Maximum %d doors per bulk operation'):format(Config.MaxBulkDoors) }
    end

    local success = 0
    local failed = 0
    local ids = {}

    for i, door in ipairs(doorsData) do
        local merged = {}
        for k, v in pairs(sharedSettings or {}) do merged[k] = v end
        for k, v in pairs(door) do merged[k] = v end

        if not merged.name or merged.name == '' then
            merged.name = ('%s %d'):format(Config.AutoNamePrefix, i)
        end

        local valid = validateDoorData(merged)
        if valid then
            local oxData = buildOxData(merged)
            local dataStr = json.encode(oxData)
            local id = MySQL.insert.await('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)', { merged.name, dataStr })
            if id then
                doorCache[id] = { id = id, name = merged.name, data = oxData }
                success = success + 1
                ids[#ids + 1] = id
                pcall(function() exports.ox_doorlock:editDoor(id, oxData) end)
            else
                failed = failed + 1
            end
        else
            failed = failed + 1
        end
    end

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.BULK_CREATE, {
        playerName = playerName,
        playerIdentifier = playerId,
        details = { success = success, failed = failed, total = #doorsData },
    })

    return { ok = true, success = success, failed = failed, ids = ids, message = ('%d doors created, %d failed'):format(success, failed) }
end)

-- =========================================================================
--  Building Callbacks
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:createBuilding', function(source, data)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    if type(data.name) ~= 'string' or #data.name == 0 or #data.name > 100 then
        return { ok = false, message = 'Invalid building name' }
    end

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    local id = MySQL.insert.await(
        'INSERT INTO lennox_buildings (name, description, doors, permissions, metadata, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        { data.name, data.description or '', json.encode(data.doors or {}), json.encode(data.permissions or {}), json.encode(data.metadata or {}), playerName }
    )

    buildingCache[id] = {
        id = id,
        name = data.name,
        description = data.description or '',
        doors = data.doors or {},
        permissions = data.permissions or {},
        metadata = data.metadata or {},
        createdBy = playerName,
    }

    DoorLogger.log(DoorActions.BUILDING_CREATE, {
        buildingId = id,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = data.name },
    })

    return { ok = true, id = id, message = ('Building "%s" created'):format(data.name) }
end)

lib.callback.register('lennox-doorcreator:server:editBuilding', function(source, buildingId, data)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    if not buildingCache[buildingId] then return { ok = false, message = 'Building not found' } end

    MySQL.update.await(
        'UPDATE lennox_buildings SET name = ?, description = ?, doors = ?, permissions = ?, metadata = ? WHERE id = ?',
        { data.name, data.description or '', json.encode(data.doors or {}), json.encode(data.permissions or {}), json.encode(data.metadata or {}), buildingId }
    )

    buildingCache[buildingId] = {
        id = buildingId,
        name = data.name,
        description = data.description or '',
        doors = data.doors or {},
        permissions = data.permissions or {},
        metadata = data.metadata or {},
        createdBy = buildingCache[buildingId].createdBy,
    }

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.BUILDING_EDIT, {
        buildingId = buildingId,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = data.name },
    })

    return { ok = true, message = ('Building "%s" updated'):format(data.name) }
end)

lib.callback.register('lennox-doorcreator:server:deleteBuilding', function(source, buildingId, deleteDoors)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local building = buildingCache[buildingId]
    if not building then return { ok = false, message = 'Building not found' } end

    if deleteDoors and building.doors then
        for _, doorId in ipairs(building.doors) do
            MySQL.update.await('DELETE FROM ox_doorlock WHERE id = ?', { doorId })
            doorCache[doorId] = nil
        end
    end

    MySQL.update.await('DELETE FROM lennox_buildings WHERE id = ?', { buildingId })
    buildingCache[buildingId] = nil

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.BUILDING_DELETE, {
        buildingId = buildingId,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { name = building.name, deletedDoors = deleteDoors },
    })

    return { ok = true, message = ('Building "%s" deleted'):format(building.name) }
end)

lib.callback.register('lennox-doorcreator:server:applyBuildingPerms', function(source, buildingId, permissions)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local building = buildingCache[buildingId]
    if not building then return { ok = false, message = 'Building not found' } end

    local updated = 0
    for _, doorId in ipairs(building.doors) do
        local door = doorCache[doorId]
        if door then
            if permissions.groups then door.data.groups = permissions.groups end
            if permissions.characters then door.data.characters = permissions.characters end
            if permissions.items then door.data.items = permissions.items end
            if permissions.lockpick ~= nil then door.data.lockpick = permissions.lockpick end
            if permissions.passcode ~= nil then door.data.passcode = permissions.passcode end

            local dataStr = json.encode(door.data)
            MySQL.update.await('UPDATE ox_doorlock SET data = ? WHERE id = ?', { dataStr, doorId })
            pcall(function() exports.ox_doorlock:editDoor(doorId, door.data) end)
            updated = updated + 1
        end
    end

    building.permissions = permissions
    MySQL.update.await('UPDATE lennox_buildings SET permissions = ? WHERE id = ?', { json.encode(permissions), buildingId })

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    DoorLogger.log(DoorActions.PERM_CHANGE, {
        buildingId = buildingId,
        playerName = playerName,
        playerIdentifier = playerId,
        details = { doorsUpdated = updated, permissions = permissions },
    })

    return { ok = true, message = ('%d doors updated with new permissions'):format(updated) }
end)

-- =========================================================================
--  Template Callbacks
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:getTemplates', function(source)
    if not Framework.isAdmin(source) then return {} end
    return TemplateManager.getAll()
end)

lib.callback.register('lennox-doorcreator:server:createTemplate', function(source, data)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end
    data.author = Framework.getPlayerName(source)
    local result = TemplateManager.create(data)

    DoorLogger.log(DoorActions.TEMPLATE_CREATE, {
        playerName = data.author,
        playerIdentifier = Framework.getPlayerIdentifier(source),
        details = { name = data.name, id = result.id },
    })

    return { ok = true, id = result.id, exportCode = result.exportCode }
end)

lib.callback.register('lennox-doorcreator:server:getTemplate', function(source, id)
    if not Framework.isAdmin(source) then return nil end
    return TemplateManager.getById(id)
end)

lib.callback.register('lennox-doorcreator:server:deleteTemplate', function(source, id)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    TemplateManager.delete(id)

    DoorLogger.log(DoorActions.TEMPLATE_DELETE, {
        playerName = Framework.getPlayerName(source),
        playerIdentifier = Framework.getPlayerIdentifier(source),
        details = { templateId = id },
    })

    return { ok = true }
end)

lib.callback.register('lennox-doorcreator:server:exportTemplate', function(source, id)
    if not Framework.isAdmin(source) then return nil end
    return TemplateManager.exportToString(id)
end)

lib.callback.register('lennox-doorcreator:server:importTemplate', function(source, importStr)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end
    local result, err = TemplateManager.importFromString(importStr)
    if not result then return { ok = false, message = err } end
    return { ok = true, id = result.id, name = result.name }
end)

-- =========================================================================
--  Import Callbacks
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:importPreview', function(source, importSource, content)
    if not Framework.isAdmin(source) then return nil end

    if importSource == 'ox_doorlock' then
        return ImportManager.getOxDoors()
    elseif importSource == 'qb-doorlock' then
        local doors, err = ImportManager.parseQBDoorlock(content)
        if err then return { error = err } end
        return doors
    elseif importSource == 'nui_doorlock' then
        local doors, err = ImportManager.parseNuiDoorlock(content)
        if err then return { error = err } end
        return doors
    elseif importSource == 'custom_json' then
        local doors, err = ImportManager.parseCustomJSON(content)
        if err then return { error = err } end
        return doors
    end

    return nil
end)

lib.callback.register('lennox-doorcreator:server:importExecute', function(source, doors)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end

    local allowed, msg = checkRateLimit(source, 'import', 2, 30000)
    if not allowed then return { ok = false, message = msg } end

    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)

    local result = ImportManager.batchInsert(doors, playerName, playerId)

    refreshDoorCache()

    return { ok = true, success = result.success, failed = result.failed, message = ('%d imported, %d failed'):format(result.success, result.failed) }
end)

-- =========================================================================
--  Backup Callbacks
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:getBackups', function(source)
    if not Framework.isAdmin(source) then return {} end
    return BackupManager.getAll()
end)

lib.callback.register('lennox-doorcreator:server:createBackup', function(source)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end
    local playerName = Framework.getPlayerName(source)
    local result = BackupManager.create('manual', playerName)
    return { ok = true, backup = result }
end)

lib.callback.register('lennox-doorcreator:server:previewBackup', function(source, id)
    if not Framework.isAdmin(source) then return nil end
    return BackupManager.getPreview(id)
end)

lib.callback.register('lennox-doorcreator:server:restoreBackup', function(source, id)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end
    local playerName = Framework.getPlayerName(source)
    local playerId = Framework.getPlayerIdentifier(source)
    local ok, result = BackupManager.restore(id, playerName, playerId)
    if ok then
        refreshDoorCache()
        refreshBuildingCache()
        return { ok = true, message = ('%d doors restored'):format(result) }
    end
    return { ok = false, message = result }
end)

lib.callback.register('lennox-doorcreator:server:deleteBackup', function(source, id)
    if not Framework.isAdmin(source) then return { ok = false, message = 'Access denied' } end
    BackupManager.delete(id)
    return { ok = true }
end)

-- =========================================================================
--  Log Callbacks
-- =========================================================================

lib.callback.register('lennox-doorcreator:server:getLogs', function(source, filters)
    if not Framework.isAdmin(source) then return nil end
    return DoorLogger.getLogs(filters or {})
end)

-- =========================================================================
--  Initialization
-- =========================================================================

Citizen.CreateThread(function()
    if not verifyIntegrity() then
        print('^1[FATAL] Lennox-DoorCreator integrity check failed. Resource disabled.^7')
        return
    end

    for _, line in ipairs(BANNER) do
        print(line)
    end

    local fwName = detectFramework()
    print('^5[Lennox-DoorCreator]^7 Framework: ^2' .. fwName .. '^7')

    Citizen.Wait(1000)

    refreshDoorCache()
    refreshBuildingCache()

    local doorCount = 0
    for _ in pairs(doorCache) do doorCount = doorCount + 1 end
    local buildingCount = 0
    for _ in pairs(buildingCache) do buildingCount = buildingCount + 1 end

    print('^5[Lennox-DoorCreator]^7 Loaded ^2' .. doorCount .. '^7 doors, ^2' .. buildingCount .. '^7 buildings')
    print('^5[Lennox-DoorCreator]^7 Ready! Use ^3/' .. Config.Command .. '^7 in-game')
end)
