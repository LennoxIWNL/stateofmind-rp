-- Appearance persistence and authority.
--
-- The client renders and previews. It does not decide what it is allowed to
-- change, what that costs, or what ends up stored.

local SECTION_KEYS = {
    heritage = { 'headBlend' },
    features = { 'faceFeatures' },
    hair     = { 'hair' },
    overlays = { 'headOverlays' },
    apparel  = { 'components', 'props' },
}

---@param source number
---@return table|nil player, table|nil appearance
local function load(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    local raw = MySQL.scalar.await(
        'SELECT appearance FROM som_characters WHERE citizenid = ?', { player.citizenid })

    if not raw then return player, nil end

    local ok, decoded = pcall(json.decode, raw)
    return player, (ok and type(decoded) == 'table') and decoded or nil
end

lib.callback.register('som-appearance:server:get', function(source)
    local player, appearance = load(source)
    if not player then return nil end

    return {
        appearance = appearance,
        gender = player.charinfo and player.charinfo.gender or 0,
    }
end)

---Merges only the sections a scope permits, over what is already stored.
---
---This is the security boundary. The client sends a whole appearance table
---because that is what it is holding, but a barber may not change what a
---player is wearing and a clothing shop may not change their face. Anything
---outside the scope is taken from the STORED record and the submitted value is
---discarded, so an edited request changes nothing it was not allowed to.
---@param stored table|nil
---@param submitted table
---@param scope string
---@return table merged, string[] changed section names
local function merge(stored, submitted, scope)
    local allowed = Config.Scopes[scope]
    if not allowed then return stored or {}, {} end

    local base = stored and json.decode(json.encode(stored)) or {}
    local changed = {}

    for _, section in ipairs(allowed) do
        for _, key in ipairs(SECTION_KEYS[section] or {}) do
            if submitted[key] ~= nil then
                -- Compared before assignment so a section that was opened but
                -- not touched is not charged for.
                if json.encode(base[key]) ~= json.encode(submitted[key]) then
                    changed[#changed + 1] = section
                end
                base[key] = submitted[key]
            end
        end
    end

    -- Model and gender only ever move during creation. Letting a barber change
    -- them would make the whole scope system pointless.
    if scope == 'creator' then
        base.model = submitted.model
        base.gender = submitted.gender
        base.eyeColour = submitted.eyeColour
    elseif submitted.eyeColour ~= nil and Config.Scopes[scope] then
        for _, section in ipairs(allowed) do
            if section == 'heritage' then base.eyeColour = submitted.eyeColour end
        end
    end

    -- Deduplicate: heritage and features can both report through the same
    -- section name, and nobody should be charged twice for one visit.
    local seen, unique = {}, {}
    for _, section in ipairs(changed) do
        if not seen[section] then
            seen[section] = true
            unique[#unique + 1] = section
        end
    end

    return base, unique
end

---@param changed string[]
---@return number
local function priceFor(changed)
    local total = 0
    for _, section in ipairs(changed) do
        total = total + (Config.Pricing.sections[section] or 0)
    end
    return total
end

lib.callback.register('som-appearance:server:save', function(source, data)
    if type(data) ~= 'table' or type(data.appearance) ~= 'table' then
        return { success = false, error = 'invalid request' }
    end

    local scope = type(data.scope) == 'string' and data.scope or 'creator'
    if not Config.Scopes[scope] then return { success = false, error = 'unknown scope' } end

    local player, stored = load(source)
    if not player then return { success = false, error = 'not loaded' } end

    local merged, changed = merge(stored, data.appearance, scope)

    -- Creation is free: nothing has been earned yet, and charging for it would
    -- just be a tax on starting.
    local price = scope == 'creator' and 0 or priceFor(changed)

    if price > 0 then
        local paid = exports['som-core']:removeMoney(source, Config.Pricing.account, price,
            ('appearance:%s'):format(scope))

        if not paid then
            return { success = false, error = ('you need $%d'):format(price) }
        end
    end

    MySQL.update.await('UPDATE som_characters SET appearance = ? WHERE citizenid = ?',
        { json.encode(merged), player.citizenid })

    -- A face that can change silently is a face that cannot be investigated.
    -- Nothing reads this yet; som-police and the MDT will.
    if Config.LogFaceChanges then
        for _, section in ipairs(changed) do
            if section == 'heritage' or section == 'features' then
                MySQL.insert.await([[
                    INSERT INTO som_appearance_log (citizenid, scope, section, price)
                    VALUES (?, ?, ?, ?)
                ]], { player.citizenid, scope, section, price })
            end
        end
    end

    return { success = true, price = price, changed = changed }
end)

---Other resources need to know what a character looks like without loading
---them: mugshots, and clothing shops offering an outfit preview.
exports('getAppearance', function(citizenid)
    if type(citizenid) ~= 'string' then return nil end

    local raw = MySQL.scalar.await(
        'SELECT appearance FROM som_characters WHERE citizenid = ?', { citizenid })
    if not raw then return nil end

    local ok, decoded = pcall(json.decode, raw)
    return ok and decoded or nil
end)
