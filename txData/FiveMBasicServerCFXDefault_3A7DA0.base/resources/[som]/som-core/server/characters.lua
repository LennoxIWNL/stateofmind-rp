-- Character slots, creation, selection, deletion.
--
-- These are the only client-reachable entry points in som-core, so every one
-- of them re-derives identity from the source rather than trusting the payload.
-- A client never sends its own license or citizenid: the server looks both up.

Characters = {}

local NAME_PATTERN = "^[%a][%a'%-% ]*$"

---@param source number
---@return string|nil license identifier
local function getLicense(source)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

---@return string unique citizen id
local function generateCitizenId()
    for _ = 1, 20 do
        local id = ('%s%s'):format(
            string.char(math.random(65, 90), math.random(65, 90)),
            math.random(10000000, 99999999)
        )
        local exists = MySQL.scalar.await('SELECT 1 FROM som_characters WHERE citizenid = ?', { id })
        if not exists then return id end
    end
    error('som-core: could not generate a unique citizenid after 20 attempts')
end

---Validates a name field from the client.
---@param value any
---@return string|nil cleaned, string|nil err
local function validateName(value)
    if type(value) ~= 'string' then return nil, 'name must be text' end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #trimmed < 2 or #trimmed > 24 then return nil, 'name must be 2 to 24 characters' end
    if not trimmed:match(NAME_PATTERN) then return nil, 'name contains invalid characters' end

    return trimmed
end

---Age on a given date, in whole years.
---@param year number
---@param month number
---@param day number
---@return number
local function ageFrom(year, month, day)
    local now = os.date('*t')
    local age = now.year - year

    -- Not had their birthday yet this year.
    if now.month < month or (now.month == month and now.day < day) then
        age = age - 1
    end

    return age
end

---@param value any
---@return string|nil iso date, string|nil err
local function validateDob(value)
    if type(value) ~= 'string' then return nil, 'date of birth must be text' end

    local year, month, day = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
    if not year then return nil, 'date of birth must be YYYY-MM-DD' end

    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if month < 1 or month > 12 or day < 1 or day > 31 then return nil, 'invalid date' end

    -- Reject impossible dates such as 31 February, which the pattern above
    -- happily accepts.
    local stamp = os.time({ year = year, month = month, day = day, hour = 12 })
    local check = os.date('*t', stamp)
    if check.year ~= year or check.month ~= month or check.day ~= day then
        return nil, 'that date does not exist'
    end

    local age = ageFrom(year, month, day)

    -- Enforced server side, not just in the date picker. The client cannot be
    -- trusted to police this, and characters under 18 are not permitted.
    if age < Config.Characters.minimumAge then
        return nil, ('characters must be at least %d years old'):format(Config.Characters.minimumAge)
    end
    if age > Config.Characters.maximumAge then
        return nil, ('characters must be under %d years old'):format(Config.Characters.maximumAge)
    end

    return ('%04d-%02d-%02d'):format(year, month, day)
end

---@param source number
---@return table[] character rows for this license
function Characters.List(source)
    local license = getLicense(source)
    if not license then return {} end

    return MySQL.query.await([[
        SELECT c.citizenid, c.slot, c.firstname, c.lastname, c.dob, c.gender,
               c.nationality, c.job, c.job_grade, c.gang, c.last_played,
               m.cash, m.bank
        FROM som_characters c
        LEFT JOIN som_character_money m ON m.citizenid = c.citizenid
        WHERE c.license = ? AND c.deleted = 0
        ORDER BY c.slot
    ]], { license }) or {}
end

