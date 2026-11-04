LACConfig = {}

-- =========================================================================
--  Discord Webhooks
-- =========================================================================
-- Read from convars, not committed here. Set the real (regenerated) values
-- in server.cfg, which is gitignored; see server.cfg.example.
LACConfig.Webhooks = {
    bans        = GetConvar('lac_webhook_bans', ''),
    kicks       = GetConvar('lac_webhook_kicks', ''),
    flags       = GetConvar('lac_webhook_flags', ''),
    events      = GetConvar('lac_webhook_events', ''),
    connections = GetConvar('lac_webhook_connections', ''),
}

-- =========================================================================
--  Admin Immunity
-- =========================================================================
LACConfig.AdminAces = {
    'qbcore.god',
    'som.admin',
    'som.mod',
    'command',
}

LACConfig.AdminIdentifiers = {
    'license:1edd18060d34914e203e0036ff7ea5ae0a06ae7e',
    'steam:11000015634fc51',
}

-- =========================================================================
--  Action Thresholds (severity score)
-- =========================================================================
LACConfig.KickThreshold = 15
LACConfig.BanThreshold  = 25

-- =========================================================================
--  Heartbeat
-- =========================================================================
LACConfig.HeartbeatInterval   = 30000
LACConfig.HeartbeatTimeout    = 12000
LACConfig.MaxMissedHeartbeats = 3

-- =========================================================================
--  Weapon Damage
-- =========================================================================
LACConfig.MaxDamageEventsPerSecond = 25
LACConfig.MaxWeaponDamage          = 500.0

LACConfig.BlacklistedWeapons = {
    [0x42BF8A85] = true,  -- Minigun
    [0x6D544C99] = true,  -- Railgun
    [0xB62D1F67] = true,  -- Widowmaker
    [0x476BF155] = true,  -- Up-n-Atomizer
    [0xCDB56D62] = true,  -- Unholy Hellbringer
}

-- =========================================================================
--  Explosions
-- =========================================================================
LACConfig.MaxExplosionsPer5Sec = 5

LACConfig.BlacklistedExplosions = {
    [26] = true, -- TRAIN
}

-- =========================================================================
--  Entities
-- =========================================================================
LACConfig.MaxEntitiesPer2Sec = 15

-- =========================================================================
--  Movement
-- =========================================================================
LACConfig.PositionCheckInterval     = 2000
LACConfig.TeleportDistanceThreshold = 200.0
LACConfig.MaxOnFootSpeed            = 15.0
LACConfig.MaxVehicleSpeed           = 100.0  -- m/s (~360 km/h), catches boosted vehicles
LACConfig.SuperJumpThreshold        = 12.0   -- meters, normal jump is ~1-2m

-- =========================================================================
--  Honeypot Events (instant ban — no legit client ever fires these)
-- =========================================================================
LACConfig.Honeypots = {
    'admin:giveWeapon',
    'admin:setHealth',
    'admin:giveMoney',
    'admin:setArmour',
    'qb-admin:server:giveitem',
    'qb-admin:server:setmoney',
    'server:addCash',
    'server:giveWeaponAll',
    'esx:getSharedObject',
    'esx_society:withdrawMoney',
    'esx_billing:payBill',
    'server:spawnVehicle',
    'admin:reviveAll',
    'admin:teleportAll',
    'admin:noclip',
    'admin:godmode',
    'admin:spawnVehicle',
    'admin:clearInventory',
    'admin:tpToWaypoint',
}

-- =========================================================================
--  Blacklisted Client Resources (known cheat menus)
-- =========================================================================
LACConfig.BlacklistedResources = {
    'menyoo', 'cheat', 'hack', 'mod_menu', 'lambda', 'kiddion',
    'lynx', 'eulen', 'skid', 'executor', 'injector', 'bypass',
    'redengine', 'brutan', 'hammafia', 'dopamine', 'impulse',
    'ozark', 'paragon', 'phantom', 'nightfall', 'cherax', 'stand',
    'desudo', 'xcheats', 'xforce', 'reaper', 'modest',
}

-- =========================================================================
--  Blacklisted Ped Models (server-side model check)
--  Only freemode peds are allowed. Set to false to disable.
-- =========================================================================
LACConfig.EnforceFreemodePed = true

