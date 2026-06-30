Config = {}

-- =========================================================================
--  General
-- =========================================================================
Config.Debug = false
Config.Command = 'doorcreator'
Config.CommandAliases = { 'dc', 'doors' }
Config.Keybind = 'F7'
Config.AdminOnly = true

-- =========================================================================
--  Framework
-- =========================================================================
Config.Framework = 'auto' -- 'auto', 'qb', 'esx', 'standalone'

-- =========================================================================
--  Permissions
-- =========================================================================
Config.AdminAces = {
    'qbcore.god',
    'command',
    'group.admin',
}

Config.AdminIdentifiers = {
    -- 'license:xxxx',
    -- 'steam:xxxx',
    -- 'discord:xxxx',
}

-- =========================================================================
--  Door Lock System
-- =========================================================================
Config.DoorLockSystem = 'ox_doorlock'

-- =========================================================================
--  UI Theme
-- =========================================================================
Config.ThemeColor = '#6366f1'
Config.UIScale = 1.0

-- =========================================================================
--  Creator Settings
-- =========================================================================
Config.RaycastDistance = 10.0
Config.DefaultLockState = 1
Config.DefaultMaxDistance = 2.0
Config.DefaultDoorRate = 1.0
Config.AutoNamePrefix = 'Door'

-- =========================================================================
--  Bulk Selection
-- =========================================================================
Config.BulkDefaultRadius = 10.0
Config.BulkMaxRadius = 100.0
Config.BulkMinRadius = 1.0
Config.MaxBulkDoors = 1000

-- =========================================================================
--  Backups
-- =========================================================================
Config.AutoBackup = true
Config.BackupInterval = 21600000
Config.MaxBackups = 10

-- =========================================================================
--  Logging
-- =========================================================================
Config.LogToDiscord = false
Config.DiscordWebhook = ''
Config.LogRetention = 30

-- =========================================================================
--  Sounds
-- =========================================================================
Config.DefaultLockSound = 'door-bolt-4'
Config.DefaultUnlockSound = 'door-bolt-4'

-- =========================================================================
--  Import
-- =========================================================================
Config.AllowImport = true
Config.SupportedImports = {
    'ox_doorlock',
    'qb-doorlock',
    'nui_doorlock',
    'custom_json',
}
