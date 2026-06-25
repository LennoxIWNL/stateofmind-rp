# Lennox Anti-Cheat — Full Release Status

## COMPLETED (Pass 1)

### Client Detections Implemented (28 modules)
1. God Mode (invincible flag) — soft 8
2. Blacklisted Resources (31 patterns) — hard, auto-ban
3. Spectate/Freecam (invisible + moving) — soft 8
4. Noclip Underground (ground Z comparison, 3 hits) — soft 8
5. Noclip Flying (altitude + velocity, no chute, 4 hits) — soft 8
6. Health Snap Heal (>100 HP in <500ms) — soft 5
7. Weapon Injection (has blacklisted weapon, auto-remove) — hard 10
8. Anti-Executor: 16 cheat tool globals (Executor, CheatEngine, LuaExec, SkidMenu, EulenCheat, HamMafia, Dopamine, Ozark, Paragon, PhantomX, Cherax, RedEngine, Desudo, Stand, Nightfall, XCheats) — hard 15
9. Anti-Executor: debug.sethook + jit table check — hard 15
10. Anti-Tamper (sigHash integrity, 60-90s) — hard 15
11. Super Jump (>12m, 2 consecutive hits) — soft 8
12. Vehicle Speed (>100 m/s, 3 consecutive) — soft 5
13. Infinite Ammo (ammo unchanged after shooting, 3 checks) — hard 8
14. Night/Thermal Vision (GetUsingnightvision/GetUsingseethrough) — soft 5
15. Ped Flag Manipulation (invisible, frozen, no-ragdoll flag 32) — soft 8
16. Rapid Respawn (dead→alive <3s, 3 times) — hard 10
17. Environment Integrity (tostring snapshot of pcall/rawget/RegisterNetEvent/TriggerServerEvent at boot, verified every 30-45s; string.dump presence; _G metatable injection) — hard 20
18. Canary System (2 planted global values with derived names, verified every 20s) — hard 15
19. Combat: Shooting While Dead (IsPedShooting + IsPedDeadOrDying, 3 hits) — hard 10
20. Combat: Ragdoll Cancel in Combat (config flag 32 during melee) — soft 8
21. Vehicle Fly (non-aircraft altitude gain, 4 hits) — hard 8
22. Swim Speed (>8 m/s, 3 hits) — soft 5
23. Particle Interception (wraps StartParticleFxNonLoopedAtCoord + 3 more natives, shared 100/5s limit) — hard 8
24. Native Return Validation (GetPlayerServerId, GetEntityModel sanity) — hard varies
25. **Hardware Fingerprint Collector** — collects GPU/resolution/RAM/language/build, hashes with MAGIC salt, submits once, monitors for mid-session change (severity 15 hard)
26. **Freecam Detection** — camera vs player distance (>20m soft, >100m hard, 2-4 hit confirm)
27. **Progressive Teleport Detection** — circular buffer of 10 positions over 10s, cumulative >300m on foot = flagged
28. **World Manipulation Detection** — time jumps (>1h in <5s), weather spam (>3 changes in 30s)

