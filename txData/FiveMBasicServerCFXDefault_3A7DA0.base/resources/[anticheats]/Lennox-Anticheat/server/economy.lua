-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Advanced Economy Protection
--  Transaction signing, money source validation, inventory consistency,
--  duplicate transaction detection, item dupe detection
-- =========================================================================

local cfg = LACConfig

-- =========================================================================
--  1. Transaction Signing System
--  Server-generated nonce per money operation, single-use, 30s expiry
-- =========================================================================
local TransactionNonces = {}  -- src -> { nonce -> {issuedAt, source, maxAmount} }

function LAC.issueTransactionNonce(src, source_name, maxAmount)
    if not cfg.TransactionSigningEnabled then return nil end
    src = tonumber(src)
    if not src then return nil end

    math.randomseed(GetGameTimer() + src + math.random(1, 10000))
    local nonce = ('%08X-%08X'):format(math.random(0, 0x7FFFFFFF), math.random(0, 0x7FFFFFFF))

    if not TransactionNonces[src] then TransactionNonces[src] = {} end
    TransactionNonces[src][nonce] = {
        issuedAt  = GetGameTimer(),
        source    = source_name,
        maxAmount = maxAmount or (cfg.JobMaxPerTx or 5000),
    }

    return nonce
end

function LAC.validateTransaction(src, nonce, amount, source_name)
    if not cfg.TransactionSigningEnabled then return true end
    src = tonumber(src)
    if not src then return false end
    if LAC.isAdmin(src) then return true end

    if not nonce or not TransactionNonces[src] then
        LAC.flagPlayer(src, 'Unsigned Transaction',
            ('Source: %s, Amount: %s'):format(tostring(source_name), tostring(amount)), 10, true)
        return false
    end

    local entry = TransactionNonces[src][nonce]
    if not entry then
        LAC.flagPlayer(src, 'Invalid Transaction Nonce',
            ('Nonce: %s'):format(tostring(nonce):sub(1, 20)), 10, true)
        return false
    end

    TransactionNonces[src][nonce] = nil

    local expiry = (cfg.TransactionNonceExpiry or 30) * 1000
    if (GetGameTimer() - entry.issuedAt) > expiry then
        LAC.flagPlayer(src, 'Expired Transaction Nonce',
            ('Expired after %ds'):format((GetGameTimer() - entry.issuedAt) / 1000), 5, false)
        return false
    end

    amount = tonumber(amount) or 0
    if amount > entry.maxAmount then
        LAC.flagPlayer(src, 'Transaction Amount Exceeded',
            ('Amount: $%d (max: $%d)'):format(amount, entry.maxAmount), 10, true)
        return false
    end

    return true
end

-- Nonce expiry cleanup
CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        local expiry = (cfg.TransactionNonceExpiry or 30) * 1000
        for src, nonces in pairs(TransactionNonces) do
            for nonce, entry in pairs(nonces) do
                if (now - entry.issuedAt) > expiry * 2 then
                    nonces[nonce] = nil
                end
            end
        end
    end
end)

-- =========================================================================
--  2. Money Source Validation
--  Per-source limits: job max $5000/tx, max $50000/30min
-- =========================================================================
local MoneySourceTrack = {}

