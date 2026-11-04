--- Which phone is this, and is it open. A phone item carries an imei that the
--- SERVER writes and reads back, so the item is a pointer to a row here. The
--- lock is a salted hash with a pepper from a convar, and a wrong passcode five
--- times locks the phone for a short while.

local ox = exports.ox_inventory

local fails = {}   -- imei -> { count, lockedUntil }. Short lived, so a restart clearing it is fine.
local seen = {}    -- imei -> { source, at }, to notice a duplicated item

local function newImei()
    return ('%08X%08X'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
end

local function pepper() return GetConvar('som_phone_pepper', '') end

---@param passcode string
---@param salt string
---@return string
local function digest(passcode, salt)
    return MySQL.scalar.await('SELECT SHA2(CONCAT(?, ?, ?), 256)', { salt, pepper(), passcode })
end

---The phone the player is holding, creating its imei on first use.
---@param source number
---@param player table
---@return table|nil device, string|nil error
function Phone.DeviceFor(source, player)
    local imei

    if Config.RequireItem and GetResourceState('ox_inventory') == 'started' then
        local slots = ox:Search(source, 'slots', Config.Item) or {}
        local slot = slots[1]
        if not slot then return nil, 'You do not have a phone' end

        imei = slot.metadata and slot.metadata.imei

        if not imei then
            imei = newImei()
            local metadata = {}
            for k, v in pairs(slot.metadata or {}) do metadata[k] = v end
            metadata.imei = imei
            ox:SetMetadata(source, slot.slot, metadata)

            -- Read back, so a write the inventory refused is not trusted.
            local again = ox:Search(source, 'slots', Config.Item) or {}
            if not (again[1] and again[1].metadata and again[1].metadata.imei == imei) then
                return nil, 'This phone cannot be set up'
            end
        end
    else
        imei = 'C' .. player.citizenid
    end

    local row = MySQL.single.await('SELECT imei, pass_hash FROM som_phone_devices WHERE imei = ?', { imei })
    if not row then
        MySQL.insert.await('INSERT INTO som_phone_devices (imei) VALUES (?)', { imei })
        row = { imei = imei }
    end

    local last = seen[imei]
    if last and last.source ~= source and os.time() - last.at < 120
        and GetPlayerPed(last.source) ~= 0 and GetPlayerPed(last.source) ~= nil then
        MySQL.insert.await('INSERT INTO som_phone_audit (citizenid, app, action, ok) VALUES (?, ?, ?, 0)',
            { player.citizenid, 'system', 'duplicate imei' })
    end
    seen[imei] = { source = source, at = os.time() }

    return row
end

---@param source number
---@param device table
---@return boolean
function Phone.IsLocked(source, device)
    if not device.pass_hash then return false end
    return Phone.unlocked[source] ~= device.imei
end

---@param source number
---@param player table
---@param device table
---@param action string
---@param payload table
---@return table
function Phone.System(source, player, device, action, payload)
    if action == 'lock' then
        Phone.unlocked[source] = nil
        return { success = true }
    end

    if action == 'unlock' then
        if not device.pass_hash then return { success = true } end

        local state = fails[device.imei]
        if state and state.lockedUntil and os.time() < state.lockedUntil then
            return { success = false, error = 'Try again shortly', wait = state.lockedUntil - os.time() }
        end

        local code = payload.passcode
        local salt = MySQL.scalar.await('SELECT pass_salt FROM som_phone_devices WHERE imei = ?', { device.imei })
        if type(code) ~= 'string' or not code:match('^%d%d%d%d$') or not salt
            or digest(code, salt) ~= device.pass_hash then
            state = state or { count = 0 }
            state.count = state.count + 1

            if state.count >= Config.Lock.failsBeforeLock then
                state.count = 0
                state.lockedUntil = os.time() + Config.Lock.lockSeconds
            end

            fails[device.imei] = state
            return { success = false, error = 'Wrong passcode' }
        end

        fails[device.imei] = nil
        Phone.unlocked[source] = device.imei
        return { success = true }
    end

    return Phone.Open(source, player, device)
end

---Sets, changes or clears the passcode. The phone must be open.
---@param source number
---@param payload table { passcode, current }
---@return table
function Phone.SetPasscode(source, payload, player)
    local player = player
    local device = Phone.DeviceFor(source, player)
    if not device then return { success = false, error = 'no phone' } end

    local code = payload.passcode
    if code ~= nil and (type(code) ~= 'string' or not code:match('^%d%d%d%d$')) then
        return { success = false, error = 'Use four digits' }
    end

    if code == nil then
        MySQL.update.await('UPDATE som_phone_devices SET pass_hash = NULL, pass_salt = NULL WHERE imei = ?', { device.imei })
        Phone.unlocked[source] = nil
        return { success = true }
    end

    local salt = newImei():sub(1, 12)
    MySQL.update.await('UPDATE som_phone_devices SET pass_hash = ?, pass_salt = ? WHERE imei = ?',
        { digest(code, salt), salt, device.imei })

    Phone.unlocked[source] = device.imei
    return { success = true }
end

AddEventHandler('playerDropped', function()
    local source = source
    for imei, last in pairs(seen) do
        if last.source == source then seen[imei] = nil end
    end
end)

CreateThread(function()
    Wait(3000)
    if pepper() == '' then
        print('[som-phone] som_phone_pepper is not set: passcodes are salted but not peppered (LAUNCH-TODO.md)')
    end
end)