-- =========================================================================
--  Event Rate Limiting (global, per-player)
-- =========================================================================
LACConfig.GlobalEventRateLimit = 100   -- max net events per player per second
LACConfig.GlobalEventRateWindow = 1000 -- ms window

-- =========================================================================
--  v3.0 — Economy Protection
-- =========================================================================
LACConfig.MaxDumpsterItemAmount = 5    -- max items per dumpster receive event
LACConfig.MaxDumpsterCash       = 500  -- max cash per dumpster money event
LACConfig.ExploitEventRateLimit = 10   -- max triggers of exploit-monitored events per 10s

-- =========================================================================
--  v3.0 — Chat Protection
-- =========================================================================
LACConfig.MaxChatMessagesPerWindow = 8  -- messages per 5s window

-- =========================================================================
--  v3.0 — Connection Protection
-- =========================================================================
LACConfig.MaxReconnectsPerMinute = 5

-- =========================================================================
--  v3.0 — Entity Protection
-- =========================================================================
LACConfig.MaxEntityDeletionsPer5Sec = 30

-- =========================================================================
--  v3.0 — Screenshot on Ban (requires screenshot-basic resource)
-- =========================================================================
LACConfig.ScreenshotOnBan = true

-- =========================================================================
--  v1.0 Full Release — Hardware Fingerprinting
-- =========================================================================
LACConfig.EnableHWFingerprint = true
LACConfig.HWIDSpoofThreshold = 3   -- different identities sharing same HWID before admin alert

-- =========================================================================
--  v1.0 Full Release — Particle Interception
-- =========================================================================
LACConfig.TotalParticleRateLimit = 100  -- total particle calls per 5s across all natives

-- =========================================================================
--  v1.0 Full Release — Freecam Detection
-- =========================================================================
LACConfig.CameraDistanceSoft = 20.0   -- meters, soft flag threshold
LACConfig.CameraDistanceHard = 100.0  -- meters, hard flag threshold

-- =========================================================================
--  v1.0 Full Release — Progressive Teleport
-- =========================================================================
LACConfig.ProgressiveTeleportWindow = 10  -- seconds
LACConfig.ProgressiveTeleportMaxDist = 300.0  -- meters cumulative in window

-- =========================================================================
--  v1.0 Full Release — World Manipulation
-- =========================================================================
LACConfig.MaxWeatherChangesPer30Sec = 3

-- =========================================================================
--  v1.0 Full Release — Framework
-- =========================================================================
LACConfig.FrameworkAutoDetect = true  -- auto-detect QBCore/ESX/standalone

-- =========================================================================
--  v1.0 Full Release — Behavioral Analysis Engine
-- =========================================================================
LACConfig.BehavioralAnalysis = true
LACConfig.BehavioralPositionSamples   = 30    -- circular buffer size
LACConfig.BehavioralPositionInterval  = 2000  -- ms between samples
LACConfig.BehavioralCombatWindow      = 300   -- seconds (5 min rolling)
LACConfig.BehavioralHeadshotThreshold = 65    -- % over 100-hit window
LACConfig.BehavioralDPSThreshold      = 120   -- % of theoretical max
LACConfig.BehavioralEconWindow        = 1800  -- seconds (30 min)
LACConfig.BehavioralEconStdDevs       = 3     -- flag above N standard deviations
LACConfig.BehavioralWebhook           = ''    -- separate webhook for behavioral alerts (optional, falls back to 'flags')

-- =========================================================================
--  v1.0 Full Release — Server-Side Damage Model
-- =========================================================================
LACConfig.DamageValidation       = true
LACConfig.DamageTolerancePct     = 30   -- ±% tolerance for per-hit damage
LACConfig.FireRateTolerancePct   = 130  -- flag above 130% of weapon RPM
LACConfig.FireRateMinShots       = 10   -- min shots before RPM check
LACConfig.DamageRangeMultiplier  = 2.0  -- flag hits beyond effective_range × this
LACConfig.HeadshotWindow         = 200  -- hits to track for headshot ratio

