-- The downed state: the authority.
--
-- The client reports that its ped died. It does not decide that it is down, how
-- long for, whether it may get up, or what that costs. All of that is here,
-- because a client that owned any of it could refuse to go down, revive itself
-- for free, or skip the fee.
--
-- The state lives in a statebag rather than only in this table, so som-police
-- (custody of a downed suspect), som-theft (robbing a body) and a future EMS
-- job can all read it without asking.

local core = exports['som-core']

Medical = {}

-- downed[citizenid] = { source, since = os.time(), cause = string|nil }
--
-- Keyed by citizenid rather than source, so a player who reconnects while down
-- is still down. Keying by source would hand out a free revive to anyone
-- willing to rejoin.
local downed = {}

---@param source number
---@return string|nil citizenid
local function cidOf(source)
    local player = core:getPlayer(source)
    return player and player.citizenid or nil
end

---@param source number
---@param state boolean
local function publish(source, state, since)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    -- Replicated, so every client sees who is down without a broadcast event.
    Player(source).state:set('som:downed', state and { since = since } or false, true)
end

---Whether a character is currently down.
---@param ref number|string source or citizenid
---@return boolean
function Medical.IsDowned(ref)
    if type(ref) == 'string' then return downed[ref] ~= nil end

    local cid = cidOf(ref)
    return cid ~= nil and downed[cid] ~= nil
end

---Puts a player down. The only path into the state.
---@param source number
---@param cause string|nil
---@return boolean
function Medical.Down(source, cause)
    local cid = cidOf(source)
    if not cid then return false end
    if downed[cid] then return false end

    local since = os.time()
    downed[cid] = { source = source, since = since, cause = cause }

    core:setMetadata(source, 'downed', true)
    publish(source, true, since)

    TriggerClientEvent('som-medical:client:down', source, since, 0)
    TriggerEvent('som:server:playerDowned', source, cid, cause)

    return true
end

---Brings a player back up where they lie. The path a medic will use.
---
---Exported now, before any EMS job exists, so that job is written against a
---contract that already works rather than inventing its own revive.
---@param source number
---@param by number|nil the medic, for the log
---@return boolean
function Medical.Revive(source, by)
    local cid = cidOf(source)
    if not cid or not downed[cid] then return false end

    downed[cid] = nil

    core:setMetadata(source, 'downed', false)
    publish(source, false)

    TriggerClientEvent('som-medical:client:revive', source, false)
    TriggerEvent('som:server:playerRevived', source, cid, by)

    return true
end

exports('isDowned', Medical.IsDowned)
exports('down', Medical.Down)
exports('revive', Medical.Revive)

-- ---------------------------------------------------------------------------
-- Going down
-- ---------------------------------------------------------------------------

---Whether the server's own view of this player's ped says it is dead.
---
---Retried once, because entity health is replicated and the client reports its
---death the instant it happens. A single check can genuinely lose that race and
---refuse a real death, which is a far worse failure than the one it prevents.
---A player who is not dying is still not dying 300ms later.
---@param source number
---@return boolean
local function pedIsDead(source)
    for _ = 1, 2 do
        local ped = GetPlayerPed(source)

        if ped and ped ~= 0 and GetEntityHealth(ped) <= 0 then return true end

        Wait(300)
    end

    return false
end

-- In flight, so a client cannot open a hundred of these and hold the server in
-- the Wait above.
local reporting = {}

RegisterNetEvent('som-medical:server:died', function(cause)
    local source = source

    -- The client says only THAT it died. Everything else is derived here.
    if cause ~= nil and type(cause) ~= 'string' then return end

    local player = core:getPlayer(source)
    if not player then return end

    if reporting[source] then return end
    reporting[source] = true

    -- THE DEATH ITSELF IS CHECKED, not just the shape of the message.
    --
    -- Without this the event is a self-service invincibility button: a player
    -- losing a firefight triggers it at full health, the client half of this
    -- resource then holds them at 150 HP with SetEntityInvincible every frame,
    -- and the shots that were about to kill them stop landing. They wake up at
    -- the hospital for $350 having won the fight by declaring themselves dead.
    local dead = pedIsDead(source)

    reporting[source] = nil

    if not dead then return end

    -- Still connected, and still the same character, after the wait above.
    if not core:getPlayer(source) then return end

    Medical.Down(source, cause and cause:sub(1, 48) or nil)
end)

-- ---------------------------------------------------------------------------
-- The hospital
-- ---------------------------------------------------------------------------

