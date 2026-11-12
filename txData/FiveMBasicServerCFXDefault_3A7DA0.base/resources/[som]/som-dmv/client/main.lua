--- A counter and two menus. Fees, ownership, the plate rules and the garage
--- check are all the server's.

local zone

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function ask(heading, rows)
    return lib.inputDialog(heading, rows)
end

local menu

local function vehicleMenu(v, data)
    local options = {
        {
            title = v.expired and 'Renew the registration (expired)' or ('Renew the registration (%d days left)'):format(v.daysLeft),
            description = ('$%d, adds %d days'):format(data.registrationFee, Config.registration.days),
            onSelect = function()
                local r = lib.callback.await('som-dmv:server:renew', false, v.id)
                if r and r.success then notify('Registration renewed', 'success') else notify(r and r.error or 'Not available') end
                menu()
            end,
        },
        {
            title = 'Change the plate',
            description = v.state == 'garaged' and ('$%d, the car must be in a garage'):format(data.vanityFee) or 'Put it in a garage first',
            disabled = v.state ~= 'garaged',
            onSelect = function()
                local input = ask('New plate', { { type = 'input', label = 'Plate (2 to 8 letters, numbers or spaces)', required = true, min = Config.vanity.minLength, max = Config.vanity.maxLength } })
                if not input then return end
                local r = lib.callback.await('som-dmv:server:changePlate', false, v.id, tostring(input[1]))
                if r and r.success then notify(('Your plate is now %s'):format(r.plate), 'success') else notify(r and r.error or 'Not available') end
                menu()
            end,
        },
    }
    lib.registerContext({ id = 'som_dmv_vehicle', title = v.plate, menu = 'som_dmv', options = options })
    lib.showContext('som_dmv_vehicle')
end

menu = function()
    local data = lib.callback.await('som-dmv:server:list', false)
    if not data or not data.success then return notify(data and data.error or 'Not available') end

    local options = {}
    for _, v in ipairs(data.vehicles) do
        options[#options + 1] = {
            title = ('%s (%s)'):format(v.plate, v.model),
            description = v.expired and 'Registration expired' or ('Registered, %d days left'):format(v.daysLeft),
            arrow = true,
            onSelect = function() vehicleMenu(v, data) end,
        }
    end
    if #options == 0 then options[1] = { title = 'You have no vehicles to register', readOnly = true } end

    lib.registerContext({ id = 'som_dmv', title = 'DMV', options = options })
    lib.showContext('som_dmv')
end

CreateThread(function()
    local d = lib.callback.await('som-dmv:server:desk', false)
    if type(d) ~= 'table' then return end
    zone = exports['som-interact']:addSphereZone({
        name = 'som_dmv_desk',
        coords = vec3(d.coords.x, d.coords.y, d.coords.z),
        radius = d.distance,
        options = { { name = 'som_dmv_use', label = d.label, icon = 'fa-solid fa-id-card', distance = d.distance, onSelect = menu } },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and zone then exports['som-interact']:removeZone(zone) end
end)