-- =========================================================================
--  v1.0 Full Release — Advanced Economy Protection
-- =========================================================================
LACConfig.TransactionSigningEnabled = true
LACConfig.TransactionNonceExpiry    = 30    -- seconds
LACConfig.JobMaxPerTx               = 5000  -- max $ per job transaction
LACConfig.JobMaxPer30Min            = 50000 -- max $ per 30 min from jobs
LACConfig.DupeDetectionEnabled      = true

-- =========================================================================
--  v1.0 Full Release — Advanced God Mode Detection
-- =========================================================================
LACConfig.GodModeTestInterval = 120000  -- ms between server-initiated tests
LACConfig.GodModeTestDamage   = 1       -- HP to apply for test
LACConfig.RagdollTestInterval = 180000  -- ms between ragdoll tests

-- =========================================================================
--  v1.0 Full Release — Vehicle Handling Validation
-- =========================================================================
LACConfig.VehicleHandlingValidation = true
LACConfig.VehAccelThresholdPct      = 150  -- % of class max before flag
LACConfig.VehAccelMinSamples        = 3    -- consecutive samples required
LACConfig.VehHandlingSampleInterval = 2500 -- ms between velocity samples

-- =========================================================================
--  v1.0 Full Release — Advanced Noclip Detection
-- =========================================================================
LACConfig.AdvancedNoclip         = true
LACConfig.NoclipRaycastInterval  = 3000  -- ms between shape test checks
LACConfig.SubterraneanInteriors  = {     -- Z coords below which underground is legitimate
    { x = 404.0, y = -997.0, z = -100.0, radius = 200.0 },   -- Vangelico
    { x = 1087.0, y = -3187.0, z = -100.0, radius = 100.0 }, -- Facility
}

-- =========================================================================
--  v1.0 Full Release — Advanced Spectate Detection
-- =========================================================================
LACConfig.SpectateInvisibleTimeout = 30  -- seconds invisible = flag

-- =========================================================================
--  v1.0 Full Release — Object/Prop Manipulation
-- =========================================================================
LACConfig.ObjectSpawnRateLimit   = 20   -- objects per 5s
LACConfig.ObjectSpawnMaxDistance  = 50.0 -- meters from player
LACConfig.MaxSelfAttachments     = 10
LACConfig.BlacklistedObjects     = {}   -- hash list, empty by default

-- =========================================================================
--  v1.0 Full Release — Network Manipulation
-- =========================================================================
LACConfig.DesyncDistanceThreshold = 5.0   -- meters ahead of server pos
LACConfig.LagSwitchBurstThreshold = 50    -- events in burst
LACConfig.LagSwitchSilenceMs      = 3000  -- ms of silence before burst

-- =========================================================================
--  v1.0 Full Release — Advanced Vehicle Detections
-- =========================================================================
LACConfig.MissileSpamLimit    = 10  -- missiles per 5s
LACConfig.CountermeasureLimit = 5   -- countermeasures per 3s
LACConfig.MaxControlledVehicles = 5

-- =========================================================================
--  v1.0 Full Release — Performance Protection
-- =========================================================================
LACConfig.FPSMonitorEnabled      = true
LACConfig.FPSAttackThreshold     = 5.0   -- sustained <5 FPS = possible attack
LACConfig.ThreadFloodThreshold   = 50    -- threads per resource

-- =========================================================================
--  v1.0 Full Release — Database Support (Optional)
-- =========================================================================
LACConfig.StorageMode = 'json'  -- 'json' or 'database'
LACConfig.DatabaseResource = nil -- auto-detect oxmysql/ghmattimysql

-- =========================================================================
--  v1.0 Full Release — Discord Webhook Enhancements
-- =========================================================================
LACConfig.Webhooks.behavioral  = ''  -- behavioral alert channel
LACConfig.Webhooks.screenshots = ''  -- screenshot channel
LACConfig.StatusEmbedInterval  = 0   -- 0 = disabled, seconds between status embeds

-- =========================================================================
--  v1.0 Full Release — Resource Integrity
-- =========================================================================
LACConfig.ResourceIntegrity       = false  -- opt-in, requires /lac_hash_resources
LACConfig.ResourceIntegrityHashes = {}     -- populated by /lac_hash_resources
