local LOG_TAG = '^5[Lennox-DoorCreator]^7'

RegisterCommand(Config.Command, function(source)
    if source == 0 then
        print(LOG_TAG .. ' This command can only be used in-game.')
        return
    end
    TriggerClientEvent('lennox-doorcreator:client:open', source)
end, false)

for _, alias in ipairs(Config.CommandAliases or {}) do
    RegisterCommand(alias, function(source, args)
        if source == 0 then
            if args[1] == 'backup' then
                local result = BackupManager.create('manual', 'Console')
                print(('%s ^2Manual backup created:^7 %s'):format(LOG_TAG, result.name))
            elseif args[1] == 'stats' then
                local doors = MySQL.scalar.await('SELECT COUNT(*) FROM ox_doorlock')
                local buildings = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_buildings')
                local templates = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_templates')
                local backups = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_backups')
                print(('%s ^3Stats:^7 %d doors, %d buildings, %d templates, %d backups'):format(LOG_TAG, doors or 0, buildings or 0, templates or 0, backups or 0))
            else
                print(LOG_TAG .. ' Use in-game or provide a subcommand: backup, stats')
            end
            return
        end

        if not args[1] then
            TriggerClientEvent('lennox-doorcreator:client:open', source)
            return
        end

        if not Framework.isAdmin(source) then
            TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', 'Access denied.')
            return
        end

        local sub = args[1]:lower()

        if sub == 'backup' then
            local name = Framework.getPlayerName(source)
            local result = BackupManager.create('manual', name)
            TriggerClientEvent('lennox-doorcreator:client:notify', source, 'success', ('Backup created: %s'):format(result.name))

        elseif sub == 'restore' then
            local id = tonumber(args[2])
            if not id then
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', 'Usage: /dc restore [id]')
                return
            end
            local name = Framework.getPlayerName(source)
            local identifier = Framework.getPlayerIdentifier(source)
            local ok, count = BackupManager.restore(id, name, identifier)
            if ok then
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'success', ('Restored %d doors from backup #%d'):format(count, id))
            else
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', 'Restore failed: ' .. tostring(count))
            end

        elseif sub == 'stats' then
            local doors = MySQL.scalar.await('SELECT COUNT(*) FROM ox_doorlock')
            local buildings = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_buildings')
            local templates = MySQL.scalar.await('SELECT COUNT(*) FROM lennox_templates')
            TriggerClientEvent('lennox-doorcreator:client:notify', source, 'info',
                ('Stats: %d doors, %d buildings, %d templates'):format(doors or 0, buildings or 0, templates or 0))

        elseif sub == 'delete' then
            local doorId = tonumber(args[2])
            if not doorId then
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', 'Usage: /dc delete [doorId]')
                return
            end
            MySQL.update.await('DELETE FROM ox_doorlock WHERE id = ?', { doorId })
            local name = Framework.getPlayerName(source)
            local identifier = Framework.getPlayerIdentifier(source)
            DoorLogger.log(DoorActions.DELETE, {
                doorId = doorId,
                playerName = name,
                playerIdentifier = identifier,
                details = { method = 'command' },
            })
            TriggerClientEvent('lennox-doorcreator:client:notify', source, 'success', ('Door #%d deleted.'):format(doorId))

        elseif sub == 'tp' then
            local doorId = tonumber(args[2])
            if not doorId then
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', 'Usage: /dc tp [doorId]')
                return
            end
            local rows = MySQL.query.await('SELECT data FROM ox_doorlock WHERE id = ?', { doorId })
            if not rows or not rows[1] then
                TriggerClientEvent('lennox-doorcreator:client:notify', source, 'error', ('Door #%d not found.'):format(doorId))
                return
            end
            local data = json.decode(rows[1].data)
            if data and data.coords then
                TriggerClientEvent('lennox-doorcreator:client:teleport', source, data.coords)
            end
        end
    end, false)
end
