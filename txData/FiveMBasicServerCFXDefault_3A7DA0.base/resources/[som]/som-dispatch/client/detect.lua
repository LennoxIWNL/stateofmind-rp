-- Crime detection.
--
-- This file only ever says "this happened near me". It does not decide whether
-- a call is raised, where it lands, who sees it, or what it says: the server
-- rolls the chance, reads the position off the ped, and picks the recipients.
--
-- CEventGunShot is subscribed by name, which is how r14-evidence does it on this
-- same server (r14-evidence/client/main.lua:548) and is therefore known to work
-- in this build rather than assumed.

local core = exports['som-core']

---Reports an event. Cheap and fire-and-forget: the server discards most of them.
---@param alertType string
---@param extra table|nil
local function report(alertType, extra)
    if not core:isPlayerLoaded() then return end
    TriggerServerEvent('som-dispatch:server:report', alertType, extra or {})
end

-- Weapon hash -> readable label, built once from ox_inventory's item list.
--
-- Built lazily rather than at boot because ox_inventory may not have started
-- yet, and scanned once rather than per shot: a linear search over several
-- hundred items on every trigger pull is exactly the kind of cost that only
-- shows up in a firefight.
local weaponLabels

local function labelForWeapon(hash)
    if not weaponLabels then
        weaponLabels = {}

        local ok, items = pcall(function() return exports.ox_inventory:Items() end)
        if ok and type(items) == 'table' then
            for _, item in pairs(items) do
                if item.weapon and item.hash then
                    weaponLabels[item.hash] = item.label
                end
            end
        end
    end

    return weaponLabels[hash]
end

---The street under a position, resolved here because the natives are client
---only. Purely cosmetic: the server truncates it and never trusts it.
---@return string|nil
local function streetAt(coords)
    local main = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    if not main or main == 0 then return nil end

    local name = GetStreetNameFromHashKey(main)
    return name ~= '' and name or nil
end

-- ---------------------------------------------------------------------------
-- Gunfire
-- ---------------------------------------------------------------------------

AddEventHandler('CEventGunShot', function(_, shooter)
    -- Only the local player's own shots. Every client near a shooting receives
    -- this event, so without the check one gunshot reports once per witness and
    -- the cooldown, which is per player, does not save you.
    if shooter ~= cache.ped then return end

    local weapon = GetSelectedPedWeapon(shooter)
    if Config.SilentWeapons[weapon] then return end

    local coords = GetEntityCoords(shooter)
    local suppressed = Config.SuppressedWeapons[weapon] == true

    local inVehicle = IsPedInAnyVehicle(shooter, false)
    local vehicle = inVehicle and GetVehiclePedIsIn(shooter, false) or nil

    report(inVehicle and 'driveBy' or 'shotsFired', {
        street = streetAt(coords),
        weapon = labelForWeapon(weapon),
        -- A suppressed shot still reports, but the position is scattered server
        -- side. Knowing exactly where a silenced round came from would make the
        -- suppressor pointless.
        scatter = suppressed,
        automatic = Config.AutomaticWeapons[weapon] == true,
        plate = vehicle and GetVehicleNumberPlateText(vehicle) or nil,
        model = vehicle and GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) or nil,
    })
end)

-- ---------------------------------------------------------------------------
-- Melee
--
-- Polled rather than event-driven: there is no melee equivalent of
-- CEventGunShot, and IsPedInMeleeCombat is the only reliable signal. Two
-- seconds is frequent enough for a brawl and cheap enough to leave running.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(2000)

        if core:isPlayerLoaded() and IsPedInMeleeCombat(cache.ped) then
            local coords = GetEntityCoords(cache.ped)
            report('meleeAttack', { street = streetAt(coords) })
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Vehicle theft
--
-- Fires when the player starts hotwiring a car that is not theirs. som-garage
-- will later mark owned vehicles with a statebag; until then anything with a
-- som plate prefix is treated as somebody's.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(1000)

        if core:isPlayerLoaded() then
            local vehicle = cache.vehicle

            if vehicle and GetIsTaskActive(cache.ped, 151) then
                report('vehicleTheft', {
                    street = streetAt(GetEntityCoords(vehicle)),
                    plate = GetVehicleNumberPlateText(vehicle),
                    model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
                })

                -- The server rate-limits this anyway, but hotwiring lasts
                -- several seconds and there is nothing to gain from asking
                -- again while the same task runs.
                Wait(15000)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Explosions
-- ---------------------------------------------------------------------------

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    -- args[1] is the victim and args[2] the attacker. Everything after that is
    -- disputed: this file read args[6] as the weapon hash, som-medical shipped
    -- reading it as the fatal flag and worked, and the Cfx sample and PolyZone
    -- both read args[4] as the fatal flag. They cannot all be right.
    --
    -- So the argument is a hint and the PED is the truth, the same resolution
    -- som-medical uses. Whatever the player is actually holding is not a
    -- decoding of anything, and both candidates still have to pass the damage
    -- type check, so a wrong guess reports nothing rather than reporting a
    -- pistol shot as an explosion.
    local attacker = args[2]
    if attacker ~= cache.ped then return end

    local function explosive(weapon)
        return weapon and weapon ~= 0 and GetWeaponDamageType(weapon) == 5
    end

    if explosive(args[6]) or explosive(GetSelectedPedWeapon(cache.ped)) then
        report('explosion', { street = streetAt(GetEntityCoords(cache.ped)) })
    end
end)
