-- Resolves what a player is entitled to: character slots, queue priority, and
-- cosmetic perks.
--
-- Server side only, and every consumer must ask here rather than reading a
-- config value locally. Character slots in particular are a security boundary:
-- if the client decided its own cap, a player could create characters in slots
-- they have not earned.

Entitlements = {}

---@param source number
---@return table tier definition the player qualifies for
local function resolveSupporterTier(source)
    local best = Tiers.supporter[1]

    -- Ordered lowest to highest, so the last match wins.
    for i = 1, #Tiers.supporter do
        local tier = Tiers.supporter[i]
        if tier.ace and Permissions.Has(source, tier.ace) then
            best = tier
        end
    end

    return best
end

---@param source number
---@return number slots, number priority
local function resolveStaff(source)
    local slots, priority = 0, 0

    for _, entry in ipairs(Tiers.staff) do
        if Permissions.Has(source, entry.ace) then
            if entry.slots > slots then slots = entry.slots end
            if entry.queuePriority > priority then priority = entry.queuePriority end
        end
    end

    return slots, priority
end

---@param source number
---@return table { tier, label, slots, queuePriority, perks }
function Entitlements.Get(source)
    local tier = resolveSupporterTier(source)
    local staffSlots, staffPriority = resolveStaff(source)

    -- Better of the two, so staff never lose what a purchase would have given
    -- and a purchase never removes a staff entitlement.
    -- A purchase can never exceed the purchasable ceiling, even if the tier
    -- table is later edited past it by mistake. Staff are exempt: management
    -- is the only route to the absolute cap.
    local purchased = math.min(tier.slots or Tiers.defaultSlots, Tiers.maxPurchasableSlots)

    local slots = math.max(purchased, staffSlots)
    local priority = math.max(tier.queuePriority or 0, staffPriority)

    if slots > Tiers.maxSlots then slots = Tiers.maxSlots end
    if slots < 1 then slots = 1 end

    return {
        tier = tier.name,
        label = tier.label,
        slots = slots,
        queuePriority = priority,
        perks = tier.perks or {},
    }
end

---Character slot cap. Its own function because it is the one entitlement that
---is a security boundary rather than a convenience.
---@param source number
---@return number
function Entitlements.GetSlots(source)
    return Entitlements.Get(source).slots
end

---@param source number
---@param perk string
---@return boolean|number false, true, or a count for perks that have one
function Entitlements.HasPerk(source, perk)
    local value = Entitlements.Get(source).perks[perk]
    return value or false
end

exports('getEntitlements', Entitlements.Get)
exports('getCharacterSlots', Entitlements.GetSlots)
exports('hasPerk', Entitlements.HasPerk)

lib.callback.register('som:server:getEntitlements', function(source)
    local result = Entitlements.Get(source)

    -- Resolving to the bare minimum is usually a misconfiguration rather than
    -- a genuine free-tier player, and a silent 2 slots looks identical to a
    -- broken ACE lookup. Report what the server actually believes.
    if result.slots <= Tiers.defaultSlots then
        print(('[som-core] %s resolved to %s, %d slots. If that is wrong, the ACE below is why:')
            :format(GetPlayerName(source) or '?', result.label or '?', result.slots))
        Permissions.Debug(source)
    end

    return result
end)