function LAC.validateMoneySource(src, source_name, amount)
    src = tonumber(src)
    if not src then return false end
    if LAC.isAdmin(src) then return true end
    amount = tonumber(amount) or 0

    if not MoneySourceTrack[src] then MoneySourceTrack[src] = {} end
    if not MoneySourceTrack[src][source_name] then
        MoneySourceTrack[src][source_name] = { entries = {}, total30 = 0 }
    end

    local track = MoneySourceTrack[src][source_name]
    local now = GetGameTimer()

    -- Per-transaction limit
    local maxTx = cfg.JobMaxPerTx or 5000
    if amount > maxTx then
        LAC.flagPlayer(src, 'Money Source Limit (tx)',
            ('Source: %s | $%d (max $%d/tx)'):format(source_name, amount, maxTx), 10, true)
        LAC.sendDiscord('bans', 'MONEY EXPLOIT — TRANSACTION LIMIT',
            ('**Player:** %s (id: %s)\n**Source:** %s\n**Amount:** $%d (max $%d)')
                :format(GetPlayerName(src) or '?', src, source_name, amount, maxTx), 16711680, true)
        return false
    end

    -- Prune entries older than 30 min
    local windowMs = 1800000
    local pruned = {}
    local rollingTotal = 0
    for _, e in ipairs(track.entries) do
        if (now - e.time) < windowMs then
            pruned[#pruned + 1] = e
            rollingTotal = rollingTotal + e.amount
        end
    end
    track.entries = pruned
    track.total30 = rollingTotal

    -- 30-min rolling limit
    local max30 = cfg.JobMaxPer30Min or 50000
    if track.total30 + amount > max30 then
        LAC.flagPlayer(src, 'Money Source Limit (30min)',
            ('Source: %s | $%d + $%d (max $%d/30min)'):format(source_name, track.total30, amount, max30), 10, true)
        LAC.sendDiscord('bans', 'MONEY EXPLOIT — RATE LIMIT',
            ('**Player:** %s (id: %s)\n**Source:** %s\n**30min total:** $%d + $%d (max $%d)')
                :format(GetPlayerName(src) or '?', src, source_name, track.total30, amount, max30), 16711680, true)
        return false
    end

    -- Record this transaction
    track.entries[#track.entries + 1] = { amount = amount, time = now }
    track.total30 = track.total30 + amount

    -- Feed behavioral engine
    if LAC.recordEarning then
        LAC.recordEarning(src, source_name, amount)
    end

    return true
end

-- =========================================================================
--  3. Duplicate Transaction Detection
--  hash(amount + source + 10s bucket) — same hash twice = hard 15
-- =========================================================================
local TxHashLog = {}

function LAC.checkDuplicateTransaction(src, amount, source_name)
    if not cfg.DupeDetectionEnabled then return false end
    src = tonumber(src)
    if not src then return false end
    if LAC.isAdmin(src) then return false end

    local bucket = math.floor(GetGameTimer() / 10000)
    local hashStr = ('%s:%s:%d:%d'):format(tostring(src), tostring(source_name), tonumber(amount) or 0, bucket)

    local h = 0x5A3C
    for i = 1, #hashStr do h = (h * 33 + string.byte(hashStr, i)) % 0x7FFFFFFF end
    local hashKey = ('%08x'):format(h)

    if TxHashLog[hashKey] then
        LAC.flagPlayer(src, 'Duplicate Transaction',
            ('Source: %s | Amount: $%s | Hash: %s'):format(source_name, tostring(amount), hashKey), 15, true)
        LAC.sendDiscord('bans', 'DUPLICATE TRANSACTION DETECTED',
            ('**Player:** %s (id: %s)\n**Source:** %s\n**Amount:** $%s\n**Hash:** `%s`\n**Verdict:** Same transaction hash appeared twice in 10s window.')
                :format(GetPlayerName(src) or '?', src, source_name, tostring(amount), hashKey), 16711680, true)
        return true
    end

    TxHashLog[hashKey] = GetGameTimer()
    return false
end

-- Cleanup old hashes
CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        for hash, time in pairs(TxHashLog) do
            if (now - time) > 30000 then TxHashLog[hash] = nil end
        end
    end
end)

-- =========================================================================
--  4. Inventory Consistency
--  Snapshot on open, compare on close
-- =========================================================================
local InventorySnapshots = {}

function LAC.snapshotInventory(src, items)
    src = tonumber(src)
    if not src then return end
    InventorySnapshots[src] = {
        items = items or {},
        time = GetGameTimer(),
    }
end

function LAC.validateInventoryClose(src, currentItems)
    src = tonumber(src)
    if not src then return true end
    if LAC.isAdmin(src) then return true end

    local snap = InventorySnapshots[src]
    if not snap then return true end
    InventorySnapshots[src] = nil

    if type(snap.items) ~= 'table' or type(currentItems) ~= 'table' then return true end

    local snapCounts = {}
    for _, item in ipairs(snap.items) do
        local k = tostring(item.name or item.slot or '')
        snapCounts[k] = (snapCounts[k] or 0) + (tonumber(item.amount) or 1)
    end

    for _, item in ipairs(currentItems) do
        local k = tostring(item.name or item.slot or '')
        local snapAmt = snapCounts[k] or 0
        local curAmt = tonumber(item.amount) or 1
        if curAmt > snapAmt + 10 then
            LAC.flagPlayer(src, 'Inventory Anomaly',
                ('Item: %s increased %d→%d without server add'):format(k:sub(1, 30), snapAmt, curAmt), 10, true)
            return false
        end
    end

    return true
end

-- =========================================================================
--  5. Item Dupe Detection
--  Same serial in two inventories = hard 20
-- =========================================================================
local SerialTracker = {}

function LAC.trackItemSerial(src, serial, itemName)
    if not serial or serial == '' then return end
    src = tonumber(src)
    if not src then return end

    if SerialTracker[serial] and SerialTracker[serial] ~= src then
        LAC.flagPlayer(src, 'Item Duplication',
            ('Item: %s | Serial: %s also in player %d'):format(
                tostring(itemName):sub(1, 30), tostring(serial):sub(1, 20), SerialTracker[serial]), 20, true)
        LAC.sendDiscord('bans', 'ITEM DUPLICATION DETECTED',
            ('**Player:** %s (id: %s)\n**Item:** %s\n**Serial:** `%s`\n**Also held by:** id %d\n**Verdict:** Same serial number found in two inventories.')
                :format(GetPlayerName(src) or '?', src, tostring(itemName), tostring(serial),
                    SerialTracker[serial]), 16711680, true)
    end

    SerialTracker[serial] = src
end

-- =========================================================================
--  Exports
-- =========================================================================
exports('IssueTransactionNonce', function(src, source_name, maxAmount) return LAC.issueTransactionNonce(src, source_name, maxAmount) end)
exports('ValidateTransaction', function(src, nonce, amount, source_name) return LAC.validateTransaction(src, nonce, amount, source_name) end)
exports('ValidateMoneySource', function(src, source_name, amount) return LAC.validateMoneySource(src, source_name, amount) end)
exports('CheckDuplicateTransaction', function(src, amount, source_name) return LAC.checkDuplicateTransaction(src, amount, source_name) end)
exports('SnapshotInventory', function(src, items) LAC.snapshotInventory(src, items) end)
exports('ValidateInventoryClose', function(src, items) return LAC.validateInventoryClose(src, items) end)
exports('TrackItemSerial', function(src, serial, itemName) LAC.trackItemSerial(src, serial, itemName) end)

-- Cleanup
AddEventHandler('playerDropped', function()
    local src = source
    TransactionNonces[src] = nil
    MoneySourceTrack[src] = nil
    InventorySnapshots[src] = nil
end)
