-- Radial server.
--
-- Decides what a player is ENTITLED to see. The client decides what makes
-- sense right now, which is a different question: a job entry filtered only on
-- the client is a job entry any client can restore.

local registered = {}

---Other resources contribute their own entries, the same way som-phone takes
---its apps, so this resource does not need to know about every feature.
---
---`export` names a validated export. There is deliberately no `event` field:
---a config that can fire an arbitrary event from a menu click would let the
---client choose both the event and its payload.
---@param item table { id, section, label, icon, order, export, job, gang, minGrade, duty, ace }
exports('register', function(item)
    if type(item) ~= 'table' or type(item.id) ~= 'string' then return false end
    if type(item.export) ~= 'string' and type(item.menu) ~= 'string' then return false end

    registered[item.id] = {
        id = item.id,
        section = item.section or 'self',
        label = item.label or item.id,
        icon = item.icon or 'dot',
        order = item.order or 50,
        export = item.export,
        menu = item.menu,
        seatedOnly = item.seatedOnly,
        -- Client-side situational check, e.g. 'som-garage.hasGarageNear'. A
        -- VISIBILITY filter only; entitlement is decided by permitted() below.
        visible = type(item.visible) == 'string' and item.visible or nil,
        job = item.job,
        gang = item.gang,
        minGrade = item.minGrade,
        duty = item.duty,
        ace = item.ace,
        resource = GetInvokingResource(),
    }

    return true
end)

exports('unregister', function(id)
    registered[id] = nil
    return true
end)

---@param source number
---@param player table
---@param item table
---@return boolean
local function permitted(source, player, item)
    if item.job then
        if not player.job or player.job.name ~= item.job then return false end
        if item.minGrade and (player.job.grade or 0) < item.minGrade then return false end
        if item.duty and not player.job.onduty then return false end
    end

    if item.gang then
        if not player.gang or player.gang.name ~= item.gang then return false end
        if item.minGrade and (player.gang.grade or 0) < item.minGrade then return false end
    end

    if item.ace and not exports['som-core']:hasPermission(source, item.ace) then
        return false
    end

    return true
end

lib.callback.register('som-radial:server:entries', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    local hasJob = player.job and player.job.name and player.job.name ~= 'unemployed'
    local hasGang = player.gang and player.gang.name and player.gang.name ~= 'none'

    local sections = {}
    for _, section in ipairs(Config.Sections) do
        local show = true
        if section.when == 'job' then show = hasJob end
        if section.when == 'gang' then show = hasGang end

        if show then
            sections[#sections + 1] = {
                id = section.id,
                label = section.label,
                icon = section.icon,
                order = section.order,
                when = section.when,
            }
        end
    end

    table.sort(sections, function(a, b) return a.order < b.order end)

    local items = {}

    local function consider(item)
        if not permitted(source, player, item) then return end
        items[#items + 1] = item
    end

    for _, item in ipairs(Config.Items) do consider(item) end
    for _, item in pairs(registered) do consider(item) end

    table.sort(items, function(a, b) return (a.order or 50) < (b.order or 50) end)

    return { sections = sections, items = items }
end)

RegisterNetEvent('som-radial:server:handsUp', function(state)
    local source = source
    if type(state) ~= 'boolean' then return end

    local player = exports['som-core']:getPlayer(source)
    if not player then return end

    -- Only a real change is applied, so repeating the same state costs nothing and a quick up and down is never lost.
    if exports['som-core']:getMetadata(source, 'handsup') == state then return end
    exports['som-core']:setMetadata(source, 'handsup', state)
end)
