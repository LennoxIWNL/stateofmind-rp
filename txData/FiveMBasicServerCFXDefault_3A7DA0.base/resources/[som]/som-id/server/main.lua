-- ID card server.
--
-- The card is assembled here and pushed to viewers. The client that showed it
-- never decides who sees it, and never supplies the details on it: both would
-- let a player forge a document or flash it across the whole city.

---Builds the card for a character.
---@param player table som-core player
---@param doc table Config.Documents entry
---@return table|nil
local function buildCard(player, doc)
    local charinfo = player.charinfo or {}

    local card = {
        label = doc.label,
        issuer = doc.issuer,
        accent = doc.accent,
        fields = doc.fields,
        photo = nil,

        name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''),
        dob = charinfo.birthdate,
        sex = charinfo.gender == 1 and 'F' or 'M',
        nationality = charinfo.nationality or 'Unknown',
        citizenid = player.citizenid,
    }

    local row = MySQL.single.await(
        'SELECT photo, created_at FROM som_characters WHERE citizenid = ?',
        { player.citizenid })

    if row then
        card.photo = row.photo
        card.issued = row.created_at
    end

    -- A licence document says whether the licence is actually held, so a
    -- revoked one reads as revoked rather than simply being absent.
    if doc.licence then
        local held = MySQL.single.await(
            'SELECT revoked FROM som_licenses WHERE citizenid = ? AND type = ?',
            { player.citizenid, doc.licence })

        if not held then
            card.status = 'NOT ISSUED'
        elseif held.revoked then
            card.status = 'REVOKED'
        else
            card.status = 'VALID'
        end
    end

    return card
end

---@param source number
---@param origin vector3
---@return number[] player ids close enough to read it
local function viewersNear(source, origin)
    local list = {}

    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        if targetId and targetId ~= source then
            local ped = GetPlayerPed(targetId)

            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)

                -- Height is checked separately. A plain 3D distance would let
                -- somebody a floor above read a card held in a lobby, which is
                -- exactly the case this is meant to exclude.
                local dz = math.abs(coords.z - origin.z)
                local flat = #(vector2(coords.x, coords.y) - vector2(origin.x, origin.y))

                if dz <= Config.Show.zTolerance and flat <= Config.Show.radius then
                    list[#list + 1] = targetId
                end
            end
        end
    end

    return list
end

lib.callback.register('som-id:server:show', function(source, item)
    local doc = type(item) == 'string' and Config.Documents[item]
    if not doc then return false end

    local player = exports['som-core']:getPlayer(source)
    if not player then return false end

    -- Holding the item is re-checked here. The client asking to show a document
    -- is not proof it has one.
    if GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(source, item)
        if not count or count < 1 then return false end
    end

    local card = buildCard(player, doc)
    if not card then return false end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end

    local viewers = viewersNear(source, GetEntityCoords(ped))
    for _, viewerId in ipairs(viewers) do
        TriggerClientEvent('som-id:client:card', viewerId, card, Config.Show.duration, false)
    end

    TriggerClientEvent('som-id:client:card', source, card, Config.Show.ownDuration, true)

    return true, #viewers
end)
