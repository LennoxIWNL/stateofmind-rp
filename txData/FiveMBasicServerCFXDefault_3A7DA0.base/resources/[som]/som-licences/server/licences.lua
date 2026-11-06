local core = exports['som-core']

Licences = {}

local function truthy(v) return v == true or v == 1 end

---@return 'valid'|'suspended'|'revoked'
local function stateOf(row)
    if truthy(row.revoked) then return 'revoked' end
    if truthy(row.suspended) then return 'suspended' end
    return 'valid'
end

---The database is the only authority; a suspension ends when its timestamp passes.
---@param citizenid string
---@return table<string, { state: string, until: string|nil }>
function Licences.Status(citizenid)
    local rows = MySQL.query.await([[
        SELECT type, revoked, suspended_until IS NOT NULL AND suspended_until > NOW() AS suspended,
               DATE_FORMAT(suspended_until, '%Y-%m-%d %H:%i') AS until_at
        FROM som_licenses WHERE citizenid = ?
    ]], { citizenid }) or {}

    local out = {}
    for _, row in ipairs(rows) do
        if Config.types[row.type] then
            out[row.type] = { state = stateOf(row), ['until'] = truthy(row.suspended) and row.until_at or nil }
        end
    end

    return out
end

---Rewrites metadata.licenses (read by ox_inventory and ps-mdt) from the table.
---Only writes when something differs, which is what stops the
---metadataChanged handler below from looping.
function Licences.Sync(source)
    local player = core:getPlayer(source)
    if not player then return end

    local status = Licences.Status(player.citizenid)
    local current = core:getMetadata(source, 'licenses')
    current = type(current) == 'table' and current or {}

    local changed = false
    for kind in pairs(Config.types) do
        local valid = status[kind] ~= nil and status[kind].state == 'valid'
        if (current[kind] == true) ~= valid then
            current[kind] = valid
            changed = true
        end
    end

    if changed then core:setMetadata(source, 'licenses', current) end
end

---Claims the licence, hands over the card and takes the fee. Anything that
---fails undoes what came before it.
---@param source number
---@param kind string
---@param fee number
---@param credit fun(amount: number, reason: string): boolean
---@param issuer string|nil citizenid of the approving officer
---@return boolean ok, string|nil err
function Licences.Issue(source, kind, fee, credit, issuer)
    local player = core:getPlayer(source)
    local def = Config.types[kind]
    if not player or not def then return false, 'not available' end

    local cid = player.citizenid

    local claimed = MySQL.update.await([[
        INSERT INTO som_licenses (citizenid, type, issued_by)
        SELECT ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_licenses WHERE citizenid = ? AND type = ?)
    ]], { cid, kind, issuer or 'school', cid, kind })
    if not claimed or claimed < 1 then return false, 'you already hold or have lost this licence' end

    local function unclaim()
        MySQL.update.await('DELETE FROM som_licenses WHERE citizenid = ? AND type = ? AND revoked = 0 AND suspended_until IS NULL', { cid, kind })
    end

    if not exports.ox_inventory:AddItem(source, def.item, 1) then
        unclaim()
        return false, 'you have no room for the card'
    end

    local function undo()
        exports.ox_inventory:RemoveItem(source, def.item, 1)
        unclaim()
    end

    local reason = 'licence:' .. kind
    local paid, payErr = core:removeMoney(source, 'bank', fee, reason)
    if not paid then
        undo()
        return false, payErr or ('you need $%d in the bank'):format(fee)
    end

    if not credit(fee, reason) then
        core:addMoney(source, 'bank', fee, reason .. ':refund')
        undo()
        return false, 'the fee could not be taken, nothing was charged'
    end

    Licences.Sync(source)
    return true
end

AddEventHandler('som:server:playerLoaded', function(source) Licences.Sync(source) end)

-- ps-mdt revokes by writing metadata.licences.<type> = false (see som-compat).
-- Turn that into a revoke in the table, then rewrite the mirror from it, so a
-- client can never grant itself a licence by writing metadata.
AddEventHandler('som:server:metadataChanged', function(source, citizenid, key, value)
    if key ~= 'licenses' or type(value) ~= 'table' then return end

    local status = Licences.Status(citizenid)
    for kind in pairs(Config.types) do
        if value[kind] == false and status[kind] and status[kind].state == 'valid' then
            MySQL.update.await('UPDATE som_licenses SET revoked = 1, suspended_until = NULL WHERE citizenid = ? AND type = ? AND revoked = 0', { citizenid, kind })
        end
    end

    Licences.Sync(source)
end)