### Client Anti-Executor Expansion (v1.0)
29. **Global Creation Monitor** — snapshots all globals at boot, detects new function globals appearing after boot — hard 15
30. **NUI Focus Detection** — NUI focused without keepInput while player moving = suspicious
31. **Loadstring Probe** — checks if loadstring or load() exist in _G (shouldn't in FiveM client) — hard 20
32. **Standard Library Caching** — pcall, type, tostring, rawget, pairs, ipairs, math cached at top of closure, immune to post-hook replacement

### Server Detections Implemented (18 modules)
1. Heartbeat Challenge-Response (30s interval, HMAC-style math, 3 miss threshold)
2. Weapon Damage Filtering (blacklisted weapons hard 10, rapid fire soft 5, excessive damage soft 5)
3. Explosion Filtering (blacklisted types hard 10, spam soft 8)
4. Entity Creation Rate Limiting (>15/2s, soft 8)
5. Position Tracking (teleport >200m soft 5, speed >15 m/s soft 3)
6. Honeypot Events (19 traps, instant ban)
7. Resource Injection Monitor (count change alert)
8. Ped Model Validation (non-freemode = hard 10)
9. Health/Armor Monitor (HP >200 hard 10, armor >100 hard 10, suspicious heal soft 3)
10. Wanted Level Validation (>5 hard 5)
11. Global Event Rate Limiter (>100/sec soft 5)
12. Vehicle Teleport Detection (>500m in <3s, soft 5)
13. Integrity Self-Check (hash constants every 2min)
14. **HWID Spoof receiver** (mid-session change hard 15)
15. **Freecam receiver** (hard 10)
16. **Progressive Teleport receiver** (soft 8)
17. **World Manipulation receiver** (soft 5)
18. **Object Spam receiver** (soft 8)

### Server Protection Systems (10 modules)
1. Economy Exploit Protection (qb-inventory recieveItem/givemoney, amount cap + rate limit)
2. Permission Escalation Detection (add_ace, stop, restart, etc. from in-game = hard 20)
3. Chat Spam Protection (8 msg/5s + duplicate flood)
4. Connection Flood Protection (5 reconnects/30s)
5. Mass Entity Deletion Detection (>30/5s)
6. Screenshot on Ban (screenshot-basic wrapper)
7. Weapon Damage Audit (>200 hits/min same weapon)
8. Inventory Session Audit (anomaly volume at disconnect)
9. Runtime Resource Monitoring (start/stop alerts with @here)
10. Wanted Level Validation (server-side)

### Server Infrastructure
- Hardware Fingerprint System (hwid.lua) — stores HWID per player, matches in ban checks, detects ban evasion via HWID index, alerts when same HWID appears on 3+ identities
- Framework Auto-Detection (QBCore/ESX/standalone) — auto-detects via GetResourceState, session init hooks for both frameworks + fallback
- Session Token System with 10-minute rotation
- Nonce Replay Protection with 5-minute GC
- Dual Scoring (hard/soft) with decay
- Anti-Resource-Stop alerting

### Admin Commands (10)
/cheater, /lac_unban, /lac_score, /lac_info, /lac_status, /lac_screenshot, /lac_exempt, /lac_unexempt, /lac_expectwarp, /lac_dump

### Exports (14)
IsAdmin, FlagPlayer, KickPlayer, BanPlayer, CheckBan, GetScore, ExpectWarp, IsExempt, SetExempt, RemoveExempt, GetHWID, GetPlayerInfo, GetStats, IsWarpExpected

### Obfuscation
- XOR byte array string encoding (8-byte rotating key)
- Variable name mangling (_0x hex identifiers)
- do...end closure isolation
- Standard library caching (pre-hook)
- Event name derivation via sigHash
- Timing jitter on all intervals

### Files
Server: main.lua, detections.lua, protection.lua, hwid.lua, connect.lua, commands.lua
Client: main.lua (obfuscated)
Shared: config.lua
Data: bans.json
Sell Copy: All above + README.md, clean config (no personal data)

---

## COMPLETED (Pass 2)

### Behavioral Analysis Engine ✓ (server/behavioral.lua)
- Rolling 60-second position history per player (circular buffer, configurable 30 points)
- Movement variance calculation (teleporter signature vs speed hacker signature)
- Movement entropy for bot detection (low variance + steady speed flagged)
- Combat profiling: damage dealt/received rolling 5-min window, K/D velocity, headshot % over 100-hit window (flag >65%)
- Economic profiling: money earned per source per 30-min window, earning rate vs server average, flag >3 std deviations
- Anomaly scoring: 0-100 per dimension, informational only (Discord alerts, never auto-ban)
- Export: GetBehavioralData(src)

### Server-Side Damage Model ✓ (server/damage_model.lua)
- Weapon stat database (40+ weapons: base damage, headshot multiplier, RPM, effective range, damage falloff)
- Per-hit damage validation on weaponDamageEvent (expected range ±30%, configurable)
- Fire rate validation per weapon (flag >130% of weapon RPM for 10+ shots, configurable)
- Damage-from-impossible-range detection (distance > effective range × 2)
- Headshot ratio tracking per weapon over 200-hit window
- Feeds into behavioral analysis engine

### Advanced Economy Protection ✓ (server/economy.lua)
- Transaction signing: server-generated nonce per money operation, single-use, 30s expiry
- Money source validation: per-source limits (job max $5000/tx, max $50000/30min)
- Inventory consistency: snapshot on open, compare on close, flag increases without server-side add
- Duplicate transaction detection: hash(amount + source + 10s bucket), flag same hash twice = hard 15
- Item dupe detection: same serial in two inventories = hard 20
- 7 new exports: IssueTransactionNonce, ValidateTransaction, ValidateMoneySource, CheckDuplicateTransaction, SnapshotInventory, ValidateInventoryClose, TrackItemSerial

### Advanced God Mode Detection ✓ (server/detections.lua + client/main.lua)
- Damage application test: server instructs client to apply 1-2 HP damage, verify health decreases — hard 10
- Server health authoritativeness: server maintains own health value, compares with client — soft 5
- Ragdoll resistance test: server applies ragdoll force, verify ped ragdolls — soft 8
- Vehicle god mode: server tracks vehicle health, flags impossible recovery — soft 8
- Configurable intervals (GodModeTestInterval, RagdollTestInterval)

### Vehicle Handling Validation ✓ (client/main.lua)
- Handling data table per vehicle class (23 classes: max acceleration values)
- Measure actual acceleration from velocity samples every 2-3s
- Flag if acceleration exceeds 150% of class max for 3+ consecutive samples (configurable)
- Vehicle gravity modification detection (floating in air with low upward velocity)
- Respects aircraft exemptions (helicopter/plane classes)

### Advanced Noclip Detection ✓ (client/main.lua)
- StartShapeTestRay downward collision check — no ground below = suspicious
- Subterranean interior exemptions table (configurable coordinate list)
- Velocity-based detection (zero vertical velocity but not on ground, elevated)
- Wall-clip detection (ray in movement direction hits wall but player passes through)
- Hit counter with decay

### Event Parameter Validation Framework ✓ (server/validation.lua)
- Define expected parameter types + value ranges per event via schema
- Auto-validate before processing (RegisterNetEvent wrapper)
- Built-in schemas for QBCore and ESX common exploitable events
- Export: RegisterEventValidation(eventName, schema)
- Export: IsEventValid(eventName, ...)
- Supports: number (min/max), string (maxLen, pattern), boolean, table, required flag

### Advanced Spectate Detection ✓ (client/main.lua)
- Camera velocity vs player velocity comparison (camera moving fast, ped stationary)
- Invisible for >30 seconds continuously = flag (configurable timeout)
- Sends to det:spectadv receiver on server

### Object/Prop Manipulation Detection ✓ (client/main.lua)
- Attachment abuse detection (>10 attachments to self, configurable)
- Uses GetGamePool('CObject') for efficient entity scanning
- Sends to det:objmanip receiver on server

### Ped Manipulation Detection (Expanded) ✓ (client/main.lua)
- Ped alpha transparency (<200 while not in valid state, moving)
- Ped clone detection (same model + position within 2m + alive)
- Uses GetGamePool('CPed') for efficient scanning

### Network Manipulation Detection ✓ (client/main.lua)
- Desync abuse detection (compare local vs server-seen position, flag >5m delta)
- Configurable DesyncDistanceThreshold

### Advanced Vehicle Detections ✓ (client/main.lua)
- Vehicle seat manipulation (seat index > max seats for vehicle)
- Vehicle ghost detection (entity at coords 0,0,0; 0 health but still driving)
- Multi-vehicle exploit (player owns >5 vehicles, configurable)
- All sent to det:vehadv receiver — hard 8

### Anti-Tamper Upgrades ✓ (client/main.lua)
- Debugger detection (set debug.sethook and verify callback fires)
- Executor sandbox detection (require/package.path/load behavior anomalies)
- Timing analysis (operation duration anomalies — VM overhead detection)
- All use existing det:antitamper event channel

### Advanced Obfuscation ✓ (client/main.lua)
- Opaque predicates (always-true/false conditions gating dead code)
- Number transformation (constants stored as XOR pairs)
- Dead code injection (gated by opaque predicates, never executes)
- Function indirection (reference table with periodic shuffle every 5 min)

### Performance Protection ✓ (client/main.lua)
- Client FPS monitoring (GetFrameTime → FPS calculation, flag sustained <5 FPS)
- 3-hit confirmation before flagging
- Configurable threshold (FPSAttackThreshold)

### Resource Integrity Verification ✓ (client/main.lua + server/commands.lua)
- Client-side resource metadata hashing at boot
- Compare to known-good hashes from /lac_hash_resources
- Opt-in via config (ResourceIntegrity = true, requires setup)
- /lac_hash_resources command computes and stores hashes

### Discord Webhook Enhancements ✓
- Behavioral alert channel (configurable, falls back to 'flags')
- Screenshot channel (configurable)
- Periodic status embeds (configurable interval, 0 = disabled)
- Rich embeds with player info fields throughout

### Additional Admin Commands ✓ (server/commands.lua)
- /lac_banlist [page] — paginated ban list (10 per page)
- /lac_baninfo [banId] — full ban details (player, reason, identifiers, HWID)
- /lac_reload — reload config.lua without restart
- /lac_hash_resources — compute resource hashes for integrity system

### New Server Detection Receivers ✓ (server/detections.lua)
- _rce() helper function for standardized event registration
- 10 new detection receivers: godtest, vehhandle, noclipwall, spectadv, objmanip, pedmanip, netmanip, vehadv, perf, resinteg
- Server-instrumented god mode test (challenge-response with timeout)
- Server-instrumented ragdoll test
- Server health authoritativeness tracking
- Vehicle god mode health tracking

### New Config Values ✓ (config.lua)
- 40+ new configuration values across all Pass 2 modules
- All with sensible defaults
- Database support config (StorageMode, DatabaseResource)

### New Server Files ✓
- server/behavioral.lua — Behavioral analysis engine
- server/damage_model.lua — Weapon stat database + damage validation
- server/economy.lua — Advanced economy protection
- server/validation.lua — Event parameter validation framework

### Updated Files ✓
- config.lua — 40+ new configuration values
- fxmanifest.lua — 4 new server scripts added
- server/main.lua — LAC._getBans() accessor
- server/detections.lua — _rce helper, 10 new receivers, god mode test, ragdoll test, health tracking, vehicle god mode
- server/commands.lua — 4 new commands, periodic status embed
- client/main.lua — 40+ new _E entries, 13 new detection modules, obfuscation features

---

## REMAINING

### Database Support (Optional)
- oxmysql / ghmattimysql auto-detection — config placeholder ready (StorageMode, DatabaseResource)
- Tables: lennox_bans, lennox_logs, lennox_players, lennox_behavioral
- Migration from bans.json to database
- **Note:** Config values are defined. Implementation deferred — requires a live database to test against. The JSON storage works for all server sizes; database mode is a performance optimization for very large ban lists.

### Object/Prop Spawn Rate Monitoring (partial)
- Object spawn monitoring per player (20/5s limit) — the server-side entityCreating handler already covers this; client-side spawn-rate counter is wired but needs the entityCreating native on client which FiveM doesn't expose per-player. Attachment abuse and blacklisted object checks are fully implemented.
- Blacklisted object models — config placeholder ready (BlacklistedObjects), needs server-specific model list population
- Prop gun detection (object creation correlated with weapon fire timing) — requires frame-level correlation that produces too many false positives in testing

### Server-Side Load Attack Detection (partial)
- Server load attack detection (entity/event correlation with tick time) — partially covered by existing entity spam + event rate limiter. Full tick-time correlation requires GetGameTimer resolution that isn't reliable in server context across all hosting environments.

### Network Lag Switch Detection (partial)
- Lag switch detection (event burst patterns) — the client-side desync check is implemented. Full burst-pattern detection requires server-side event timestamping which overlaps with the existing event rate limiter. The current event rate limiter (>100/sec) catches the most egregious burst patterns.

### Network Ragdoll Desync
- Ragdoll desync (ragdolled on server but not client) — requires reliable server-side ragdoll state query which FiveM doesn't consistently expose via GetPedRagdollState on server.
