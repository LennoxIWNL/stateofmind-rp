BackupManager = {}

local LOG_TAG = '^5[Lennox-DoorCreator]^7'

function BackupManager.create(backupType, createdBy)
    local doors = MySQL.query.await('SELECT id, name, data FROM ox_doorlock ORDER BY id ASC')
    local buildings = MySQL.query.await('SELECT * FROM lennox_buildings ORDER BY id ASC')

    local snapshot = json.encode({
        doors = doors or {},
        buildings = buildings or {},
        timestamp = os.time(),
    })

    local name = ('%s Backup — %s'):format(
        backupType == 'auto' and 'Auto' or 'Manual',
        os.date('%Y-%m-%d %H:%M:%S')
    )

    local id = MySQL.insert.await(
        'INSERT INTO lennox_backups (name, type, door_count, building_count, data, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        { name, backupType, #(doors or {}), #(buildings or {}), snapshot, createdBy or 'System' }
    )

    BackupManager.enforceLimit()

    DoorLogger.log(DoorActions.BACKUP_CREATE, {
        playerName = createdBy or 'System',
        playerIdentifier = 'system',
        details = { backupId = id, type = backupType, doors = #(doors or {}), buildings = #(buildings or {}) },
    })

    print(('%s ^2Backup created:^7 %s (ID: %d, %d doors, %d buildings)'):format(
        LOG_TAG, name, id, #(doors or {}), #(buildings or {})
    ))

    return {
        id = id,
        name = name,
        type = backupType,
        doorCount = #(doors or {}),
        buildingCount = #(buildings or {}),
    }
end

function BackupManager.enforceLimit()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_backups')
    if count and count > Config.MaxBackups then
        local excess = count - Config.MaxBackups
        MySQL.update.await(
            ('DELETE FROM lennox_backups ORDER BY created_at ASC LIMIT %d'):format(excess)
        )
    end
end

function BackupManager.getAll()
    local rows = MySQL.query.await(
        'SELECT id, name, type, door_count, building_count, created_by, created_at FROM lennox_backups ORDER BY created_at DESC'
    )
    return rows or {}
end

function BackupManager.getById(id)
    local rows = MySQL.query.await('SELECT * FROM lennox_backups WHERE id = ?', { id })
    return rows and rows[1] or nil
end

function BackupManager.restore(id, playerName, playerIdentifier)
    local backup = BackupManager.getById(id)
    if not backup then return false, 'Backup not found' end

    local data = json.decode(backup.data)
    if not data or not data.doors then return false, 'Invalid backup data' end

    BackupManager.create('auto', 'Pre-Restore Auto-Backup')

    MySQL.update.await('DELETE FROM ox_doorlock')

    local restored = 0
    for _, door in ipairs(data.doors) do
        MySQL.insert.await('INSERT INTO ox_doorlock (id, name, data) VALUES (?, ?, ?)', {
            door.id, door.name, door.data
        })
        restored = restored + 1
    end

    if data.buildings then
        MySQL.update.await('DELETE FROM lennox_buildings')
        for _, building in ipairs(data.buildings) do
            MySQL.insert.await(
                'INSERT INTO lennox_buildings (id, name, description, doors, permissions, metadata, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { building.id, building.name, building.description, building.doors, building.permissions, building.metadata, building.created_by }
            )
        end
    end

    DoorLogger.log(DoorActions.BACKUP_RESTORE, {
        playerName = playerName,
        playerIdentifier = playerIdentifier,
        details = { backupId = id, doorsRestored = restored },
    })

    print(('%s ^2Backup restored:^7 ID %d — %d doors restored by %s'):format(LOG_TAG, id, restored, playerName or 'Unknown'))

    return true, restored
end

function BackupManager.delete(id)
    MySQL.update.await('DELETE FROM lennox_backups WHERE id = ?', { id })
end

function BackupManager.getPreview(id)
    local backup = BackupManager.getById(id)
    if not backup then return nil end

    local data = json.decode(backup.data)
    if not data then return nil end

    local doorSummary = {}
    for _, door in ipairs(data.doors or {}) do
        local doorData = json.decode(door.data or '{}')
        doorSummary[#doorSummary + 1] = {
            id = door.id,
            name = door.name,
            model = doorData.model,
            coords = doorData.coords,
            state = doorData.state,
        }
    end

    return {
        id = backup.id,
        name = backup.name,
        type = backup.type,
        doorCount = backup.door_count,
        buildingCount = backup.building_count,
        createdBy = backup.created_by,
        createdAt = backup.created_at,
        doors = doorSummary,
        buildings = data.buildings or {},
    }
end

if Config.AutoBackup then
    Citizen.CreateThread(function()
        Citizen.Wait(5000)
        BackupManager.create('auto', 'System')

        while true do
            Citizen.Wait(Config.BackupInterval)
            BackupManager.create('auto', 'System')
        end
    end)
end
