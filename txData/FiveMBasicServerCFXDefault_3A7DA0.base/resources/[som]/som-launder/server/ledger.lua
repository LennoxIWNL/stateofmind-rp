--- The ledger of marked bills. An item in an inventory is only a pointer to a
--- row here: its metadata says which row, but the worth and the status that
--- count are the row's. A forged, duplicated or reused item therefore points at
--- nothing, or at a row that has already been washed.

local ox = exports.ox_inventory

Ledger = {}

---@param text string
function Ledger.Log(text)
    local url = GetConvar('som_launder_webhook', '')
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({ content = text }),
        { ['Content-Type'] = 'application/json' })
end

local function newUid()
    return ('%08X%08X'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
end

---Issues one marked bill per worth, straight into the player's inventory.
---Either every bill arrives or none do.
---@param source number
---@param worths number[]
---@param tag string where they came from, for the ledger
---@return string[]|nil uids, string|nil error
function Ledger.Mint(source, worths, tag)
    if type(worths) ~= 'table' or #worths < 1 or #worths > Config.Mint.maxBills then
        return nil, 'bad bill count'
    end

    for _, worth in ipairs(worths) do
        if math.type(worth) ~= 'integer' or worth < 1 or worth > Config.Mint.maxWorth then
            return nil, 'bad bill worth'
        end
    end

    local issued = {}

    local function rollback()
        for _, bill in ipairs(issued) do
            if bill.slot then ox:RemoveItem(source, Config.Item, 1, nil, bill.slot) end
            MySQL.update.await("UPDATE som_marked_bills SET status = 'void' WHERE uid = ? AND status = 'issued'", { bill.uid })
        end
    end

    for _, worth in ipairs(worths) do
        local uid = newUid()
        MySQL.insert.await('INSERT INTO som_marked_bills (uid, worth, source_tag) VALUES (?, ?, ?)', { uid, worth, tostring(tag):sub(1, 32) })
        local bill = { uid = uid }
        issued[#issued + 1] = bill

        if not ox:AddItem(source, Config.Item, 1, { uid = uid, worth = worth }) then
            rollback()
            return nil, 'could not carry the bills'
        end

        bill.slot = Ledger.SlotOf(source, uid)
    end

    local uids = {}
    for _, bill in ipairs(issued) do uids[#uids + 1] = bill.uid end
    Ledger.Log(('minted %d bills for %s (%s)'):format(#uids, tostring(source), tag))
    return uids
end

---The inventory slot holding the bill with this uid, or nil.
---@param source number
---@param uid string
---@return number|nil
function Ledger.SlotOf(source, uid)
    for _, slot in ipairs(ox:Search(source, 'slots', Config.Item) or {}) do
        if slot.metadata and slot.metadata.uid == uid then return slot.slot end
    end
end

---The ledger row for a uid, or nil.
---@param uid any
---@return table|nil
function Ledger.Get(uid)
    if type(uid) ~= 'string' or not uid:match('^%x+$') or #uid ~= 16 then return nil end
    return MySQL.single.await('SELECT worth, status FROM som_marked_bills WHERE uid = ?', { uid })
end

exports('mintBills', Ledger.Mint)
