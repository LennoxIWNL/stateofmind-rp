-- The client half of the ps-dispatch export surface.
--
-- ps-mdt calls exports['ps-dispatch']:CustomAlert from the CLIENT for its
-- traffic stop alert (`ps-mdt/client/main.lua:1132`), and other preserved
-- resources reach for the same name. Nothing answered on the client, so those
-- calls errored and the alert never fired.
--
-- `provide 'ps-dispatch'` does not forward exports. The
-- __cfx_export_<resource>_<name> event is the actual mechanism, the same one
-- server/main.lua uses and the same one som-compat uses to answer as qb-core.
--
-- SECURITY: nothing here decides anything. Each of these fires a server event
-- that re-derives the position from the caller's own ped, fixes the alert
-- definition from config, and applies the same cooldown as a typed 911. A
-- client may say that something happened where it is standing. It may not say
-- what the call is worth, who hears it, or where it came from.

local function publish(name, fn)
    AddEventHandler(('__cfx_export_ps-dispatch_%s'):format(name), function(setCB)
        setCB(fn)
    end)

    exports(name, fn)
end

---@param data table ps-dispatch's payload shape. Only the text survives.
local function customAlert(data)
    if type(data) ~= 'table' then return end

    TriggerServerEvent('som-dispatch:server:customAlert', {
        message = data.message or data.dispatchMessage or data.description,
        description = data.description,
        street = data.street or data.firstStreet,
        plate = data.plate,
    })
end

publish('CustomAlert', customAlert)

-- ps-dispatch names one export per crime, and third-party scripts call whichever
-- one matches. Each maps onto a definition this resource already has, so a
-- preserved script raising a robbery gets a real call rather than an error.
--
-- Deliberately NOT a loop over Config.Alerts: the names below are ps-dispatch's
-- vocabulary, not SOM's, and they have to keep matching what other resources
-- call even as SOM's own list changes.
local ALIASES = {
    ShotsFired = 'shotsFired',
    Shooting = 'shotsFired',
    DriveBy = 'driveBy',
    Fight = 'meleeAttack',
    MeleeAttack = 'meleeAttack',
    VehicleTheft = 'vehicleTheft',
    CarJacking = 'vehicleTheft',
    Explosion = 'explosion',
}

for name, alertType in pairs(ALIASES) do
    publish(name, function(data)
        TriggerServerEvent('som-dispatch:server:report', alertType,
            type(data) == 'table' and {
                street = data.street,
                plate = data.plate,
                model = data.model or data.vehicle,
                weapon = data.weapon,
            } or {})
    end)
end
