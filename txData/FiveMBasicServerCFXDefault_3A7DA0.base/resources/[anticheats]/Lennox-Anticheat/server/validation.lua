-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Event Parameter Validation Framework
--  Define expected parameter types + value ranges per event, auto-validate.
-- =========================================================================

local EventSchemas = {}

-- =========================================================================
--  Schema Definition
--  schema = { {name, type, min, max, required}, ... }
--  type: 'number', 'string', 'boolean', 'table'
-- =========================================================================
function LAC.registerEventValidation(eventName, schema)
    if type(eventName) ~= 'string' or type(schema) ~= 'table' then return end
    EventSchemas[eventName] = schema

    AddEventHandler(eventName, function(...)
        local src = source
        if not src or src <= 0 then return end
        if LAC.isAdmin(src) then return end

        local args = { ... }
        for i, rule in ipairs(schema) do
            local val = args[i]
            local valid = true
            local reason = ''

            if rule.required and val == nil then
                valid = false
                reason = ('param %d (%s) missing'):format(i, rule.name or '?')
            elseif val ~= nil then
                if rule.type and type(val) ~= rule.type then
                    valid = false
                    reason = ('param %d (%s) expected %s got %s'):format(i, rule.name or '?', rule.type, type(val))
                end

                if rule.type == 'number' and type(val) == 'number' then
                    if rule.min and val < rule.min then
                        valid = false
                        reason = ('param %d (%s) = %s below min %s'):format(i, rule.name or '?', tostring(val), tostring(rule.min))
                    end
                    if rule.max and val > rule.max then
                        valid = false
                        reason = ('param %d (%s) = %s above max %s'):format(i, rule.name or '?', tostring(val), tostring(rule.max))
                    end
                end

                if rule.type == 'string' and type(val) == 'string' then
                    if rule.maxLen and #val > rule.maxLen then
                        valid = false
                        reason = ('param %d (%s) length %d exceeds max %d'):format(i, rule.name or '?', #val, rule.maxLen)
                    end
                    if rule.pattern and not val:match(rule.pattern) then
                        valid = false
                        reason = ('param %d (%s) failed pattern check'):format(i, rule.name or '?')
                    end
                end
            end

            if not valid then
                LAC.flagPlayer(src, 'Event Validation Failed',
                    ('Event: %s | %s'):format(eventName:sub(1, 40), reason:sub(1, 60)), 5, false)
                CancelEvent()
                return
            end
        end
    end)
end

function LAC.isEventValid(eventName, ...)
    local schema = EventSchemas[eventName]
    if not schema then return true end

    local args = { ... }
    for i, rule in ipairs(schema) do
        local val = args[i]
        if rule.required and val == nil then return false end
        if val ~= nil then
            if rule.type and type(val) ~= rule.type then return false end
            if rule.type == 'number' and type(val) == 'number' then
                if rule.min and val < rule.min then return false end
                if rule.max and val > rule.max then return false end
            end
            if rule.type == 'string' and type(val) == 'string' then
                if rule.maxLen and #val > rule.maxLen then return false end
                if rule.pattern and not val:match(rule.pattern) then return false end
            end
        end
    end
    return true
end

-- =========================================================================
--  Built-in Schemas for Common Exploitable Events
-- =========================================================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- QBCore common events
    if GetResourceState('qb-core') == 'started' then
        LAC.registerEventValidation('qb-inventory:server:recieveItem', {
            { name = 'item',   type = 'string', required = true, maxLen = 50 },
            { name = 'amount', type = 'number', required = true, min = 1, max = 100 },
        })

        LAC.registerEventValidation('qb-inventory:server:givemoney', {
            { name = 'amount', type = 'number', required = true, min = 1, max = 5000 },
        })

        LAC.registerEventValidation('qb-shops:server:sellItem', {
            { name = 'item',   type = 'string', required = true, maxLen = 50 },
            { name = 'amount', type = 'number', required = true, min = 1, max = 500 },
            { name = 'price',  type = 'number', required = false, min = 0, max = 100000 },
        })
    end

    -- ESX common events
    if GetResourceState('es_extended') == 'started' then
        LAC.registerEventValidation('esx_society:withdrawMoney', {
            { name = 'society', type = 'string', required = true, maxLen = 50 },
            { name = 'amount',  type = 'number', required = true, min = 1, max = 100000 },
        })
    end
end)

-- =========================================================================
--  Exports
-- =========================================================================
exports('RegisterEventValidation', function(eventName, schema)
    LAC.registerEventValidation(eventName, schema)
end)

exports('IsEventValid', function(eventName, ...)
    return LAC.isEventValid(eventName, ...)
end)
