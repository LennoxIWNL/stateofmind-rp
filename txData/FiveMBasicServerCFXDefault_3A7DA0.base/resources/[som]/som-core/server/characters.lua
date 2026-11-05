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

    local rows = MySQL.query.await([[
        SELECT c.citizenid, c.slot, c.firstname, c.lastname, c.dob, c.gender,
               c.nationality, c.job, c.job_grade, c.gang, c.last_played,
               -- The selector needs this to dress its preview ped. Without it
               -- every character stood in the shell wearing the freemode
               -- default, whatever they actually look like.
               c.appearance,
               m.cash, m.bank
        FROM som_characters c
        LEFT JOIN som_character_money m ON m.citizenid = c.citizenid
        WHERE c.license = ? AND c.deleted = 0
        ORDER BY c.slot
    ]], { license }) or {}

    -- Same reason as SomFormatDate: the selector renders this directly, and a
    -- raw DATE arrives as epoch milliseconds.
    for _, row in ipairs(rows) do row.dob = SomFormatDate(row.dob) end

    return rows
end

---Collapses whitespace and strips control characters, then checks the length.
---@param text any
---@return string|nil clean, string|nil err
function Characters.ValidateBackstory(text)
    if type(text) ~= 'string' then return nil, 'a backstory is required' end

    local clean = text:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if #clean < Config.Characters.backstoryMin then
        return nil, ('your backstory needs at least %d characters'):format(Config.Characters.backstoryMin)
    end

    return clean:sub(1, Config.Characters.backstoryMax)
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

    local backstory, storyErr = Characters.ValidateBackstory(data.backstory)
    if not backstory then return false, storyErr end

    local metadata = {}
    for k, v in pairs(Config.DefaultMetadata) do metadata[k] = v end
    metadata.backstory = backstory

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
        json.encode(metadata),
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

    -- Welcome gift, once per character, and only AFTER som:server:playerLoaded.
    --
    -- ox_inventory's som bridge builds the player's inventory on that event, so
    -- anything handed over before it is written into an inventory that does not
    -- exist yet and is silently lost. The flag is set only once something has
    -- actually landed, so a failure here is retried on the next login rather
    -- than marking the character welcomed forever.
    if not player.metadata.welcomed then
        Characters.GiveWelcomeGift(source)
    end

    return true
end

---Hands a new character their starter items.
---
---Runs in its own thread and waits for ox_inventory to finish building the
---player's inventory. setPlayerInventory loads from the database, so the
---inventory does not exist the instant som:server:playerLoaded fires and an
---AddItem before then goes nowhere.
---
---Missing items are skipped with a warning rather than aborting: an item name
---that does not exist in ox_inventory should not stop the rest of the gift, or
---one typo leaves new players with nothing.
---@param source number
function Characters.GiveWelcomeGift(source)
    local gift = Config.Characters.welcomeGift
    if not gift or #gift == 0 then return end

    if GetResourceState('ox_inventory') ~= 'started' then
        print('[som-core] ox_inventory is not running, welcome gift skipped')
        return
    end

    CreateThread(function()
        -- Bounded wait. If the inventory never appears the gift is skipped and
        -- the character stays unwelcomed, so the next login tries again.
        local ready = false
        for _ = 1, 40 do
            local ok, inv = pcall(function()
                return exports.ox_inventory:GetInventory(source)
            end)

            if ok and inv then
                ready = true
                break
            end

            Wait(250)
        end

        local player = Players.Get(source)
        if not player then return end

        if not ready then
            print(('[som-core] welcome gift: inventory never loaded for %s, will retry next login')
                :format(player.citizenid))
            return
        end

        local given = 0
        for _, entry in ipairs(gift) do
            -- AddItem returns false rather than raising when an item is unknown
            -- or the inventory is full, so the return value is what matters
            -- here. pcall alone would report every failure as a success.
            local ok, added = pcall(function()
                return exports.ox_inventory:AddItem(source, entry.item, entry.count)
            end)

            if ok and added then
                given = given + 1
            else
                print(('[som-core] welcome gift: %s could not be given to %s')
                    :format(entry.item, player.citizenid))
            end
        end

        if given == 0 then
            print(('[som-core] welcome gift: nothing given to %s, not marking welcomed')
                :format(player.citizenid))
            return
        end

        player:setMetadata('welcomed', true)

        TriggerClientEvent('som:client:notify', source,
            'You have received a gift', 'success', 8000)
    end)
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