---@param source number
---@return number charged
local function chargeFee(source)
    local fee = math.floor(Config.RespawnFee or 0)
    if fee <= 0 then return 0 end

    for _, account in ipairs(Config.FeeAccounts or { 'bank' }) do
        if core:hasMoney(source, account, fee) then
            local ok = core:removeMoney(source, account, fee, 'hospital-treatment')
            if ok then return fee end
        end
    end

    -- Broke. Treated anyway, deliberately: a player pinned on the floor because
    -- they cannot afford to stand up is a player who logs off.
    return 0
end

lib.callback.register('som-medical:server:respawn', function(source)
    local cid = cidOf(source)
    if not cid then return { success = false, error = 'not loaded' } end

    local entry = downed[cid]
    if not entry then return { success = false, error = 'you are not down' } end

    -- The wait is enforced HERE. A client that skipped its own countdown would
    -- otherwise respawn instantly.
    local elapsed = os.time() - entry.since
    local required = Config.RespawnOfferedAfter or 120

    if elapsed < required then
        return { success = false, error = ('wait %d more seconds'):format(required - elapsed) }
    end

    local hospital = Config.Hospitals.pillbox
    if not hospital then return { success = false, error = 'no hospital configured' } end

    local charged = chargeFee(source)

    downed[cid] = nil
    core:setMetadata(source, 'downed', false)
    publish(source, false)

    TriggerEvent('som:server:playerRevived', source, cid, nil)

    return {
        success = true,
        charged = charged,
        health = Config.RespawnHealth or 150,
        coords = { x = hospital.coords.x, y = hospital.coords.y,
                   z = hospital.coords.z, w = hospital.coords.w },
        label = hospital.label,
    }
end)

-- ---------------------------------------------------------------------------
-- Nobody came
--
-- Checked on an interval rather than with a timer per player, so a full server
-- costs one loop instead of thirty-two.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)

        local limit = Config.ForceRespawnAfter or 600
        local now = os.time()

        for _, entry in pairs(downed) do
            -- Only to a source that is still that character.
            --
            -- Entries survive a disconnect on purpose, so without this check a
            -- body left by someone who logged off keeps firing at their old
            -- server id every five seconds forever. Server ids are recycled, so
            -- that eventually lands on somebody else: if the new holder is
            -- themselves down and past the offer window, the callback succeeds
            -- for them, and they are charged and teleported out of a scene
            -- eight minutes early by a timer belonging to a player who left.
            if entry.source and GetPlayerName(entry.source)
                and now - entry.since >= limit then
                -- Told to go, rather than moved from here: the client owns the
                -- camera and the fade, and it asks for the respawn itself so
                -- there is one code path in and not two.
                TriggerClientEvent('som-medical:client:forceRespawn', entry.source)
            end
        end
    end
end)

-- A player who disconnects while down STAYS down, because the table is keyed by
-- citizenid. Only the source is stale, so it is refreshed when they return.
--
-- The second argument is a CITIZENID STRING, not a player table. som-core emits
-- `som:server:playerLoaded(source, player.citizenid)` and its README documents
-- exactly that. This handler took `player` and read `player.citizenid`, which on
-- a string returns nil through the string metatable rather than erroring, so it
-- returned on the first line every single time and did so silently. Relogging
-- while down was therefore a free revive: no wait, no fee, and the character
-- left marked down in the table and in the database forever.
AddEventHandler('som:server:playerLoaded', function(source, citizenid)
    local entry = type(citizenid) == 'string' and downed[citizenid] or nil
    if not entry then return end

    entry.source = source

    core:setMetadata(source, 'downed', true)
    publish(source, true, entry.since)

    -- Elapsed is sent, not just `since`. The client has no server clock, so
    -- without this a player who reconnects while down watches their countdown
    -- restart at two minutes while the server, which counts from the original
    -- `since`, would have let them up immediately.
    TriggerClientEvent('som-medical:client:down', source, entry.since,
        os.time() - entry.since)
end)

-- The source goes stale the moment they leave; the ENTRY does not.
--
-- Clearing the source rather than the entry is the whole point: the character
-- is still down, so they come back down, but nothing addresses their old server
-- id in the meantime. Both the force-respawn loop and any future medic path
-- check for a live source before using one.
AddEventHandler('som:server:playerUnloaded', function(source, citizenid)
    reporting[source] = nil

    local entry = type(citizenid) == 'string' and downed[citizenid] or nil
    if not entry then return end

    entry.source = nil
end)