---@param source number
---@param data table client supplied character fields
---@return boolean success, string|nil err
function Characters.Create(source, data)
    if type(data) ~= 'table' then return false, 'invalid payload' end

    local license = getLicense(source)
    if not license then return false, 'could not identify player' end

    -- The cap is per player and resolved server side. A client deciding its
    -- own limit could create characters in slots it has not earned.
    local maxSlots = Entitlements.GetSlots(source)

    local slot = tonumber(data.slot)
    if not slot or slot % 1 ~= 0 or slot < 1 or slot > maxSlots then
        return false, 'invalid slot'
    end

    local taken = MySQL.scalar.await(
        'SELECT 1 FROM som_characters WHERE license = ? AND slot = ? AND deleted = 0',
        { license, slot }
    )
    if taken then return false, 'slot already in use' end

    local firstname, err = validateName(data.firstname)
    if not firstname then return false, err end

    local lastname, lastErr = validateName(data.lastname)
    if not lastname then return false, lastErr end

    local dob, dobErr = validateDob(data.dob)
    if not dob then return false, dobErr end

    local gender = tonumber(data.gender)
    if gender ~= 0 and gender ~= 1 then return false, 'invalid gender' end

    local nationality = type(data.nationality) == 'string' and data.nationality:sub(1, 32) or 'Unknown'

    local citizenid = generateCitizenId()
    local phone = ('%03d-%04d'):format(math.random(100, 999), math.random(1000, 9999))

    MySQL.insert.await([[
        INSERT INTO som_users (license, last_name) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE last_seen = CURRENT_TIMESTAMP
    ]], { license, GetPlayerName(source) })

    MySQL.insert.await([[
        INSERT INTO som_characters
            (citizenid, license, slot, firstname, lastname, dob, gender, nationality, phone, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, license, slot, firstname, lastname, dob, gender, nationality, phone,
        json.encode(Config.DefaultMetadata),
    })

    -- Starting funds are a faucet and are ledgered like any other, so the very
    -- first money a character owns is already auditable.
    MySQL.insert.await(
        'INSERT INTO som_character_money (citizenid, cash, bank) VALUES (?, ?, ?)',
        { citizenid, Config.Characters.startingCash, Config.Characters.startingBank }
    )
    MySQL.insert.await([[
        INSERT INTO som_transactions
            (citizenid, account, amount, balance, direction, flow, reason, resource)
        VALUES (?, 'cash', ?, ?, 'credit', 'faucet', 'character-creation', 'som-core'),
               (?, 'bank', ?, ?, 'credit', 'faucet', 'character-creation', 'som-core')
    ]], {
        citizenid, Config.Characters.startingCash, Config.Characters.startingCash,
        citizenid, Config.Characters.startingBank, Config.Characters.startingBank,
    })

    return true, citizenid
end

---Loads a character and makes it the player's active one.
---@param source number
---@param citizenid string
---@return boolean success, string|nil err
function Characters.Select(source, citizenid)
    if type(citizenid) ~= 'string' then return false, 'invalid character' end

    local license = getLicense(source)
    if not license then return false, 'could not identify player' end

    -- The license check is what stops a client selecting somebody else's
    -- character by sending an arbitrary citizenid.
    local row = MySQL.single.await([[
        SELECT * FROM som_characters WHERE citizenid = ? AND license = ? AND deleted = 0
    ]], { citizenid, license })
    if not row then return false, 'character not found' end

    if Players.GetByCitizenId(citizenid) then return false, 'character already in use' end

    local money = MySQL.single.await(
        'SELECT cash, bank, crypto, dirty FROM som_character_money WHERE citizenid = ?',
        { citizenid }
    )

    local player = Players.Create(source, row, money)

    MySQL.update.await('UPDATE som_users SET last_seen = CURRENT_TIMESTAMP, last_ip = ? WHERE license = ?', {
        GetPlayerEndpoint(source), license,
    })

    TriggerEvent('som:server:playerLoaded', source, player.citizenid)
    TriggerClientEvent('som:client:playerLoaded', source, {
        citizenid = player.citizenid,
        charinfo = player.charinfo,
        job = player.job,
        gang = player.gang,
        money = player.money,
        metadata = player.metadata,
        position = player.position or Config.Characters.defaultSpawn,
    })

    return true
end

---Soft delete. The row is kept so the ledger keeps referential integrity.
---@param source number
---@param citizenid string
---@return boolean success, string|nil err
function Characters.Delete(source, citizenid)
    if type(citizenid) ~= 'string' then return false, 'invalid character' end

    local license = getLicense(source)
    if not license then return false, 'could not identify player' end

    local owned = MySQL.scalar.await(
        'SELECT 1 FROM som_characters WHERE citizenid = ? AND license = ?',
        { citizenid, license }
    )
    if not owned then return false, 'character not found' end

    local active = Players.GetByCitizenId(citizenid)
    if active then return false, 'character is currently loaded' end

    -- Clearing slot frees it for reuse. The row itself survives so the
    -- transaction ledger keeps referential integrity.
    MySQL.update.await(
        'UPDATE som_characters SET deleted = 1, slot = NULL WHERE citizenid = ?',
        { citizenid }
    )

    return true
end

-- ---------------------------------------------------------------------------
-- Client entry points
-- ---------------------------------------------------------------------------

lib.callback.register('som:server:getCharacters', function(source)
    return Characters.List(source)
end)

lib.callback.register('som:server:createCharacter', function(source, data)
    local ok, result = Characters.Create(source, data)
    if not ok then return { success = false, error = result } end
    return { success = true, citizenid = result }
end)

lib.callback.register('som:server:selectCharacter', function(source, citizenid)
    local ok, err = Characters.Select(source, citizenid)
    return { success = ok, error = err }
end)

lib.callback.register('som:server:deleteCharacter', function(source, citizenid)
    local ok, err = Characters.Delete(source, citizenid)
    return { success = ok, error = err }
end)
